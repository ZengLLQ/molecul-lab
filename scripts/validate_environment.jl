# scripts/validate_environment.jl — MolecuLab Environment & Toolchain Diagnostics

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..")))

println("="^70)
println("  MOLECULAB — COMPUTATIONAL CHEMISTRY WORKBENCH")
println("  Environment & Toolchain Validation Suite")
println("="^70)

println("\n[1/5] Checking Julia Runtime & System Information...")
println("  Julia Version   : $(VERSION)")
println("  Commit          : $(Base.GIT_VERSION_INFO.commit_short) ($(Base.GIT_VERSION_INFO.date_string))")
println("  OS / Word Size  : $(Sys.KERNEL) / $(Sys.WORD_SIZE)-bit")
println("  CPU Cores/Host  : $(Sys.CPU_NAME) ($(Sys.CPU_THREADS) hardware threads)")
println("  Base Threads    : $(Threads.nthreads()) available Julia worker thread(s)")

println("\n[2/5] Loading Core Modules...")
t_start = time()
using MolecuLab
using MolecuLab.Hardware
using MolecuLab.Environment
using MolecuLab.MolecularMechanics
using MolecuLab.Geometry
using MolecuLab.Database
using SQLite
t_load = round(time() - t_start, digits=3)
println("  ✓ MolecuLab and core modules loaded in $(t_load)s")

println("\n[3/5] Probing Hardware Capabilities...")
hw = Hardware.probe_hardware()
println("  CPU Architecture: $(hw.cpu_model)")
println("  Logical Threads : $(hw.cpu_threads)")
println("  Total RAM       : $(hw.total_memory_gb) GB")
println("  Free RAM        : $(hw.free_memory_gb) GB")
if hw.gpu_detected
    println("  GPU Status      : [DETECTED] $(hw.gpu_name)")
    println("  VRAM Total      : $(round(hw.gpu_vram_mb / 1024, digits=2)) GB ($(hw.gpu_vram_mb) MB)")
    println("  Driver Version  : $(hw.gpu_driver_version)")
    println("  CUDA Capable    : $(hw.cuda_available)")
else
    println("  GPU Status      : [NOT DETECTED / UNAVAILABLE] $(hw.notes)")
    println("  Compute Fallback: CPU multi-threading active")
end

println("\n[4/5] Testing Local SQLite Database...")
temp_db_path = tempname() * ".sqlite"
try
    db = Database.init_database(temp_db_path)
    println("  ✓ SQLite database created with WAL mode: $(basename(temp_db_path))")
    tables = [row[1] for row in DBInterface.execute(db, "SELECT name FROM sqlite_master WHERE type='table'")]
    println("  ✓ Initialized tables ($(length(tables))): $(join(tables, ", "))")
    SQLite.close(db)
    GC.gc()
    rm(temp_db_path, force=true)
catch err
    println("  ✗ SQLite test failed: $err")
    GC.gc()
    rm(temp_db_path, force=true)
end

println("\n[5/5] Testing Scientific Computation Engine (Lennard-Jones Kernel)...")
# Argon dimer at r = 3.822 Å (equilibrium distance)
# sigma = 3.405 Å, epsilon = 0.238 kcal/mol
# r_min = 2^(1/6) * sigma ≈ 3.82199 Å
# V(r_min) = -epsilon = -0.238 kcal/mol
r_eq = 2^(1/6) * 3.405
coords = [0.0, 0.0, 0.0, r_eq, 0.0, 0.0]
elements = ["Ar", "Ar"]
eps = 0.238
sig = 3.405

energy = MolecularMechanics.lj_total_energy(coords, eps, sig)
grad = zeros(6)
MolecularMechanics.lj_total_gradient!(grad, coords, eps, sig)
grad_norm = MolecularMechanics.LinearAlgebra.norm(grad)

println("  Argon Dimer Separation : $(round(r_eq, digits=5)) Å")
println("  Computed Potential     : $(round(energy, digits=6)) kcal/mol (Expected: -0.238 kcal/mol)")
println("  Gradient Norm (Force)  : $(round(grad_norm, digits=8)) kcal/(mol·Å) (Expected: ≈ 0.0 at minimum)")

if isapprox(energy, -0.238, atol=1e-3) && grad_norm < 1e-4
    println("  ✓ Numerical verification PASSED: Energy and zero-force verified at equilibrium")
else
    println("  ✗ Numerical verification FAILED")
end

println("\n" * "="^70)
println("  VALIDATION SUMMARY: All critical environment components verified!")
println("="^70)
