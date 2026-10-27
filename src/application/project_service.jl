"""
Application Service for managing project lifecycle, storage creation, and metadata.
"""
module ProjectService

using UUIDs
using Dates
using TOML
using SQLite
using ..Projects: Project
using ..Artifacts: ensure_project_directories
using ..Database: init_database, get_cached_database, close_cached_database!,
                  save_project!, load_project

export create_project, open_project, get_project_db, close_project!

"""
    create_project(name::AbstractString, root_path::AbstractString) -> Project

Creates a new MolecuLab project directory, database, and manifest.
"""
function create_project(name::AbstractString, root_path::AbstractString)::Project
    clean_name = strip(name)
    if isempty(clean_name)
        error("Project name cannot be empty.")
    end

    full_root = abspath(root_path)
    ensure_project_directories(full_root)

    proj_id = string(uuid4())
    now_iso = string(Dates.now(Dates.UTC))
    proj = Project(proj_id, clean_name, full_root;
                   schema_version=1,
                   created_at=now_iso,
                   updated_at=now_iso,
                   settings=Dict{String, Any}("default_coordinate_unit" => "Angstrom"))

    # 1. Initialize SQLite metadata database
    db = get_project_db(proj)
    save_project!(db, proj)

    # 2. Write human-readable project.toml manifest
    toml_path = joinpath(full_root, "project.toml")
    open(toml_path, "w") do f
        TOML.print(f, Dict(
            "id" => proj.id,
            "name" => proj.name,
            "schema_version" => proj.schema_version,
            "created_at" => proj.created_at,
            "updated_at" => proj.updated_at
        ))
    end

    return proj
end

"""
    open_project(root_path::AbstractString) -> Project

Opens an existing MolecuLab project and validates database integrity.
"""
function open_project(root_path::AbstractString)::Project
    full_root = abspath(root_path)
    toml_path = joinpath(full_root, "project.toml")
    db_path = joinpath(full_root, "database", "project.sqlite")

    if !isfile(toml_path)
        error("Not a valid MolecuLab project: missing 'project.toml' at $full_root")
    end
    if !isfile(db_path)
        error("Project metadata database missing: expected $db_path")
    end

    data = TOML.parsefile(toml_path)
    db = get_cached_database(db_path)
    proj = load_project(db, data["id"])

    if isnothing(proj)
        # Recover project record from project.toml
        proj = Project(data["id"], data["name"], full_root;
                       schema_version=get(data, "schema_version", 1),
                       created_at=get(data, "created_at", string(Dates.now(Dates.UTC))),
                       updated_at=string(Dates.now(Dates.UTC)))
        save_project!(db, proj)
    end

    return proj
end

"""
    get_project_db(p::Project) -> SQLite.DB
"""
function get_project_db(p::Project)::SQLite.DB
    db_path = joinpath(p.root_path, "database", "project.sqlite")
    return get_cached_database(db_path)
end

"""
    close_project!(p::Project)
"""
function close_project!(p::Project)
    db_path = joinpath(p.root_path, "database", "project.sqlite")
    close_cached_database!(db_path)
end

end # module ProjectService
