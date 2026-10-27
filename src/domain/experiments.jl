"""
Domain definitions for computational experiments.
"""
module Experiments

export Experiment

"""
    Experiment

Represents a configured computational calculation tied to an immutable structure snapshot.
"""
struct Experiment
    id::String
    project_id::String
    structure_id::String
    method_id::String
    status::String
    config::Dict{String, Any}
    random_seed::Int
    created_at::String
    updated_at::String

    function Experiment(id::AbstractString, project_id::AbstractString,
                        structure_id::AbstractString, method_id::AbstractString;
                        status::AbstractString="draft",
                        config::Dict{String, Any}=Dict{String, Any}(),
                        random_seed::Int=42,
                        created_at::AbstractString="",
                        updated_at::AbstractString="")
        new(String(id), String(project_id), String(structure_id), String(method_id),
            String(status), config, random_seed, String(created_at), String(updated_at))
    end
end

end # module Experiments
