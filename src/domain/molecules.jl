"""
Domain definitions for chemical molecules.
"""
module Molecules

export Molecule

"""
    Molecule

Represents a high-level chemical identity within a project.
"""
struct Molecule
    id::String
    project_id::String
    name::String
    formula::String
    molecular_weight::Float64
    structure_ids::Vector{String}
    metadata::Dict{String, Any}
    created_at::String

    function Molecule(id::AbstractString, project_id::AbstractString, name::AbstractString;
                      formula::AbstractString="",
                      molecular_weight::Real=0.0,
                      structure_ids::Vector{String}=String[],
                      metadata::Dict{String, Any}=Dict{String, Any}(),
                      created_at::AbstractString="")
        new(String(id), String(project_id), String(name), String(formula),
            Float64(molecular_weight), structure_ids, metadata, String(created_at))
    end
end

end # module Molecules
