"""
Chemical structure format parsers: XYZ, MDL Molfile (V2000), and PDB.
Enforces strict coordinate validation and element symbol normalization.
"""
module Importers

using SHA
using ..Structures: Atom, Bond, Structure
using ..Descriptors: element_data
using ..Validation: validate_structure

export import_xyz, import_mol, import_pdb, import_structure_file

"""
    import_xyz(content::AbstractString; filename::AbstractString="molecule.xyz") -> Structure

Parses a standard .xyz Cartesian coordinate file.
"""
function import_xyz(content::AbstractString; filename::AbstractString="molecule.xyz")::Structure
    lines = [strip(l) for l in split(content, "\n") if !isempty(strip(l))]
    if length(lines) < 2
        error("Invalid XYZ format: requires at least 2 header lines (atom count + comment).")
    end

    n_atoms = tryparse(Int, lines[1])
    if isnothing(n_atoms) || n_atoms < 1
        error("Invalid XYZ format: line 1 must specify a positive integer atom count (got '$(lines[1])').")
    end

    comment = lines[2]
    atom_lines = lines[3:end]
    if length(atom_lines) < n_atoms
        error("Invalid XYZ format: specified $n_atoms atoms, but only $(length(atom_lines)) coordinate lines were provided.")
    end

    atoms = Atom[]
    for i in 1:n_atoms
        tokens = split(atom_lines[i])
        if length(tokens) < 4
            error("Invalid coordinate line in XYZ: '$(atom_lines[i])'. Expected: Symbol X Y Z")
        end
        sym = String(tokens[1])
        x = tryparse(Float64, tokens[2])
        y = tryparse(Float64, tokens[3])
        z = tryparse(Float64, tokens[4])
        if isnothing(x) || isnothing(y) || isnothing(z)
            error("Non-numeric coordinates in XYZ line $(i+2): '$(atom_lines[i])'")
        end

        edata = element_data(sym)
        push!(atoms, Atom(i, edata.symbol, edata.atomic_number, x, y, z, edata.atomic_mass, 0))
    end

    # Heuristic bond detection if none provided (covalent radius overlap)
    bonds = infer_covalent_bonds(atoms)
    errors, warnings = validate_structure(atoms, bonds)
    if !isempty(errors)
        error("Structure validation failed:\n" * join(errors, "\n"))
    end

    c_hash = bytes2hex(sha256(Vector{UInt8}(content)))
    name = isempty(comment) ? splitext(basename(filename))[1] : comment

    return Structure("struct-" * string(rand(UInt64), base=16),
                     "mol-" * string(rand(UInt64), base=16),
                     name, atoms, bonds;
                     coordinate_unit="Angstrom",
                     source_hash=c_hash,
                     warnings=warnings)
end

"""
    import_mol(content::AbstractString; filename::AbstractString="molecule.mol") -> Structure

Parses MDL Molfile / SDF format (V2000 connection table).
"""
function import_mol(content::AbstractString; filename::AbstractString="molecule.mol")::Structure
    lines = split(content, "\n")
    if length(lines) < 4
        error("Invalid Molfile: requires at least 4 header lines.")
    end

    title = strip(lines[1])
    # Line 4: Counts line: aaabbblllfffcccsssxxxrrrpppiiimmmvvvvv
    counts_line = lines[4]
    if length(counts_line) < 6
        error("Invalid Molfile: counts line too short ('$counts_line').")
    end

    n_atoms = tryparse(Int, strip(counts_line[1:3]))
    n_bonds = tryparse(Int, strip(counts_line[4:6]))
    if isnothing(n_atoms) || isnothing(n_bonds)
        error("Could not parse atom/bond counts from Molfile counts line: '$counts_line'")
    end

    if length(lines) < 4 + n_atoms + n_bonds
        error("Molfile truncated: expected $n_atoms atoms and $n_bonds bonds, but file has only $(length(lines)) lines.")
    end

    atoms = Atom[]
    for i in 1:n_atoms
        line = lines[4 + i]
        tokens = split(line)
        if length(tokens) < 4
            error("Invalid atom line in Molfile: '$line'")
        end
        x = parse(Float64, tokens[1])
        y = parse(Float64, tokens[2])
        z = parse(Float64, tokens[3])
        sym = String(tokens[4])
        edata = element_data(sym)
        push!(atoms, Atom(i, edata.symbol, edata.atomic_number, x, y, z, edata.atomic_mass, 0))
    end

    bonds = Bond[]
    for i in 1:n_bonds
        line = lines[4 + n_atoms + i]
        tokens = split(line)
        if length(tokens) < 2
            error("Invalid bond line in Molfile: '$line'")
        end
        a1 = parse(Int, tokens[1])
        a2 = parse(Int, tokens[2])
        order_code = length(tokens) >= 3 ? parse(Int, tokens[3]) : 1
        order = order_code == 4 ? 1.5 : Float64(order_code)
        push!(bonds, Bond(a1, a2, order))
    end

    errors, warnings = validate_structure(atoms, bonds)
    if !isempty(errors)
        error("Structure validation failed:\n" * join(errors, "\n"))
    end

    c_hash = bytes2hex(sha256(Vector{UInt8}(content)))
    name = isempty(title) ? splitext(basename(filename))[1] : title

    return Structure("struct-" * string(rand(UInt64), base=16),
                     "mol-" * string(rand(UInt64), base=16),
                     name, atoms, bonds;
                     coordinate_unit="Angstrom",
                     source_hash=c_hash,
                     warnings=warnings)
