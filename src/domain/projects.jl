"""
Domain definitions for MolecuLab research projects.
"""
module Projects

export Project

"""
    Project

Represents a local scientific research workspace.
"""
struct Project
    id::String
    name::String
    schema_version::Int
    root_path::String
    created_at::String
    updated_at::String
    settings::Dict{String, Any}

    function Project(id::AbstractString, name::AbstractString, root_path::AbstractString;
                     schema_version::Int=1,
                     created_at::AbstractString="",
                     updated_at::AbstractString="",
                     settings::Dict{String, Any}=Dict{String, Any}())
        new(String(id), String(name), schema_version, String(root_path),
            String(created_at), String(updated_at), settings)
    end
end

end # module Projects
