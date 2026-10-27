"""
Atomic filesystem artifact management and SHA-256 integrity verification.
"""
module Artifacts

using SHA
using ..Results: Artifact

export compute_sha256, write_atomic, ensure_project_directories

"""
    compute_sha256(filepath::AbstractString) -> String

Calculates hex-encoded SHA-256 checksum of a file.
"""
function compute_sha256(filepath::AbstractString)::String
    if !isfile(filepath)
        error("File does not exist: $filepath")
    end
    open(filepath, "r") do f
        return bytes2hex(sha256(f))
    end
end

"""
    compute_sha256(data::Vector{UInt8}) -> String
"""
compute_sha256(data::Vector{UInt8})::String = bytes2hex(sha256(data))

"""
    write_atomic(filepath::AbstractString, content::Union{String, Vector{UInt8}}) -> Artifact

Writes content atomically using a temporary file in the same directory, then renames.
Prevents partial writes or corrupted files during crashes.
"""
function write_atomic(filepath::AbstractString, content::Union{String, Vector{UInt8}};
                      artifact_type::AbstractString="application/octet-stream")::Artifact
    dir = dirname(filepath)
    !isdir(dir) && mkpath(dir)

    tmp_path = filepath * ".tmp." * string(rand(UInt64), base=16)
    try
        write(tmp_path, content)
        mv(tmp_path, filepath; force=true)
    catch err
        rm(tmp_path; force=true)
        rethrow(err)
    end

    c_hash = compute_sha256(filepath)
    size_b = filesize(filepath)
    name = basename(filepath)

    return Artifact(name, String(filepath), String(artifact_type); sha256=c_hash, size_bytes=size_b)
end

"""
    ensure_project_directories(project_root::AbstractString)

Creates the standard directory tree for a MolecuLab project.
"""
function ensure_project_directories(project_root::AbstractString)
    mkpath(joinpath(project_root, "database"))
    mkpath(joinpath(project_root, "structures", "molecules"))
    mkpath(joinpath(project_root, "structures", "snapshots"))
    mkpath(joinpath(project_root, "experiments"))
    mkpath(joinpath(project_root, "exports"))
    mkpath(joinpath(project_root, "reports"))
end

end # module Artifacts
