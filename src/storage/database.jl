"""
SQLite database management, schema migrations, and relational persistence.
"""
module Database

using SQLite
using DBInterface
using JSON3
using ..Projects: Project
using ..Molecules: Molecule
using ..Structures: Structure, Atom, Bond
using ..Experiments: Experiment
using ..Results: JobState, Job, Result, Artifact

export init_database, get_cached_database, close_cached_database!,
       save_project!, load_project,
       save_molecule!, load_molecules,
       save_structure!, load_structure, load_structures_for_molecule,
       save_experiment!, load_experiment, load_experiments_for_project,
       save_job!, load_job,
       save_result!, load_result

const SCHEMA_VERSION = 1

const INIT_SQL = """
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_info (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    root_path TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    settings TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS molecules (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    name TEXT NOT NULL,
    formula TEXT NOT NULL,
    molecular_weight REAL NOT NULL,
    metadata TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS structures (
    id TEXT PRIMARY KEY,
    molecule_id TEXT NOT NULL,
    name TEXT NOT NULL,
    coordinate_unit TEXT NOT NULL,
    source_hash TEXT NOT NULL,
    atoms_json TEXT NOT NULL,
    bonds_json TEXT NOT NULL,
    warnings_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(molecule_id) REFERENCES molecules(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS experiments (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    structure_id TEXT NOT NULL,
    method_id TEXT NOT NULL,
    status TEXT NOT NULL,
    config_json TEXT NOT NULL,
    random_seed INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY(structure_id) REFERENCES structures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY,
    experiment_id TEXT NOT NULL,
    state TEXT NOT NULL,
    started_at TEXT,
    finished_at TEXT,
    error_summary TEXT,
    termination_reason TEXT,
    progress REAL NOT NULL,
    FOREIGN KEY(experiment_id) REFERENCES experiments(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS results (
    id TEXT PRIMARY KEY,
    experiment_id TEXT NOT NULL,
    final_energy REAL NOT NULL,
    gradient_norm REAL NOT NULL,
    iterations INTEGER NOT NULL,
    converged INTEGER NOT NULL,
    termination_status TEXT NOT NULL,
    metrics_json TEXT NOT NULL,
    artifacts_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(experiment_id) REFERENCES experiments(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_molecules_project ON molecules(project_id);
CREATE INDEX IF NOT EXISTS idx_structures_molecule ON structures(molecule_id);
CREATE INDEX IF NOT EXISTS idx_experiments_project ON experiments(project_id);
CREATE INDEX IF NOT EXISTS idx_jobs_experiment ON jobs(experiment_id);
CREATE INDEX IF NOT EXISTS idx_results_experiment ON results(experiment_id);
"""

"""
    init_database(db_path::AbstractString) -> SQLite.DB

Initializes or opens an SQLite database with the current schema.
"""
function init_database(db_path::AbstractString)::SQLite.DB
    dir = dirname(db_path)
    !isdir(dir) && mkpath(dir)

    db = SQLite.DB(db_path)
    # Execute DDL
    DBInterface.executemultiple(db, INIT_SQL)

    # Check schema version
    rows = DBInterface.execute(db, "SELECT version FROM schema_info WHERE version = $SCHEMA_VERSION")
    if isempty(rows)
        DBInterface.execute(db, "INSERT INTO schema_info (version, applied_at) VALUES ($SCHEMA_VERSION, datetime('now'))")
    end

    return db
end

const DB_CACHE = Dict{String, SQLite.DB}()
const DB_LOCK = ReentrantLock()

function get_cached_database(db_path::AbstractString)::SQLite.DB
    lock(DB_LOCK) do
        full_path = abspath(db_path)
        if !haskey(DB_CACHE, full_path)
            DB_CACHE[full_path] = init_database(full_path)
        end
        return DB_CACHE[full_path]
    end
end

function close_cached_database!(db_path::AbstractString)
    lock(DB_LOCK) do
        full_path = abspath(db_path)
        if haskey(DB_CACHE, full_path)
            db = DB_CACHE[full_path]
            delete!(DB_CACHE, full_path)
            try
                DBInterface.close!(db)
            catch
            end
        end
    end
end

# ----------------- Project CRUD -----------------
function save_project!(db::SQLite.DB, p::Project)
    stmt = SQLite.Stmt(db, """
        INSERT INTO projects (id, name, schema_version, root_path, created_at, updated_at, settings)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            updated_at = excluded.updated_at,
            settings = excluded.settings
    """)
    DBInterface.execute(stmt, (p.id, p.name, p.schema_version, p.root_path, p.created_at, p.updated_at, JSON3.write(p.settings)))
end

function load_project(db::SQLite.DB, id::AbstractString)::Union{Project, Nothing}
    stmt = SQLite.Stmt(db, "SELECT id, name, schema_version, root_path, created_at, updated_at, settings FROM projects WHERE id = ?")
    cursor = DBInterface.execute(stmt, (String(id),))
    for row in cursor
        settings = ismissing(row.settings) ? Dict{String, Any}() : JSON3.read(row.settings, Dict{String, Any})
        return Project(row.id, row.name, row.root_path;
                       schema_version=row.schema_version,
                       created_at=row.created_at,
                       updated_at=row.updated_at,
                       settings=settings)
    end
    return nothing
