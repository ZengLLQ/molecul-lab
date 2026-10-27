"""
Asynchronous Job Execution Subsystem.
Orchestrates background computation on worker threads without blocking the desktop UI.
Supports safe cooperative cancellation and event streaming.
"""
module Jobs

using Base.Threads
using Dates
using ..Results: JobState, Job, JOB_QUEUED, JOB_VALIDATING, JOB_RUNNING,
                 JOB_CANCELLING, JOB_CANCELLED, JOB_COMPLETED, JOB_FAILED
using ..Structures: Structure
using ..SimulationInterface: AbstractChemistryMethod, execute_method, validate_method_config

export JobManager, submit_job!, request_cancel!, get_job, list_jobs

mutable struct JobHandle
    job::Job
    cancel_token::Atomic{Bool}
    task::Union{Task, Nothing}
    result_data::Union{Dict{String, Any}, Nothing}
    error_detail::Union{String, Nothing}
end

mutable struct JobManager
    lock::ReentrantLock
    handles::Dict{String, JobHandle}
    event_channel::Channel{NamedTuple}

    function JobManager(buffer_size::Int=256)
        new(ReentrantLock(), Dict{String, JobHandle}(), Channel{NamedTuple}(buffer_size))
    end
end

"""
    submit_job!(manager::JobManager, job_id::String, experiment_id::String,
                method::AbstractChemistryMethod, config::Dict{String, Any},
                structure::Structure; on_complete::Function=(res) -> nothing) -> Job
"""
function submit_job!(manager::JobManager, job_id::String, experiment_id::String,
                     method::AbstractChemistryMethod, config::Dict{String, Any},
                     structure::Structure; on_complete::Function=(res) -> nothing)::Job
    lock(manager.lock) do
        if haskey(manager.handles, job_id)
            error("Job with ID '$job_id' already exists.")
        end

        initial_job = Job(job_id, experiment_id, JOB_QUEUED;
                          started_at=string(Dates.now(Dates.UTC)))
        cancel_token = Atomic{Bool}(false)
        handle = JobHandle(initial_job, cancel_token, nothing, nothing, nothing)
        manager.handles[job_id] = handle

        # Spawn asynchronous worker task
        handle.task = Threads.@spawn begin
            try
                # 1. Validation phase
                handle.job = Job(job_id, experiment_id, JOB_VALIDATING;
                                 started_at=handle.job.started_at)
                put!(manager.event_channel, (job_id=job_id, state=JOB_VALIDATING, progress=0.0, msg="Validating configuration"))

                errors, warnings = validate_method_config(method, config, structure)
                if !isempty(errors)
                    err_msg = join(errors, "; ")
                    handle.job = Job(job_id, experiment_id, JOB_FAILED;
                                     started_at=handle.job.started_at,
                                     finished_at=string(Dates.now(Dates.UTC)),
                                     error_summary=err_msg,
                                     termination_reason="validation_error")
                    put!(manager.event_channel, (job_id=job_id, state=JOB_FAILED, progress=-1.0, msg=err_msg))
                    on_complete(handle.job, nothing)
                    return
                end

                # 2. Execution phase
                handle.job = Job(job_id, experiment_id, JOB_RUNNING;
                                 started_at=handle.job.started_at)
                put!(manager.event_channel, (job_id=job_id, state=JOB_RUNNING, progress=0.0, msg="Calculation started"))

                progress_cb = function(step_or_iter, metric1, metric2...)
                    if cancel_token[]
                        handle.job = Job(job_id, experiment_id, JOB_CANCELLING;
                                         started_at=handle.job.started_at)
                        put!(manager.event_channel, (job_id=job_id, state=JOB_CANCELLING, progress=-1.0, msg="Cancellation requested"))
                    else
                        put!(manager.event_channel, (job_id=job_id, state=JOB_RUNNING, progress=0.0,
                                                     iter=step_or_iter, val1=metric1))
                    end
                end

                result_dict = execute_method(method, config, structure, cancel_token, progress_cb)
                handle.result_data = result_dict

                # 3. Termination phase
                if cancel_token[]
                    handle.job = Job(job_id, experiment_id, JOB_CANCELLED;
                                     started_at=handle.job.started_at,
                                     finished_at=string(Dates.now(Dates.UTC)),
                                     termination_reason="cancelled_by_user")
                    put!(manager.event_channel, (job_id=job_id, state=JOB_CANCELLED, progress=-1.0, msg="Job cancelled"))
                else
                    handle.job = Job(job_id, experiment_id, JOB_COMPLETED;
                                     started_at=handle.job.started_at,
                                     finished_at=string(Dates.now(Dates.UTC)),
                                     termination_reason=get(result_dict, "termination_status", "completed"),
                                     progress=1.0)
                    put!(manager.event_channel, (job_id=job_id, state=JOB_COMPLETED, progress=1.0, msg="Job completed successfully"))
                end

                on_complete(handle.job, result_dict)

            catch err
                err_str = sprint(showerror, err, catch_backtrace())
                handle.error_detail = err_str
                handle.job = Job(job_id, experiment_id, JOB_FAILED;
                                 started_at=handle.job.started_at,
                                 finished_at=string(Dates.now(Dates.UTC)),
                                 error_summary=string(err),
                                 termination_reason="runtime_exception")
                put!(manager.event_channel, (job_id=job_id, state=JOB_FAILED, progress=-1.0, msg="Failed: $err"))
                on_complete(handle.job, nothing)
            end
        end

        return initial_job
    end
end

"""
    request_cancel!(manager::JobManager, job_id::String) -> Bool

Cooperatively signals a running job to halt at the next iteration boundary.
"""
function request_cancel!(manager::JobManager, job_id::String)::Bool
    lock(manager.lock) do
        if haskey(manager.handles, job_id)
            handle = manager.handles[job_id]
            handle.cancel_token[] = true
            return true
        end
        return false
    end
end

"""
    get_job(manager::JobManager, job_id::String) -> Union{Job, Nothing}
"""
function get_job(manager::JobManager, job_id::String)::Union{Job, Nothing}
    lock(manager.lock) do
        return haskey(manager.handles, job_id) ? manager.handles[job_id].job : nothing
    end
end

"""
    list_jobs(manager::JobManager) -> Vector{Job}
"""
function list_jobs(manager::JobManager)::Vector{Job}
    lock(manager.lock) do
        return [h.job for h in values(manager.handles)]
    end
end

end # module Jobs
