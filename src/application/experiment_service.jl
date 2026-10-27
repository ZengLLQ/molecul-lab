"""
Application Service for computational experiments and job scheduling.
Guarantees full provenance tracking, environment capture, and truthful result logging.
"""
module ExperimentService

using UUIDs
using Dates
using JSON3
using ..Projects: Project
using ..Structures: Structure, Atom, Bond
using ..Experiments: Experiment
using ..Results: Job, Result, Artifact, JobState, JOB_COMPLETED, JOB_FAILED, JOB_CANCELLED
using ..SimulationInterface: AbstractChemistryMethod, validate_method_config
using ..MolecularMechanics: LennardJonesMethod
using ..MolecularDynamics: MolecularDynamicsMethod
using ..Jobs: JobManager, submit_job!, request_cancel!, get_job
using ..ProjectService: get_project_db
using ..Database: save_experiment!, load_experiment,
                  load_experiments_for_project, save_job!, save_result!,
                  load_result, save_structure!
using ..Artifacts: write_atomic, compute_sha256
using ..Environment: get_runtime_manifest
using ..Exporters: export_xyz

export create_experiment, execute_experiment_job, cancel_experiment_job,
       get_project_experiments, get_experiment_result, resolve_chemistry_method

function resolve_chemistry_method(method_id::AbstractString)::AbstractChemistryMethod
    m = lowercase(strip(method_id))
    if occursin("dynamics", m) || occursin("md", m) || occursin("verlet", m)
        return MolecularDynamicsMethod()
    else
        return LennardJonesMethod()
    end
end

"""
    create_experiment(project::Project, structure::Structure, method_id::AbstractString,
                      config::Dict{String, Any}; random_seed::Int=42) -> Experiment
"""
function create_experiment(project::Project, structure::Structure, method_id::AbstractString,
                           config::Dict{String, Any}; random_seed::Int=42)::Experiment
    exp_id = "EXP-" * uppercase(string(uuid4())[1:8])
    now_iso = string(Dates.now(Dates.UTC))

    exp = Experiment(exp_id, project.id, structure.id, String(method_id);
                     status="draft",
                     config=config,
                     random_seed=random_seed,
                     created_at=now_iso,
                     updated_at=now_iso)

    db = get_project_db(project)
    save_experiment!(db, exp)

    # Prepare experiment directory hierarchy
    exp_dir = joinpath(project.root_path, "experiments", exp_id)
    mkpath(joinpath(exp_dir, "logs"))
    mkpath(joinpath(exp_dir, "checkpoints"))
    mkpath(joinpath(exp_dir, "results"))

    # Write frozen config.json and runtime environment.json
    write_atomic(joinpath(exp_dir, "config.json"), JSON3.write(config); artifact_type="application/json")
    write_atomic(joinpath(exp_dir, "environment.json"), JSON3.write(get_runtime_manifest(project.root_path)); artifact_type="application/json")

    return exp
end

"""
    execute_experiment_job(project::Project, experiment::Experiment, structure::Structure,
                           job_manager::JobManager;
                           on_event_cb::Function=(event) -> nothing) -> Job
"""
function execute_experiment_job(project::Project, experiment::Experiment, structure::Structure,
                                job_manager::JobManager;
                                on_event_cb::Function=(event) -> nothing)::Job
    method = resolve_chemistry_method(experiment.method_id)
    job_id = "JOB-" * uppercase(string(uuid4())[1:8])
    db = get_project_db(project)

    # Callback executed when worker terminates
    on_finish = function(completed_job::Job, result_dict::Union{Dict{String, Any}, Nothing})
        # 1. Update Job record in DB
        save_job!(db, completed_job)

        # 2. Update Experiment status
        updated_exp = Experiment(experiment.id, experiment.project_id, experiment.structure_id,
                                 experiment.method_id;
                                 status=string(completed_job.state),
                                 config=experiment.config,
                                 random_seed=experiment.random_seed,
                                 created_at=experiment.created_at,
                                 updated_at=string(Dates.now(Dates.UTC)))
        save_experiment!(db, updated_exp)

        # 3. If calculation produced results, persist artifacts and Result entity
        if !isnothing(result_dict)
            exp_dir = joinpath(project.root_path, "experiments", experiment.id)
            results_dir = joinpath(exp_dir, "results")
            artifacts = Artifact[]

            # Save results.json
            res_json_path = joinpath(results_dir, "results.json")
            push!(artifacts, write_atomic(res_json_path, JSON3.write(result_dict); artifact_type="application/json"))

            # Save optimized structure XYZ if present
            if haskey(result_dict, "optimized_atoms")
                opt_atoms = result_dict["optimized_atoms"]
                xyz_path = joinpath(results_dir, "final_structure.xyz")
                export_xyz(xyz_path, opt_atoms; comment="Optimized by MolecuLab ($(experiment.id))")
                push!(artifacts, Artifact("final_structure.xyz", xyz_path, "chemical/x-xyz";
                                          sha256=compute_sha256(xyz_path),
                                          size_bytes=filesize(xyz_path)))

                # Register optimized geometry as a new conformer in the project
                if get(result_dict, "converged", false)
                    conformer_id = string(uuid4())
                    conf_name = "Optimized ($(experiment.id))"
                    conf_struct = Structure(conformer_id, structure.molecule_id, conf_name, opt_atoms, structure.bonds;
                                            coordinate_unit="Angstrom",
                                            warnings=structure.warnings,
                                            created_at=string(Dates.now(Dates.UTC)))
                    save_structure!(db, conf_struct)
                end
            end

            # Save Result entity to DB
            final_e = Float64(get(result_dict, "final_energy", get(result_dict, "final_total_energy", NaN)))
            final_gnorm = Float64(get(result_dict, "gradient_norm", NaN))
            iters = Int(get(result_dict, "iterations", get(result_dict, "total_steps_executed", 0)))
            conv = Bool(get(result_dict, "converged", completed_job.state == JOB_COMPLETED))
            term_status = String(get(result_dict, "termination_status", string(completed_job.state)))

            res_entity = Result("RES-" * uppercase(string(uuid4())[1:8]), experiment.id;
                                final_energy=final_e,
                                gradient_norm=final_gnorm,
                                iterations=iters,
                                converged=conv,
                                termination_status=term_status,
                                metrics=result_dict,
                                artifacts=artifacts,
                                created_at=string(Dates.now(Dates.UTC)))
            save_result!(db, res_entity)
        end
    end

    job = submit_job!(job_manager, job_id, experiment.id, method, experiment.config, structure;
                      on_complete=on_finish)
    save_job!(db, job)
    return job
end

cancel_experiment_job(job_manager::JobManager, job_id::AbstractString) =
    request_cancel!(job_manager, String(job_id))

get_project_experiments(project::Project)::Vector{Experiment} =
    load_experiments_for_project(get_project_db(project), project.id)

get_experiment_result(project::Project, experiment_id::AbstractString)::Union{Result, Nothing} =
    load_result(get_project_db(project), experiment_id)

end # module ExperimentService
