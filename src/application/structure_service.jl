"""
Application Service for molecular structures, conformers, and descriptors.
"""
module StructureService

using UUIDs
using Dates
using JSON3
using ..Projects: Project
using ..Molecules: Molecule
using ..Structures: Structure, Atom, Bond
using ..Descriptors: molecular_formula, molecular_weight
using ..Validation: validate_structure
using ..Importers: import_structure_file
using ..ProjectService: get_project_db
using ..Database: save_molecule!, load_molecules,
                  save_structure!, load_structure, load_structures_for_molecule
using ..Artifacts: write_atomic

export import_structure_to_project, add_structure_to_molecule,
       get_project_molecules, get_molecule_structures, get_structure_by_id

"""
    import_structure_to_project(project::Project, filepath::AbstractString;
                               molecule_name::AbstractString="") -> Tuple{Molecule, Structure}

Imports an external structure file into the project, registering the molecule and initial conformer.
"""
function import_structure_to_project(project::Project, filepath::AbstractString;
                                    molecule_name::AbstractString="")::Tuple{Molecule, Structure}
    parsed = import_structure_file(filepath)

    mol_id = string(uuid4())
    struct_id = string(uuid4())
    now_iso = string(Dates.now(Dates.UTC))

    mol_name = isempty(strip(molecule_name)) ? parsed.name : strip(molecule_name)
    formula = molecular_formula(parsed.atoms)
    mw = molecular_weight(parsed.atoms)

    mol = Molecule(mol_id, project.id, mol_name;
                   formula=formula,
                   molecular_weight=mw,
                   structure_ids=[struct_id],
                   created_at=now_iso)

    structure = Structure(struct_id, mol_id, "Conformer 1", parsed.atoms, parsed.bonds;
                          coordinate_unit=parsed.coordinate_unit,
                          source_hash=parsed.source_hash,
                          warnings=parsed.warnings,
                          created_at=now_iso)

    # Persist in SQLite
    db = get_project_db(project)
    save_molecule!(db, mol)
    save_structure!(db, structure)

    # Write immutable structure snapshot
    snapshot_dir = joinpath(project.root_path, "structures", "snapshots")
    snapshot_file = joinpath(snapshot_dir, struct_id * ".json")
    atoms_dict = [Dict("index" => a.index, "symbol" => a.symbol, "atomic_number" => a.atomic_number,
                       "x" => a.x, "y" => a.y, "z" => a.z, "mass" => a.mass, "formal_charge" => a.formal_charge) for a in structure.atoms]
    bonds_dict = [Dict("atom1" => b.atom1, "atom2" => b.atom2, "order" => b.order) for b in structure.bonds]
    snapshot_json = JSON3.write(Dict(
        "id" => structure.id,
        "molecule_id" => structure.molecule_id,
        "name" => structure.name,
        "atoms" => atoms_dict,
        "bonds" => bonds_dict,
        "source_hash" => structure.source_hash,
        "created_at" => structure.created_at
    ))
    write_atomic(snapshot_file, snapshot_json; artifact_type="application/json")

    return (mol, structure)
end

"""
    add_structure_to_molecule(project::Project, molecule_id::AbstractString,
                              name::AbstractString, atoms::Vector{Atom}, bonds::Vector{Bond}=Bond[]) -> Structure
"""
function add_structure_to_molecule(project::Project, molecule_id::AbstractString,
                                   name::AbstractString, atoms::Vector{Atom}, bonds::Vector{Bond}=Bond[])::Structure
    struct_id = string(uuid4())
    now_iso = string(Dates.now(Dates.UTC))

    errors, warnings = validate_structure(atoms, bonds)
    if !isempty(errors)
        error("Cannot add invalid structure:\n" * join(errors, "\n"))
    end

    structure = Structure(struct_id, String(molecule_id), String(name), atoms, bonds;
                          coordinate_unit="Angstrom",
                          warnings=warnings,
                          created_at=now_iso)

    db = get_project_db(project)
    save_structure!(db, structure)
    return structure
end

get_project_molecules(project::Project)::Vector{Molecule} =
    load_molecules(get_project_db(project), project.id)

get_molecule_structures(project::Project, molecule_id::AbstractString)::Vector{Structure} =
    load_structures_for_molecule(get_project_db(project), molecule_id)

get_structure_by_id(project::Project, structure_id::AbstractString)::Union{Structure, Nothing} =
    load_structure(get_project_db(project), structure_id)

end # module StructureService
