using Test
using MolecuLab

@testset "Geometry Calculations & Singularities" begin
    # 1. Distance tests
    p1 = (0.0, 0.0, 0.0)
    p2 = (3.0, 4.0, 0.0)
    @test distance(p1, p2) ≈ 5.0 atol=1e-12

    p3 = (1.0, 2.0, 3.0)
    p4 = (4.0, 6.0, 15.0) # dx=3, dy=4, dz=12 => sqrt(9+16+144) = sqrt(169) = 13.0
    @test distance(p3, p4) ≈ 13.0 atol=1e-12

    # 2. Bond angle tests
    # 90-degree right angle (X-axis, Origin, Y-axis)
    a1 = (1.0, 0.0, 0.0)
    a2 = (0.0, 0.0, 0.0) # vertex
    a3 = (0.0, 1.0, 0.0)
    @test bond_angle(a1, a2, a3) ≈ π / 2.0 atol=1e-12

    # 180-degree linear configuration
    a4 = (-1.0, 0.0, 0.0)
    @test bond_angle(a1, a2, a4) ≈ π atol=1e-12

    # 60-degree equilateral triangle
    a5 = (0.5, sqrt(3)/2, 0.0)
    @test bond_angle(a1, a2, a5) ≈ π / 3.0 atol=1e-12

    # Coincident atom exception
    @test_throws DomainError bond_angle(a1, a1, a3)

    # 3. Dihedral angle tests
    # Cis configuration (torsion = 0)
    d1 = (0.0, 1.0, 0.0)
    d2 = (0.0, 0.0, 0.0)
    d3 = (1.0, 0.0, 0.0)
    d4 = (1.0, 1.0, 0.0)
    @test abs(dihedral_angle(d1, d2, d3, d4)) ≈ 0.0 atol=1e-10

    # Trans configuration (torsion = π or -π)
    d5 = (1.0, -1.0, 0.0)
    @test abs(dihedral_angle(d1, d2, d3, d5)) ≈ π atol=1e-10

    # Orthogonal twist (-90 degrees = -π/2)
    d6 = (1.0, 0.0, 1.0)
    @test dihedral_angle(d1, d2, d3, d6) ≈ -π / 2.0 atol=1e-10

    # Collinear vectors exception
    col1 = (0.0, 0.0, 0.0)
    col2 = (1.0, 0.0, 0.0)
    col3 = (2.0, 0.0, 0.0)
    col4 = (3.0, 0.0, 0.0)
    @test_throws DomainError dihedral_angle(col1, col2, col3, col4)

    # 4. Center of mass & Bounding box
    atoms = [
        Atom(1, "C", 6, -1.0, 0.0, 0.0, 12.0),
        Atom(2, "C", 6,  1.0, 0.0, 0.0, 12.0)
    ]
    @test center_of_mass(atoms) == (0.0, 0.0, 0.0)

    bbox_min, bbox_max = bounding_box(atoms)
    @test bbox_min == (-1.0, 0.0, 0.0)
    @test bbox_max == (1.0, 0.0, 0.0)

    @test radius_of_gyration(atoms) ≈ 1.0 atol=1e-12
end
