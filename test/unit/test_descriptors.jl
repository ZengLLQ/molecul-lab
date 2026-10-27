using Test
using MolecuLab

@testset "Topological Descriptors & Periodic Table" begin
    # 1. Water H2O
    water_atoms = [
        Atom(1, "O", 8, 0.0, 0.0, 0.0, 15.999),
        Atom(2, "H", 1, 0.957, 0.0, 0.0, 1.008),
        Atom(3, "H", 1, -0.240, 0.927, 0.0, 1.008)
    ]
    @test molecular_formula(water_atoms) == "H2O"
    @test molecular_weight(water_atoms) ≈ 18.015 atol=1e-3
    @test heavy_atom_count(water_atoms) == 1
    @test formal_charge_sum(water_atoms) == 0

    # 2. Ethanol C2H6O
    ethanol_atoms = [
        Atom(1, "C", 6, -1.18, 0.31, 0.0, 12.011),
        Atom(2, "C", 6, 0.0, -0.55, 0.0, 12.011),
        Atom(3, "O", 8, 1.18, 0.24, 0.0, 15.999),
        Atom(4, "H", 1, 0.0, 0.0, 0.0, 1.008),
        Atom(5, "H", 1, 0.0, 0.0, 0.0, 1.008),
        Atom(6, "H", 1, 0.0, 0.0, 0.0, 1.008),
        Atom(7, "H", 1, 0.0, 0.0, 0.0, 1.008),
        Atom(8, "H", 1, 0.0, 0.0, 0.0, 1.008),
        Atom(9, "H", 1, 0.0, 0.0, 0.0, 1.008)
    ]
    @test molecular_formula(ethanol_atoms) == "C2H6O"
    @test molecular_weight(ethanol_atoms) ≈ 46.069 atol=1e-2
    @test heavy_atom_count(ethanol_atoms) == 3

    # 3. Validation checks
    errors, warnings = validate_structure(water_atoms)
    @test isempty(errors)

    # Clashing atoms validation
    clash_atoms = [
        Atom(1, "C", 6, 0.0, 0.0, 0.0, 12.0),
        Atom(2, "C", 6, 0.2, 0.0, 0.0, 12.0) # < 0.5 A clash
    ]
    c_errs, _ = validate_structure(clash_atoms)
    @test !isempty(c_errs)
    @test occursin("Severe atomic clash", c_errs[1])
end
