# MolecuLab — System Architecture Document
**Specification Version:** 1.0  
**Pattern:** Clean Modular Monolith | Layered Hexagonal / Ports & Adapters  
**Implementation Language:** Julia 1.10+ (Julia 1.13 tested)

---

## 1. Architectural Philosophy

MolecuLab is built as a single, highly cohesive, modular Julia application following strict dependency boundaries:
- **Zero microservices**: All services communicate via in-memory dispatch and Julia type methods.
- **Separation of Concerns**: The computational engine and domain models have zero coupling to GUI libraries, window handles, or widget states.
- **Truthful States**: Solvers, jobs, and workers communicate state via structured event messages. UI states never invent percentages, convergence flags, or GPU presence without physical verification.

```
       +-----------------------------------------------------------+
       |                  Presentation Layer                       |
       |  (Gtk4 UI / Native Viewport / Plotting / Component Trees) |
       +-----------------------------------------------------------+
                                   |
                                   v  (commands / queries)
       +-----------------------------------------------------------+
       |                  Application Services                     |
       |  - ProjectService         - StructureService              |
       |  - ExperimentService      - JobScheduler                  |
       |  - ResultService          - DiagnosticsService            |
       +-----------------------------------------------------------+
                  |                                    |
                  v                                    v
       +--------------------+               +--------------------+
       |    Domain Model    |               | Computational Core |
       |  - Project         |               |  - Geometry Math   |
       |  - Molecule        |               |  - LJ Potential    |
       |  - Structure       |               |  - Optim Engine    |
       |  - Experiment      |               |  - Integrators     |
       |  - Job & Result    |               |  - Descriptors     |
       +--------------------+               +--------------------+
                  |                                    |
                  +-----------------+------------------+
                                    |
                                    v  (implements interfaces)
       +-----------------------------------------------------------+
       |                  Infrastructure & Adapters                |
       |  - SQLite.jl Metadata Store                               |
       |  - FileSystem Artifact Engine (JSON3, Atomic IO)          |
       |  - Chemical File Parsers (XYZ, MOL/SDF, PDB)              |
       |  - Molecular Mechanics & Dynamics Adapters                |
       |  - Hardware / CUDA Diagnostics Provider                   |
       +-----------------------------------------------------------+
```

---

## 2. Domain Models & Invariants

### 2.1 Project
- **Id**: UUIDv4 string.
- **Name**: Non-empty user identifier.
- **Root**: Absolute path on local filesystem.
- **SchemaVersion**: Version integer for migration control (Current: `1`).
- **Timestamps**: ISO 8601 UTC strings (`created_at`, `updated_at`).

### 2.2 Molecule & Structure
- **Molecule**: High-level chemical entity identifier, associated with one or more conformers/structures.
- **Structure**:
  - `id`: UUID string.
  - `molecule_id`: UUID reference.
  - `atoms`: Vector of `Atom` (element symbol, atomic number, 3D coordinate in Angstroms, mass, formal charge).
  - `bonds`: Vector of `Bond` (atom indices $i, j$, bond order 1/2/3/aromatic).
  - `unit`: Fixed standard unit (`Angstrom` for distances, `amu` for masses).
  - `warnings`: Vector of validation strings (e.g., overlapping coordinates, missing hydrogens).

### 2.3 Experiment & Config
- **Id**: e.g., `EXP-XXXX`.
- **StructureId**: Reference to immutable snapshot of initial coordinates.
- **Method**: Type-safe subtype of `AbstractChemistryMethod`.
- **Config**: JSON/TOML-serializable struct specifying tolerance, max iterations, step sizes, and algorithm.
- **Environment**: Software versions (Julia, MolecuLab, active packages) and hardware info at dispatch time.

### 2.4 Job & Lifecycle
A finite state machine enforcing valid transitions:
```
[queued] -> [validating] -> [running] -> [completed]
                               |      -> [failed]
                               v
                         [cancelling] -> [cancelled]
```

---

## 3. Asynchronous Job & Worker Subsystem

Heavy computations run strictly off the UI thread:
1. When the user requests an experiment run, `ExperimentService` validates the configuration.
2. If validation succeeds, a `Job` record is persisted in SQLite with state `queued`.
3. The job is scheduled on a worker task via `Base.Threads.@spawn`.
4. The worker receives an input snapshot and a `Channel{JobEvent}`.
5. The worker periodically checks for cancellation requests via an `Atomic{Bool}` token.
6. The UI subscribes to the channel or periodically polls the atomic state buffer without blocking event processing.
7. Upon termination, final metrics and artifacts are written atomically to disk, and the job status transitions to `completed`, `failed`, or `cancelled`.

---

## 4. Storage Architecture

Project data is segregated by durability and size:

```
<project_root>/
├── project.toml               # Human-readable project manifest
├── database/
│   └── project.sqlite         # Relational metadata: projects, structures, experiments, jobs
├── structures/
│   ├── molecules/             # Canonical molecule descriptions
│   └── snapshots/             # Immutable coordinate snapshots referenced by experiments
├── experiments/
│   └── EXP-0001/
│       ├── config.json        # Effective execution configuration
│       ├── environment.json   # Exact runtime versions and hardware specs
│       ├── run.log            # Bounded append-only log file
│       ├── checkpoints/       # Intermediate optimization or simulation geometries
│       └── results.json       # Final energies, gradient norms, convergence metrics
└── exports/                   # User-directed exports (XYZ, CSV, Reports)
```

---

## 5. Security & Boundary Rules

1. **No External Network Calls**: MolecuLab operates strictly offline. No telemetry, update pings, or cloud API calls are executed.
2. **Path Traversal Protection**: All file imports, exports, and artifact paths are sanitized to ensure they remain within authorized filesystem boundaries.
3. **No Dynamic Code Evaluation**: Never `eval()` code from chemical files or user configurations. Parsers are deterministic and strictly typed.
