using Test
using MolecuLab

@testset "Geometry Optimization & Convergence Truthfulness" begin
    epsilon = 1.0  # kJ/mol
    sigma = 3.40   # Angstrom
    r_target = (2.0)^(1.0 / 6.0) * sigma # ~3.81637 Å

    # Argon dimer at non-equilibrium distance (4.5 Å)
    argon_atoms = [
        Atom(1, "Ar", 18, 0.0, 0.0, 0.0, 39.95),
        Atom(2, "Ar", 18, 4.5, 0.0, 0.0, 39.95)
    ]
    struct_dimer = Structure("s-test-01", "m-test-01", "Argon Dimer", argon_atoms)

    # 1. Full optimization to convergence
    config_conv = Dict{String, Any}(
        "epsilon" => epsilon,
        "sigma" => sigma,
        "g_tol" => 1e-5,
        "f_tol" => 1e-8,
        "max_iterations" => 150,
        "algorithm" => "bfgs"
    )

    res = optimize_geometry(struct_dimer, config_conv)
    @test res["converged"] == true
    @test res["termination_status"] == "converged"
    @test res["final_energy"] ≈ -epsilon atol=1e-4

    opt_atoms = res["optimized_atoms"]
    d_final = distance(opt_atoms[1], opt_atoms[2])
    @test d_final ≈ r_target atol=1e-4
    @test res["gradient_norm"] < 1e-4

    # 2. Strict Truthfulness Test: Max Iterations reached
    # Setting max_iterations to 1 must NOT report converged
    config_cutoff = Dict{String, Any}(
        "epsilon" => epsilon,
        "sigma" => sigma,
        "g_tol" => 1e-12,
        "f_tol" => 1e-12,
        "max_iterations" => 1,
        "algorithm" => "bfgs"
    )
    res_cutoff = optimize_geometry(struct_dimer, config_cutoff)
    @test res_cutoff["converged"] == false
    @test res_cutoff["termination_status"] == "stopped_max_iterations"
end