end

# ----------------- Molecule CRUD -----------------
function save_molecule!(db::SQLite.DB, m::Molecule)
    stmt = SQLite.Stmt(db, """
        INSERT INTO molecules (id, project_id, name, formula, molecular_weight, metadata, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            formula = excluded.formula,
            molecular_weight = excluded.molecular_weight,
            metadata = excluded.metadata
    """)
    DBInterface.execute(stmt, (m.id, m.project_id, m.name, m.formula, m.molecular_weight, JSON3.write(m.metadata), m.created_at))
end

function load_molecules(db::SQLite.DB, project_id::AbstractString)::Vector{Molecule}
    stmt = SQLite.Stmt(db, "SELECT id, project_id, name, formula, molecular_weight, metadata, created_at FROM molecules WHERE project_id = ? ORDER BY created_at ASC")
    cursor = DBInterface.execute(stmt, (String(project_id),))
    result = Molecule[]
    for row in cursor
        meta = ismissing(row.metadata) ? Dict{String, Any}() : JSON3.read(row.metadata, Dict{String, Any})
        push!(result, Molecule(row.id, row.project_id, row.name;
                               formula=row.formula,
                               molecular_weight=row.molecular_weight,
                               metadata=meta,
                               created_at=row.created_at))
    end
    return result
end

# ----------------- Structure CRUD -----------------
function atom_to_dict(a::Atom)::Dict{String, Any}
    Dict("index" => a.index, "symbol" => a.symbol, "atomic_number" => a.atomic_number,
         "x" => a.x, "y" => a.y, "z" => a.z, "mass" => a.mass, "formal_charge" => a.formal_charge)
end

function dict_to_atom(d)::Atom
    Atom(Int(d["index"]), String(d["symbol"]), Int(d["atomic_number"]),
         Float64(d["x"]), Float64(d["y"]), Float64(d["z"]),
         Float64(d["mass"]), Int(d["formal_charge"]))
end

function bond_to_dict(b::Bond)::Dict{String, Any}
    Dict("atom1" => b.atom1, "atom2" => b.atom2, "order" => b.order)
end

function dict_to_bond(d)::Bond
    Bond(Int(d["atom1"]), Int(d["atom2"]), Float64(d["order"]))
end

function save_structure!(db::SQLite.DB, s::Structure)
    atoms_data = [atom_to_dict(a) for a in s.atoms]
    bonds_data = [bond_to_dict(b) for b in s.bonds]

    stmt = SQLite.Stmt(db, """
        INSERT INTO structures (id, molecule_id, name, coordinate_unit, source_hash, atoms_json, bonds_json, warnings_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            atoms_json = excluded.atoms_json,
            bonds_json = excluded.bonds_json,
            warnings_json = excluded.warnings_json
    """)
    DBInterface.execute(stmt, (s.id, s.molecule_id, s.name, s.coordinate_unit, s.source_hash,
                               JSON3.write(atoms_data), JSON3.write(bonds_data), JSON3.write(s.warnings), s.created_at))
end

function load_structure(db::SQLite.DB, id::AbstractString)::Union{Structure, Nothing}
    stmt = SQLite.Stmt(db, "SELECT id, molecule_id, name, coordinate_unit, source_hash, atoms_json, bonds_json, warnings_json, created_at FROM structures WHERE id = ?")
    cursor = DBInterface.execute(stmt, (String(id),))
    for row in cursor
        atoms_raw = JSON3.read(row.atoms_json, Vector{Dict{String, Any}})
        bonds_raw = JSON3.read(row.bonds_json, Vector{Dict{String, Any}})
        warns_raw = ismissing(row.warnings_json) ? String[] : JSON3.read(row.warnings_json, Vector{String})

        atoms = [dict_to_atom(d) for d in atoms_raw]
        bonds = [dict_to_bond(d) for d in bonds_raw]

        return Structure(row.id, row.molecule_id, row.name, atoms, bonds;
                         coordinate_unit=row.coordinate_unit,
                         source_hash=row.source_hash,
                         warnings=warns_raw,
                         created_at=row.created_at)
    end
    return nothing
end

function load_structures_for_molecule(db::SQLite.DB, molecule_id::AbstractString)::Vector{Structure}
    stmt = SQLite.Stmt(db, "SELECT id FROM structures WHERE molecule_id = ? ORDER BY created_at ASC")
    cursor = DBInterface.execute(stmt, (String(molecule_id),))
    structures = Structure[]
    for row in cursor
        s = load_structure(db, row.id)
        !isnothing(s) && push!(structures, s)
    end
    return structures
end

# ----------------- Experiment CRUD -----------------
function save_experiment!(db::SQLite.DB, exp::Experiment)
    stmt = SQLite.Stmt(db, """
        INSERT INTO experiments (id, project_id, structure_id, method_id, status, config_json, random_seed, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            status = excluded.status,
            config_json = excluded.config_json,
            updated_at = excluded.updated_at
    """)
    DBInterface.execute(stmt, (exp.id, exp.project_id, exp.structure_id, exp.method_id,
                               exp.status, JSON3.write(exp.config), exp.random_seed, exp.created_at, exp.updated_at))
