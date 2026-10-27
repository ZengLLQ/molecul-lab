"""
Software runtime environment provenance and diagnostic manifest generation.
"""
module Environment

using Dates
using SHA
using ..Hardware: probe_hardware

export get_runtime_manifest

"""
    get_runtime_manifest(project_dir::AbstractString="") -> Dict{String, Any}

Captures a complete snapshot of the executing Julia runtime, packages, and hardware.
"""
function get_runtime_manifest(project_dir::AbstractString="")::Dict{String, Any}
    hw = probe_hardware()

    manifest_hash = ""
    manifest_path = joinpath(isempty(project_dir) ? pwd() : project_dir, "Manifest.toml")
    if isfile(manifest_path)
        manifest_hash = bytes2hex(sha256(read(manifest_path)))
    end

    return Dict{String, Any}(
        "timestamp_utc" => string(Dates.now(Dates.UTC)),
        "julia_version" => string(VERSION),
        "moleculab_version" => "1.0.0",
        "os" => string(Sys.KERNEL),
        "os_version" => string(Sys.windows_version()),
        "architecture" => string(Sys.ARCH),
        "cpu_model" => hw.cpu_model,
        "cpu_threads" => hw.cpu_threads,
        "total_memory_gb" => hw.total_memory_gb,
        "free_memory_gb" => hw.free_memory_gb,
        "gpu_detected" => hw.gpu_detected,
        "gpu_name" => hw.gpu_name,
        "gpu_vram_mb" => hw.gpu_vram_mb,
        "gpu_driver" => hw.gpu_driver_version,
        "manifest_sha256" => manifest_hash
    )
end

end # module Environment
