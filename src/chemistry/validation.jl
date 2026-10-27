"""
Chemical and structural validation routines.
Detects unphysical coordinates, overlapping atoms, NaN/Inf, and topology issues.
"""
module Validation

using ..Structures: Atom, Bond, Structure
using ..Geometry: distance

export validate_structure, has_blocking_errors

const MIN_INTERATOMIC_DISTANCE = 0.5 # Angstroms; distances below this indicate serious clash/singularity

"""
    validate_structure(atoms::Vector{Atom}, bonds::Vector{Bond}=Bond[]) -> Tuple{Vector{String}, Vector{String}}

Validates structural integrity.
Returns `(errors, warnings)`:
- `errors`: Blocking issues preventing calculations (NaN/Inf, coincident atoms, empty structure, invalid bond indices).
- `warnings`: Informational observations (unusual bond lengths, missing hydrogens).
"""
function validate_structure(atoms::Vector{Atom}, bonds::Vector{Bond}=Bond[])::Tuple{Vector{String}, Vector{String}}
    errors = String[]
    warnings = String[]

    # 1. Emptiness check
    if isempty(atoms)
        push!(errors, "Structure contains no atoms.")
        return (errors, warnings)
    end

    n_atoms = length(atoms)

    # 2. Coordinate validity (no NaN or Inf)
    for a in atoms
        if !isfinite(a.x) || !isfinite(a.y) || !isfinite(a.z)
            push!(errors, "Atom $(a.index) ($(a.symbol)) has invalid non-finite coordinates: ($(a.x), $(a.y), $(a.z)).")
        end
        if a.index < 1 || a.index > n_atoms
            push!(errors, "Atom $(a.index) has out-of-range index (expected 1 to $n_atoms).")
        end
    end

    # 3. Pairwise interatomic clash check
    for i in 1:n_atoms
        for j in (i+1):n_atoms
            d = distance((atoms[i].x, atoms[i].y, atoms[i].z), (atoms[j].x, atoms[j].y, atoms[j].z))
            if d < 1e-6
                push!(errors, "Coincident atoms detected: Atom $i ($(atoms[i].symbol)) and Atom $j ($(atoms[j].symbol)) are at the exact same location (d = $(round(d, digits=4)) Å).")
            elseif d < MIN_INTERATOMIC_DISTANCE
                push!(errors, "Severe atomic clash: Atom $i ($(atoms[i].symbol)) and Atom $j ($(atoms[j].symbol)) are too close (d = $(round(d, digits=3)) Å < $MIN_INTERATOMIC_DISTANCE Å).")
            end
        end
    end

    # 4. Bond validation
    for (idx, b) in enumerate(bonds)
        if b.atom1 < 1 || b.atom1 > n_atoms || b.atom2 < 1 || b.atom2 > n_atoms
            push!(errors, "Bond $idx connects invalid atom indices ($(b.atom1), $(b.atom2)). Total atoms: $n_atoms.")
        else
            d = distance((atoms[b.atom1].x, atoms[b.atom1].y, atoms[b.atom1].z),
                         (atoms[b.atom2].x, atoms[b.atom2].y, atoms[b.atom2].z))
            if d > 3.5
                push!(warnings, "Unusually long bond between Atom $(b.atom1) ($(atoms[b.atom1].symbol)) and Atom $(b.atom2) ($(atoms[b.atom2].symbol)): $(round(d, digits=2)) Å.")
            end
        end
    end

    # 5. Missing hydrogens check (heuristic warning)
    has_h = any(a -> a.symbol == "H", atoms)
    has_heavy = any(a -> a.symbol != "H", atoms)
    if has_heavy && !has_h && n_atoms > 1
        push!(warnings, "Structure contains no explicit Hydrogen atoms. Verify protonation state if calculating all-atom potentials.")
    end

    return (errors, warnings)
end

validate_structure(s::Structure) = validate_structure(s.atoms, s.bonds)

has_blocking_errors(errors::Vector{String}) = !isempty(errors)

end # module Validation
