# MolecuLab — Implementation Plan & Milestone Roadmap
**Specification Version:** 1.0  
**Status:** In Progress (Active Implementation)  
**Primary Language:** Julia (1.10+)  
**Runtime Environment:** Local Desktop (Windows Primary, Linux/macOS portable design)

---

## 1. Executive Summary & Goals

MolecuLab is an integrated, local-first, Julia-first computational chemistry workbench designed to combine:
1. **Project & Molecular Data Management**: Atomic coordinates, topological bonding, molecular graph properties, conformers, and SQLite metadata tracking.
2. **Interactive Scientific Visualization**: Real-time inspection of 3D molecular coordinates, atom properties, distances, angles, dihedrals, and convergence metrics.
3. **Computational Workflows**:
   - Reference educational energy kernels (Lennard-Jones pairwise potentials with analytic gradients).
   - Local geometry optimization with numerical convergence guarantees (via `Optim.jl`).
   - Classical molecular dynamics with trajectory tracking, thermostatting, and ensemble metrics (adapter architecture for `Molly.jl`).
   - Extensible quantum chemistry interfaces (for periodic plane-wave DFT via `DFTK.jl` where physically valid).
4. **Scientific Honesty & Provenance**: Immutable input snapshots, exact parameter logging, random seeds, hardware diagnostics, and zero false-positive states ("converged" only when gradient/energy criteria are satisfied; zero fabricated progress percentages).

---

## 2. System Architecture & Boundaries

```
+---------------------------------------------------------------------------------+
|                               Presentation Layer                                |
|  - Desktop Shell (Gtk4.jl / Native Windowing)                                   |
|  - Viewport & Plotting (Makie.jl / WGLMakie/CairoMakie / Molecular Visualizer)  |
|  - Panels: Projects, Molecular Workspace, Experiment Designer, Run Monitor,     |
|            Results Explorer, System Diagnostics                                 |
+---------------------------------------------------------------------------------+
                                      | calls
                                      v
+---------------------------------------------------------------------------------+
|                            Application Services Layer                           |
|  - ProjectService: project lifecycle, import/export, directory layout           |
|  - StructureService: atomistic parsing, validation, descriptors, measurements   |
|  - ExperimentService: config verification, job preparation, reproducibility log |
|  - ResultService: artifact indexing, metrics extraction, dataset comparisons    |
|  - JobScheduler: async worker dispatch, cooperative cancel, progress channel    |
+---------------------------------------------------------------------------------+
                     |                                       |
                     v                                       v
+------------------------------------+   +----------------------------------------+
|            Domain Model            |   |           Computational Core           |
|  - Project, Molecule, Structure    |   |  - Geometry & Vector Math              |
|  - Experiment, Job, Result         |   |  - LJ Reference Kernel & Forces        |
|  - Artifact Manifest               |   |  - Optimization Engine (Optim.jl)      |
|  - Provenance Snapshot             |   |  - Molecular Dynamics Interface        |
+------------------------------------+   +----------------------------------------+
                     |                                       |
                     +-------------------+-------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                       Infrastructure & Adapter Layer                            |
|  - Storage: SQLite.jl (Metadata DB) + FileSystem (Traversable Artifacts, JSON)  |
|  - IO: XYZ, SDF/MOL, PDB parsers with validation and unit standardization       |
|  - Simulation Adapters: MolecularMechanicsAdapter, MollyAdapter, DFTKAdapter    |
|  - Hardware Diagnostics: CPU threads, memory detection, NVIDIA GPU / CUDA query |
+---------------------------------------------------------------------------------+
```

### Architectural Principles:
1. **Thread Separation**: Long-running simulations execute in background `Base.Threads.@spawn` or isolated worker tasks. The UI event loop communicates via thread-safe `Channel` or lock-free state queues.
2. **Zero Inventions**: All package APIs are verified against actual imported types. If an external package lacks an API, a transparent internal domain type or adapter is used.
3. **Data Integrity**: Database stores metadata and index records. Large arrays (trajectories, gradients, wavefunctions) are stored as atomic file artifacts in the project directory.

---

## 3. Milestones & Acceptance Criteria

### Milestone M0: Technical Feasibility & Spikes
- **Goal**: Validate Julia runtime, core packages, graphics/UI capabilities on Windows, SQLite persistence, and basic numerical kernel.
- **Deliverables**:
  - `docs/DEPENDENCY_MATRIX.md` recording actual versions, native binaries, and licenses.
  - Feasibility spikes:
    1. Storage: SQLite database initialization and schema setup.
    2. IO & Geometry: Parsing XYZ/MOL format into atomistic types, computing pairwise distances.
    3. Numerical kernel: 12-6 Lennard-Jones potential and force verification.
    4. Desktop UI: Windowing and rendering validation.
- **Acceptance Criteria**:
  - All spikes run and pass on Windows.
  - No speculative or unverified dependencies remain.

