using Test
using LinearAlgebra
using MolecuLab

@testset "Lennard-Jones Reference Potential & Gradients" begin
    epsilon = 1.65 # kJ/mol
    sigma = 3.40   # Angstrom

    # 1. Zero-crossing point: V(sigma) == 0.0
    @test abs(lj_pair_potential(sigma, epsilon, sigma)) < 1e-12

    # 2. Analytical minimum: r_e = 2^(1/6) * sigma
    r_e = (2.0)^(1.0 / 6.0) * sigma
    v_min = lj_pair_potential(r_e, epsilon, sigma)
    @test v_min ≈ -epsilon atol=1e-10

    # 3. Force at equilibrium distance must be zero
    f_at_min = lj_pair_force((r_e, 0.0, 0.0), r_e, epsilon, sigma)
    @test norm(f_at_min) < 1e-10

    # 4. Asymptotic behavior: V(r) -> 0 as r -> inf
    @test abs(lj_pair_potential(100.0 * sigma, epsilon, sigma)) < 1e-6

    # 5. Singularity defense: r -> 0 does not return NaN or Inf
    @test isfinite(lj_pair_potential(0.01, epsilon, sigma))
    @test isfinite(lj_pair_potential(0.001, epsilon, sigma))

    # 6. Rigorous Finite-Difference Gradient Verification
    # Construct a 4-particle non-symmetric cluster
    x = [
        0.0, 0.0, 0.0,   # Atom 1
        3.2, 0.5, 0.1,   # Atom 2
        1.1, 3.5, -0.4,  # Atom 3
        -0.8, 1.2, 3.3   # Atom 4
    ]

    grad_anal = similar(x)
    lj_total_gradient!(grad_anal, x, epsilon, sigma)

    grad_fd = finite_difference_gradient(x, epsilon, sigma, 1e-6)

    # Check that analytical gradient matches central differences to high precision
    for k in eachindex(x)
        @test grad_anal[k] ≈ grad_fd[k] rtol=1e-5 atol=1e-5
    end
end
