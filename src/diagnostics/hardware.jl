"""
Hardware diagnostics and device capability probes.
Provides truthful reporting of CPU, RAM, and NVIDIA GPU/CUDA resources.
"""
module Hardware

export HardwareInfo, probe_hardware, has_functional_gpu

struct HardwareInfo
    cpu_model::String
    cpu_threads::Int
    total_memory_gb::Float64
    free_memory_gb::Float64
    gpu_detected::Bool
    gpu_name::String
    gpu_vram_mb::Float64
    gpu_driver_version::String
    cuda_available::Bool
    notes::String
end

"""
    probe_hardware() -> HardwareInfo

Detects local host hardware without hanging or fabricating states.
"""
function probe_hardware()::HardwareInfo
    cpu_threads = Sys.CPU_THREADS
    tot_mem_gb = round(Sys.total_memory() / 1024^3, digits=2)
    free_mem_gb = round(Sys.free_memory() / 1024^3, digits=2)

    # Windows CPU model detection via environment or WMI
    cpu_model = get(ENV, "PROCESSOR_IDENTIFIER", "x86_64 CPU")

    gpu_detected = false
    gpu_name = "None"
    gpu_vram_mb = 0.0
    gpu_driver = "None"
    cuda_avail = false
    notes = "CPU baseline operational."

    # Try probing nvidia-smi if available
    try
        smi_path = Sys.which("nvidia-smi")
        if !isnothing(smi_path) && isfile(smi_path)
            # Query GPU name, driver version, and memory
            cmd = `$smi_path --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits`
            out = read(cmd, String)
            lines = split(strip(out), "\n")
            if !isempty(lines) && !isempty(strip(lines[1]))
                tokens = [strip(t) for t in split(lines[1], ",")]
                if length(tokens) >= 3
                    gpu_detected = true
                    gpu_name = tokens[1]
                    gpu_driver = tokens[2]
                    gpu_vram_mb = tryparse(Float64, tokens[3]) !== nothing ? parse(Float64, tokens[3]) : 0.0
                    cuda_avail = true
                    notes = "NVIDIA GPU detected. Optional GPU offload capability available."
                end
            end
        end
    catch err
        notes = "GPU probe skipped: $err"
    end

    return HardwareInfo(cpu_model, cpu_threads, tot_mem_gb, free_mem_gb,
                        gpu_detected, gpu_name, gpu_vram_mb, gpu_driver,
                        cuda_avail, notes)
end

has_functional_gpu() = probe_hardware().cuda_available

end # module Hardware
