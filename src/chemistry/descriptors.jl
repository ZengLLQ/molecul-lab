"""
Topological and physicochemical descriptors for molecular structures.
Uses standard atomic parameters and Hill system notation.
"""
module Descriptors

using ..Structures: Atom

export molecular_formula, molecular_weight, heavy_atom_count, formal_charge_sum,
       element_data, cpk_color_hex, vdw_radius_angstrom, covalent_radius_angstrom

struct ElementInfo
    symbol::String
    name::String
    atomic_number::Int
    atomic_mass::Float64   # standard atomic weight in amu
    covalent_radius::Float64 # in Angstroms
    vdw_radius::Float64      # in Angstroms
    cpk_color::String        # Hex color string "#RRGGBB"
end

# Canonical elements data (IUPAC standard atomic weights)
const ELEMENT_TABLE = Dict{String, ElementInfo}(
    "H"  => ElementInfo("H",  "Hydrogen",   1,   1.008, 0.31, 1.20, "#FFFFFF"),
    "He" => ElementInfo("He", "Helium",     2,   4.0026, 0.28, 1.40, "#D9FFFF"),
    "Li" => ElementInfo("Li", "Lithium",    3,   6.94,   1.28, 1.82, "#CC80FF"),
    "Be" => ElementInfo("Be", "Beryllium",  4,   9.0122, 0.96, 1.53, "#C2FF00"),
    "B"  => ElementInfo("B",  "Boron",      5,  10.81,   0.84, 1.92, "#FFB5B5"),
    "C"  => ElementInfo("C",  "Carbon",     6,  12.011,  0.76, 1.70, "#909090"),
    "N"  => ElementInfo("N",  "Nitrogen",   7,  14.007,  0.71, 1.55, "#3050F8"),
    "O"  => ElementInfo("O",  "Oxygen",     8,  15.999,  0.66, 1.52, "#FF0D0D"),
    "F"  => ElementInfo("F",  "Fluorine",   9,  18.998,  0.57, 1.47, "#90E050"),
    "Ne" => ElementInfo("Ne", "Neon",      10,  20.180,  0.58, 1.54, "#B3E3F5"),
    "Na" => ElementInfo("Na", "Sodium",    11,  22.990,  1.66, 2.27, "#AB5CF2"),
    "Mg" => ElementInfo("Mg", "Magnesium", 12,  24.305,  1.41, 1.73, "#8AFF00"),
    "Al" => ElementInfo("Al", "Aluminium", 13,  26.982,  1.21, 1.84, "#BFA6A6"),
    "Si" => ElementInfo("Si", "Silicon",   14,  28.085,  1.11, 2.10, "#F0C8A0"),
    "P"  => ElementInfo("P",  "Phosphorus",15,  30.974,  1.07, 1.80, "#FF8000"),
    "S"  => ElementInfo("S",  "Sulfur",    16,  32.06,   1.05, 1.80, "#FFFF30"),
    "Cl" => ElementInfo("Cl", "Chlorine",  17,  35.45,   1.02, 1.75, "#1FF01F"),
    "Ar" => ElementInfo("Ar", "Argon",     18,  39.95,   1.06, 1.88, "#80D1E3"),
    "K"  => ElementInfo("K",  "Potassium", 19,  39.098,  2.03, 2.75, "#8F40D4"),
    "Ca" => ElementInfo("Ca", "Calcium",   20,  40.078,  1.76, 2.31, "#3DFF00"),
    "Fe" => ElementInfo("Fe", "Iron",      26,  55.845,  1.32, 2.00, "#E06633"),
    "Cu" => ElementInfo("Cu", "Copper",    29,  63.546,  1.32, 1.40, "#C88033"),
    "Zn" => ElementInfo("Zn", "Zinc",      30,  65.38,   1.22, 1.39, "#7D80B0"),
    "Br" => ElementInfo("Br", "Bromine",   35,  79.904,  1.20, 1.85, "#A62929"),
    "I"  => ElementInfo("I",  "Iodine",    53, 126.90,   1.39, 1.98, "#940094")
)

function element_data(sym::AbstractString)::ElementInfo
    s = uppercase(first(strip(sym))) * lowercase(strip(sym)[2:end])
    if haskey(ELEMENT_TABLE, s)
        return ELEMENT_TABLE[s]
    end
    # Fallback for unknown element
    return ElementInfo(s, "Unknown", 0, 0.0, 1.0, 1.70, "#E0E0E0")
end

cpk_color_hex(sym::AbstractString) = element_data(sym).cpk_color
vdw_radius_angstrom(sym::AbstractString) = element_data(sym).vdw_radius
covalent_radius_angstrom(sym::AbstractString) = element_data(sym).covalent_radius

"""
    molecular_formula(atoms::Vector{Atom}) -> String

Generates the molecular formula using Hill system notation:
- Carbon (C) first (if present), followed by Hydrogen (H).
- All other elements follow in alphabetical order.
- Elements with count 1 do not have a numerical subscript.
"""
function molecular_formula(atoms::Vector{Atom})::String
    isempty(atoms) && return ""

    counts = Dict{String, Int}()
    for a in atoms
        sym = a.symbol
        counts[sym] = get(counts, sym, 0) + 1
    end

    buf = IOBuffer()
    # 1. Carbon first
    if haskey(counts, "C")
        print(buf, "C")
        counts["C"] > 1 && print(buf, counts["C"])
        delete!(counts, "C")

        # 2. Hydrogen second if Carbon is present
        if haskey(counts, "H")
            print(buf, "H")
            counts["H"] > 1 && print(buf, counts["H"])
            delete!(counts, "H")
        end
    end

    # 3. Remaining elements in alphabetical order
    sorted_syms = sort(collect(keys(counts)))
    for sym in sorted_syms
        print(buf, sym)
        counts[sym] > 1 && print(buf, counts[sym])
    end

    return String(take!(buf))
end

"""
    molecular_weight(atoms::Vector{Atom}) -> Float64

Calculates standard molecular weight in amu (g/mol).
"""
function molecular_weight(atoms::Vector{Atom})::Float64
    sum(atoms) do a
        a.mass > 0 ? a.mass : element_data(a.symbol).atomic_mass
    end
end

"""
    heavy_atom_count(atoms::Vector{Atom}) -> Int

Count of non-hydrogen atoms.
"""
function heavy_atom_count(atoms::Vector{Atom})::Int
    count(a -> a.symbol != "H", atoms)
end

"""
    formal_charge_sum(atoms::Vector{Atom}) -> Int

Total formal charge of the molecule.
"""
function formal_charge_sum(atoms::Vector{Atom})::Int
    sum(a -> a.formal_charge, atoms; init=0)
end

end # module Descriptors
