using Test
using Aqua
using MolecuLab

@testset "Aqua.jl Quality & Hygiene Assurance" begin
    Aqua.test_unbound_args(MolecuLab)
    Aqua.test_undefined_exports(MolecuLab)
    Aqua.test_stale_deps(MolecuLab; ignore=[:Aqua, :AtomsBase, :Unitful, :MolecularGraph, :Test])
end
