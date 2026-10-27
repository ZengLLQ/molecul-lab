"""
Analytical geometric calculations for 3D molecular coordinates.
Enforces numerical safeguards against NaN, Inf, and singular collinear/coincident configurations.
"""
module Geometry

using LinearAlgebra
using ..Structures: Atom, coords

export distance, bond_angle, dihedral_angle, center_of_mass, bounding_box, radius_of_gyration

const GEOM_EPSILON = 1e-12

"""
    distance(p1::NTuple{3, Float64}, p2::NTuple{3, Float64}) -> Float64

Euclidean distance in Angstroms between two points.
"""
function distance(p1::NTuple{3, Float64}, p2::NTuple{3, Float64})::Float64
    dx = p1[1] - p2[1]
    dy = p1[2] - p2[2]
    dz = p1[3] - p2[3]
    return sqrt(dx*dx + dy*dy + dz*dz)
end

distance(a1::Atom, a2::Atom) = distance(coords(a1), coords(a2))

"""
    bond_angle(p1::NTuple{3, Float64}, p2::NTuple{3, Float64}, p3::NTuple{3, Float64}) -> Float64

Angle in radians at central vertex `p2` between vectors `p1 - p2` and `p3 - p2`.
Returns value in range [0, π].
Throws `DomainError` if any two points are coincident.
"""
function bond_angle(p1::NTuple{3, Float64}, p2::NTuple{3, Float64}, p3::NTuple{3, Float64})::Float64
    u = (p1[1] - p2[1], p1[2] - p2[2], p1[3] - p2[3])
    v = (p3[1] - p2[1], p3[2] - p2[2], p3[3] - p2[3])

    norm_u = sqrt(u[1]^2 + u[2]^2 + u[3]^2)
    norm_v = sqrt(v[1]^2 + v[2]^2 + v[3]^2)

    if norm_u < GEOM_EPSILON || norm_v < GEOM_EPSILON
        throw(DomainError((norm_u, norm_v), "Coincident atoms detected in bond angle calculation"))
    end

    dot_prod = (u[1]*v[1] + u[2]*v[2] + u[3]*v[3]) / (norm_u * norm_v)
    clamped_cos = clamp(dot_prod, -1.0, 1.0)
    return acos(clamped_cos)
end

bond_angle(a1::Atom, a2::Atom, a3::Atom) = bond_angle(coords(a1), coords(a2), coords(a3))

"""
    dihedral_angle(p1, p2, p3, p4) -> Float64

Signed torsion/dihedral angle in radians for the chain p1-p2-p3-p4.
Returns value in range [-π, π].
Throws `DomainError` if consecutive atoms are coincident or bond vectors are collinear.
"""
function dihedral_angle(p1::NTuple{3, Float64}, p2::NTuple{3, Float64},
                        p3::NTuple{3, Float64}, p4::NTuple{3, Float64})::Float64
    b1 = (p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3])
    b2 = (p3[1] - p2[1], p3[2] - p2[2], p3[3] - p2[3])
    b3 = (p4[1] - p3[1], p4[2] - p3[2], p4[3] - p3[3])

    norm_b2 = sqrt(b2[1]^2 + b2[2]^2 + b2[3]^2)
    if norm_b2 < GEOM_EPSILON
        throw(DomainError(norm_b2, "Central bond atoms are coincident in dihedral calculation"))
    end

    # Normal vectors to the two intersecting planes
    # n1 = b1 x b2
    n1 = (b1[2]*b2[3] - b1[3]*b2[2],
          b1[3]*b2[1] - b1[1]*b2[3],
          b1[1]*b2[2] - b1[2]*b2[1])

    # n2 = b2 x b3
    n2 = (b2[2]*b3[3] - b2[3]*b3[2],
          b2[3]*b3[1] - b2[1]*b3[3],
          b2[1]*b3[2] - b2[2]*b3[1])

    norm_n1 = sqrt(n1[1]^2 + n1[2]^2 + n1[3]^2)
    norm_n2 = sqrt(n2[1]^2 + n2[2]^2 + n2[3]^2)

    if norm_n1 < GEOM_EPSILON || norm_n2 < GEOM_EPSILON
        throw(DomainError((norm_n1, norm_n2), "Collinear vectors in dihedral calculation (planes undefined)"))
    end

    # Unit vector along b2
    u_b2 = (b2[1]/norm_b2, b2[2]/norm_b2, b2[3]/norm_b2)

    # m = n1 x u_b2
    m = (n1[2]*u_b2[3] - n1[3]*u_b2[2],
         n1[3]*u_b2[1] - n1[1]*u_b2[3],
         n1[1]*u_b2[2] - n1[2]*u_b2[1])

    # x = n1 . n2, y = m . n2
    x = n1[1]*n2[1] + n1[2]*n2[2] + n1[3]*n2[3]
    y = m[1]*n2[1] + m[2]*n2[2] + m[3]*n2[3]

    return atan(y, x)
end

dihedral_angle(a1::Atom, a2::Atom, a3::Atom, a4::Atom) =
    dihedral_angle(coords(a1), coords(a2), coords(a3), coords(a4))

"""
    center_of_mass(atoms::Vector{Atom}) -> NTuple{3, Float64}

Computes the mass-weighted center of mass (or geometric centroid if masses are zero).
"""
function center_of_mass(atoms::Vector{Atom})::NTuple{3, Float64}
    isempty(atoms) && return (0.0, 0.0, 0.0)

    total_mass = sum(a -> a.mass > 0 ? a.mass : 1.0, atoms)
    cx = sum(a -> (a.mass > 0 ? a.mass : 1.0) * a.x, atoms) / total_mass
    cy = sum(a -> (a.mass > 0 ? a.mass : 1.0) * a.y, atoms) / total_mass
    cz = sum(a -> (a.mass > 0 ? a.mass : 1.0) * a.z, atoms) / total_mass

    return (cx, cy, cz)
end

"""
    bounding_box(atoms::Vector{Atom}) -> Tuple{NTuple{3, Float64}, NTuple{3, Float64}}

Computes (min_coords, max_coords) for the given atoms.
"""
function bounding_box(atoms::Vector{Atom})::Tuple{NTuple{3, Float64}, NTuple{3, Float64}}
    isempty(atoms) && return ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))

    min_x = minimum(a -> a.x, atoms)
    min_y = minimum(a -> a.y, atoms)
    min_z = minimum(a -> a.z, atoms)

    max_x = maximum(a -> a.x, atoms)
    max_y = maximum(a -> a.y, atoms)
    max_z = maximum(a -> a.z, atoms)

    return ((min_x, min_y, min_z), (max_x, max_y, max_z))
end

"""
    radius_of_gyration(atoms::Vector{Atom}) -> Float64

Computes the mass-weighted radius of gyration in Angstroms:
Rg = sqrt( sum(m_i * ||r_i - r_com||^2) / sum(m_i) )
"""
function radius_of_gyration(atoms::Vector{Atom})::Float64
    isempty(atoms) && return 0.0
    com = center_of_mass(atoms)
    total_mass = sum(a -> a.mass > 0 ? a.mass : 1.0, atoms)

    sq_dist_sum = sum(atoms) do a
        m = a.mass > 0 ? a.mass : 1.0
        d2 = (a.x - com[1])^2 + (a.y - com[2])^2 + (a.z - com[3])^2
        m * d2
    end

    return sqrt(sq_dist_sum / total_mass)
end

end # module Geometry
