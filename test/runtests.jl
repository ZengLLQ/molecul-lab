using Test
using MolecuLab

@testset "MolecuLab Complete Test Suite" begin
    @info "Running Unit Tests: Geometry..."
    include("unit/test_geometry.jl")

    @info "Running Unit Tests: Descriptors..."
    include("unit/test_descriptors.jl")

    @info "Running Scientific Tests: Lennard-Jones Potential..."
    include("scientific/test_lennard_jones.jl")

    @info "Running Scientific Tests: Geometry Optimization..."
    include("scientific/test_optimization.jl")

    @info "Running Scientific Tests: Molecular Dynamics..."
    include("scientific/test_molecular_dynamics.jl")

    @info "Running Integration Tests: Storage & Project Lifecycle..."
    include("integration/test_storage_project.jl")

    @info "Running Package Hygiene: Aqua.jl..."
    include("unit/test_aqua.jl")
end