end

"""
    import_pdb(content::AbstractString; filename::AbstractString="molecule.pdb") -> Structure

Parses standard ATOM / HETATM coordinate records from a PDB file.
"""
function import_pdb(content::AbstractString; filename::AbstractString="molecule.pdb")::Structure
    lines = split(content, "\n")
    atoms = Atom[]
    bonds = Bond[]
    atom_idx = 1
    serial_to_idx = Dict{Int, Int}()

    for line in lines
        if startswith(line, "ATOM") || startswith(line, "HETATM")
            if length(line) < 54
                continue
            end
            serial = tryparse(Int, strip(line[7:11]))
            sym = strip(length(line) >= 78 ? line[77:78] : line[13:14])
            # Remove digits from element symbol (e.g., "1H" -> "H")
            sym = filter(c -> isletter(c), sym)
            x = parse(Float64, strip(line[31:38]))
            y = parse(Float64, strip(line[39:46]))
            z = parse(Float64, strip(line[47:54]))

            edata = element_data(sym)
            push!(atoms, Atom(atom_idx, edata.symbol, edata.atomic_number, x, y, z, edata.atomic_mass, 0))
            if !isnothing(serial)
                serial_to_idx[serial] = atom_idx
            end
            atom_idx += 1
        elseif startswith(line, "CONECT")
            tokens = split(line)
            if length(tokens) >= 3
                s1 = tryparse(Int, tokens[2])
                if !isnothing(s1) && haskey(serial_to_idx, s1)
                    idx1 = serial_to_idx[s1]
                    for t in tokens[3:end]
                        s2 = tryparse(Int, t)
                        if !isnothing(s2) && haskey(serial_to_idx, s2)
                            idx2 = serial_to_idx[s2]
                            if idx1 != idx2
                                # Avoid duplicate bonds
                                b = Bond(idx1, idx2, 1.0)
                                if !(b in bonds)
                                    push!(bonds, b)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if isempty(atoms)
        error("No ATOM or HETATM records found in PDB data.")
    end

    if isempty(bonds)
        bonds = infer_covalent_bonds(atoms)
    end

    errors, warnings = validate_structure(atoms, bonds)
    if !isempty(errors)
        error("Structure validation failed:\n" * join(errors, "\n"))
    end

    c_hash = bytes2hex(sha256(Vector{UInt8}(content)))
    name = splitext(basename(filename))[1]

    return Structure("struct-" * string(rand(UInt64), base=16),
                     "mol-" * string(rand(UInt64), base=16),
                     name, atoms, bonds;
                     coordinate_unit="Angstrom",
                     source_hash=c_hash,
                     warnings=warnings)
end

"""
    import_structure_file(filepath::AbstractString) -> Structure

Auto-detects format from extension (.xyz, .mol, .sdf, .pdb) and imports structure.
"""
function import_structure_file(filepath::AbstractString)::Structure
    if !isfile(filepath)
        error("File not found: $filepath")
    end
    ext = lowercase(splitext(filepath)[2])
    content = read(filepath, String)

    if ext == ".xyz"
        return import_xyz(content; filename=filepath)
    elseif ext in (".mol", ".sdf")
        return import_mol(content; filename=filepath)
    elseif ext in (".pdb", ".ent")
        return import_pdb(content; filename=filepath)
    else
        error("Unsupported file format '$ext'. Supported formats: .xyz, .mol, .sdf, .pdb")
    end
end

"""
    infer_covalent_bonds(atoms::Vector{Atom}; tolerance::Float64=0.45) -> Vector{Bond}

Heuristically infers covalent bonds based on sum of covalent radii + tolerance.
"""
function infer_covalent_bonds(atoms::Vector{Atom}; tolerance::Float64=0.45)::Vector{Bond}
    bonds = Bond[]
    n = length(atoms)
    for i in 1:n
        r1 = element_data(atoms[i].symbol).covalent_radius
        for j in (i+1):n
            r2 = element_data(atoms[j].symbol).covalent_radius
            max_covalent_dist = r1 + r2 + tolerance
            dx = atoms[i].x - atoms[j].x
            dy = atoms[i].y - atoms[j].y
            dz = atoms[i].z - atoms[j].z
            d = sqrt(dx*dx + dy*dy + dz*dz)
            if d > 0.4 && d <= max_covalent_dist
                push!(bonds, Bond(i, j, 1.0))
            end
        end
    end
    return bonds
end

end # module Importers
