"""
Domain definitions for atoms, chemical bonds, and molecular 3D structures.
"""
module Structures

export Atom, Bond, Structure, count_atoms, count_bonds

"""
    Atom

Represents a single atom with 3D Cartesian coordinates in Angstroms.
"""
struct Atom
    index::Int
    symbol::String
    atomic_number::Int
    x::Float64
    y::Float64
    z::Float64
    mass::Float64          # in amu
    formal_charge::Int

    function Atom(index::Int, symbol::AbstractString, atomic_number::Int,
                  x::Real, y::Real, z::Real, mass::Real=0.0, formal_charge::Int=0)
        sym = uppercase(first(strip(symbol))) * lowercase(strip(symbol)[2:end])
        new(index, sym, atomic_number, Float64(x), Float64(y), Float64(z), Float64(mass), formal_charge)
    end
end

"""
    coords(a::Atom) -> NTuple{3, Float64}
"""
coords(a::Atom) = (a.x, a.y, a.z)

"""
    Bond

Represents a chemical bond between two atom indices (1-based).
"""
struct Bond
    atom1::Int
    atom2::Int
    order::Float64    # 1.0 (single), 2.0 (double), 3.0 (triple), 1.5 (aromatic)

    function Bond(atom1::Int, atom2::Int, order::Real=1.0)
        @assert atom1 != atom2 "Bond cannot connect an atom to itself (atom1 == atom2 == $atom1)"
        @assert order > 0.0 "Bond order must be strictly positive"
        new(min(atom1, atom2), max(atom1, atom2), Float64(order))
    end
end

"""
    Structure

Represents an immutable 3D molecular geometry with topology.
"""
struct Structure
    id::String
    molecule_id::String
    name::String
    atoms::Vector{Atom}
    bonds::Vector{Bond}
    coordinate_unit::String    # "Angstrom"
    source_hash::String        # SHA-256 of the source file / data
    warnings::Vector{String}
    created_at::String

    function Structure(id::AbstractString, molecule_id::AbstractString, name::AbstractString,
                       atoms::Vector{Atom}, bonds::Vector{Bond}=Bond[];
                       coordinate_unit::AbstractString="Angstrom",
                       source_hash::AbstractString="",
                       warnings::Vector{String}=String[],
                       created_at::AbstractString="")
        new(String(id), String(molecule_id), String(name), atoms, bonds,
            String(coordinate_unit), String(source_hash), warnings, String(created_at))
    end
end

count_atoms(s::Structure) = length(s.atoms)
count_bonds(s::Structure) = length(s.bonds)

end # module Structures