end

function load_experiment(db::SQLite.DB, id::AbstractString)::Union{Experiment, Nothing}
    stmt = SQLite.Stmt(db, "SELECT id, project_id, structure_id, method_id, status, config_json, random_seed, created_at, updated_at FROM experiments WHERE id = ?")
    cursor = DBInterface.execute(stmt, (String(id),))
    for row in cursor
        cfg = JSON3.read(row.config_json, Dict{String, Any})
        return Experiment(row.id, row.project_id, row.structure_id, row.method_id;
                          status=row.status,
                          config=cfg,
                          random_seed=row.random_seed,
                          created_at=row.created_at,
                          updated_at=row.updated_at)
    end
    return nothing
end

function load_experiments_for_project(db::SQLite.DB, project_id::AbstractString)::Vector{Experiment}
    stmt = SQLite.Stmt(db, "SELECT id FROM experiments WHERE project_id = ? ORDER BY created_at DESC")
    cursor = DBInterface.execute(stmt, (String(project_id),))
    exps = Experiment[]
    for row in cursor
        e = load_experiment(db, row.id)
        !isnothing(e) && push!(exps, e)
    end
    return exps
end

# ----------------- Job CRUD -----------------
function save_job!(db::SQLite.DB, j::Job)
    stmt = SQLite.Stmt(db, """
        INSERT INTO jobs (id, experiment_id, state, started_at, finished_at, error_summary, termination_reason, progress)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            state = excluded.state,
            finished_at = excluded.finished_at,
            error_summary = excluded.error_summary,
            termination_reason = excluded.termination_reason,
            progress = excluded.progress
    """)
    DBInterface.execute(stmt, (j.id, j.experiment_id, string(j.state), j.started_at, j.finished_at,
                               j.error_summary, j.termination_reason, j.progress))
end

function load_job(db::SQLite.DB, id::AbstractString)::Union{Job, Nothing}
    stmt = SQLite.Stmt(db, "SELECT id, experiment_id, state, started_at, finished_at, error_summary, termination_reason, progress FROM jobs WHERE id = ?")
    cursor = DBInterface.execute(stmt, (String(id),))
    for row in cursor
        st = try
            getfield(Results, Symbol(row.state))
        catch
            Results.JOB_QUEUED
        end
        return Job(row.id, row.experiment_id, st;
                   started_at=ismissing(row.started_at) ? nothing : row.started_at,
                   finished_at=ismissing(row.finished_at) ? nothing : row.finished_at,
                   error_summary=ismissing(row.error_summary) ? nothing : row.error_summary,
                   termination_reason=ismissing(row.termination_reason) ? nothing : row.termination_reason,
                   progress=row.progress)
    end
    return nothing
end

# ----------------- Result CRUD -----------------
function save_result!(db::SQLite.DB, r::Result)
    artifacts_data = [Dict("name" => a.name, "path" => a.path, "artifact_type" => a.artifact_type,
                           "sha256" => a.sha256, "size_bytes" => a.size_bytes) for a in r.artifacts]
    stmt = SQLite.Stmt(db, """
        INSERT INTO results (id, experiment_id, final_energy, gradient_norm, iterations, converged, termination_status, metrics_json, artifacts_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            final_energy = excluded.final_energy,
            gradient_norm = excluded.gradient_norm,
            iterations = excluded.iterations,
            converged = excluded.converged,
            termination_status = excluded.termination_status,
            metrics_json = excluded.metrics_json,
            artifacts_json = excluded.artifacts_json
    """)
    DBInterface.execute(stmt, (r.id, r.experiment_id, r.final_energy, r.gradient_norm, r.iterations,
                               r.converged ? 1 : 0, r.termination_status,
                               JSON3.write(r.metrics), JSON3.write(artifacts_data), r.created_at))
end

function load_result(db::SQLite.DB, experiment_id::AbstractString)::Union{Result, Nothing}
    stmt = SQLite.Stmt(db, "SELECT id, experiment_id, final_energy, gradient_norm, iterations, converged, termination_status, metrics_json, artifacts_json, created_at FROM results WHERE experiment_id = ?")
    cursor = DBInterface.execute(stmt, (String(experiment_id),))
    for row in cursor
        metrics = JSON3.read(row.metrics_json, Dict{String, Any})
        arts_raw = JSON3.read(row.artifacts_json, Vector{Dict{String, Any}})
        artifacts = [Artifact(d["name"], d["path"], d["artifact_type"]; sha256=d["sha256"], size_bytes=d["size_bytes"]) for d in arts_raw]
        return Result(row.id, row.experiment_id;
                      final_energy=row.final_energy,
                      gradient_norm=row.gradient_norm,
                      iterations=row.iterations,
                      converged=row.converged == 1,
                      termination_status=row.termination_status,
                      metrics=metrics,
                      artifacts=artifacts,
                      created_at=row.created_at)
    end
    return nothing
end

end # module Database