### Milestone M1: Desktop Shell & Project Management
- **Goal**: Deliver a stable project foundation with SQLite persistence, file storage hierarchy, and responsive navigation.
- **Deliverables**:
  - Project directory structure (`project.toml`, `database/project.sqlite`, `structures/`, `experiments/`).
  - `ProjectService` with create, open, list, save, and validate operations.
  - Structured logging into bounded memory ring-buffers and on-disk files.
  - UI Navigation Shell with empty, loading, error, and recovery states.
- **Acceptance Criteria**:
  - Projects survive application restart with complete structural integrity.
  - Corrupt database or missing folder produces explicit actionable user feedback.

### Milestone M2: Molecular Workspace & Geometry
- **Goal**: Full molecular structure inspection, 3D coordinate viewing, bonding representation, distance/angle/dihedral measurements, and validation warnings.
- **Deliverables**:
  - Importers for XYZ, SDF/MOL, and basic PDB formats.
  - Atomistic domain models (`Atom`, `Bond`, `Structure`, `Molecule`).
  - Geometry analytics: bond length (`norm(r_i - r_j)`), bond angle (`acos(clamp(...))`), dihedral angle, center of mass, bounding radius.
  - Topological descriptors: molecular formula, heavy atom count, formal charge, molecular weight.
  - Molecular viewport / visualizer component.
- **Acceptance Criteria**:
  - Geometry calculations match analytical values to $10^{-10}$ precision.
  - Degenerate geometries (coincident atoms, collinear points) return clear validation errors without NaN or program crashes.

### Milestone M3: Computational Core & Geometry Optimization
- **Goal**: Execute real geometry optimizations using Lennard-Jones and empirical potentials, driven by the asynchronous job manager.
- **Deliverables**:
  - LJ potential with analytical gradient and finite-difference validation tests.
  - Geometry optimization service wrapping `Optim.jl` (BFGS / Conjugate Gradient / L-BFGS).
  - Asynchronous Job System: states (`queued`, `validating`, `running`, `cancelling`, `cancelled`, `completed`, `failed`).
  - Cooperative cancellation tokens.
  - Experiment Designer UI and Run Monitor with live iteration metrics.
- **Acceptance Criteria**:
  - Optimization converges to true analytical minima (e.g., LJ dimer equilibrium $r_e = 2^{1/6}\sigma$).
  - UI remains responsive (60 FPS / non-blocking) during optimization.
  - Cancellation requests halt the worker safely and log partial artifacts.

### Milestone M4: Molecular Dynamics Adapter
- **Goal**: Classical molecular dynamics simulation with trajectory logging and thermodynamic validation.
- **Deliverables**:
  - Adapter interface for `Molly.jl` or internal velocity-Verlet reference integrator.
  - Temperature, kinetic energy, potential energy, and total energy calculations.
  - Trajectory writer (atomic XYZ/CSV format) with configurable logging intervals.
  - Results Explorer showing metric timeseries and trajectory replay controls.
- **Acceptance Criteria**:
  - NVE microcanonical ensemble conserves total energy within standard symplectic drift limits.
  - Trajectories can be reloaded and inspected across sessions.

### Milestone M5: Scientific Validation, Advanced Methods, & Release Prep
- **Goal**: Hardware diagnostics, GPU optionality checks, comprehensive scientific regression suite, and packaging documentation.
- **Deliverables**:
  - Hardware & GPU probe (detecting CUDA availability and reporting truth without fake claims).
  - Quantum chemistry boundary adapter (`DFTK.jl` interface specification and periodic constraint declarations).
  - Scientific validation report comparing computed benchmarks against literature values.
  - `PackageCompiler.jl` build script and verification on Windows.
- **Acceptance Criteria**:
  - Zero false claims about GPU or quantum methods.
  - 100% test pass rate across unit, integration, and scientific suites.

---

## 4. Key Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation Strategy |
|---|---|---|---|
| **GTK4 / JLL binaries on Windows** | High | Medium | Run dedicated spike immediately. If GTK4 binary has system conflicts, provide a robust decoupled desktop UI engine (e.g. native Blink/Webview or clean GLFW/Makie interactive desktop) while keeping 100% Julia domain logic. |
| **UI Blocking during computation** | Critical | Low | Use strict message-passing via `Channel{JobEvent}`. The UI thread only reads queued events and never invokes mathematical solvers directly. |
| **Molly.jl API compatibility** | Medium | Medium | Wrap MD behind `AbstractChemistryMethod` adapter. Implement an internal self-contained Velocity-Verlet symplectic integrator for baseline NVE/NVT dynamics to guarantee zero dependency breakage. |
| **Numerical singularities ($r \to 0$)** | High | Low | Enforce strict cutoff distance $r_{\min} > 0.01$ Å and clamp potential energies to avoid floating-point overflow. |
| **GPU availability mismatch** | Medium | High | Always query driver and device runtime explicitly via `CUDA.functional()`. Fall back to CPU gracefully with transparent user notification. |
