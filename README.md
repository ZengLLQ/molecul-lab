# MolecuLab — Computational Chemistry Workbench
### Modern | Julia-first | Local-first | GPU-optional | Scientifically Honest

MolecuLab is a desktop computational chemistry workbench engineered for researchers, molecular modelers, and students. It integrates molecular data management, 3D interactive geometry inspection, topological and quantum descriptors, reference potential calculations, geometry optimizations, and reproducible experiment tracking into a single cohesive, high-performance application.

---

## 1. Non-Negotiable Engineering Principles

1. **Julia-First**: All UI logic, domain models, application workflows, geometry engines, numerical kernels, and testing are implemented in pure Julia.
2. **Local-First & Offline**: Project files, SQLite databases, simulation logs, and trajectory artifacts are stored entirely on your local machine. No cloud accounts, external APIs, or telemetry.
3. **Scientific Honesty**: Never claim drug discovery bioactivity, clinical safety, or binding affinity from simple descriptors. If a calculation fails or hits an iteration limit, the system reports `stopped_max_iterations` or `failed`—never a fabricated "converged" status.
4. **Reproducibility**: Every computational experiment records an immutable snapshot of initial coordinates, exact numerical parameters, software environment versions, random seeds, and hardware metadata.
5. **Responsive UI**: Simulations and numerical minimizations run strictly in background tasks, keeping the UI responsive at all times.
6. **Package-First & Zero Inventions**: Built on mature Julia packages (`Optim.jl`, `SQLite.jl`, `Unitful.jl`, `Gtk4.jl`, `Cairo.jl`, `MolecularGraph.jl`, `AtomsBase.jl`) using real, verified APIs.

---

## 2. System Architecture

MolecuLab is organized as a clean modular monolith:

```
src/
├── MolecuLab.jl              # Main package module entry point
├── app/                      # Application lifecycle, desktop window, navigation
├── ui/                       # Theme tokens, UI components, workspace views
├── application/              # Services: Project, Structure, Experiment, Result, JobScheduler
├── domain/                   # Pure entities: Project, Molecule, Structure, Experiment, Job, Result
├── chemistry/                # Geometry math, Lennard-Jones kernel, topological descriptors
├── simulation/               # Computational interfaces, Optim.jl optimization engine, integrators
├── io/                       # Parsers for XYZ, MOL/SDF, and PDB files with validation
├── storage/                  # SQLite schema migrations, persistence, and file artifact manager
└── diagnostics/              # CPU thread count, memory, and NVIDIA GPU / CUDA probes
```

---

## 3. Quickstart & Installation

### Requirements
- Julia 1.10+ (Tested on Julia 1.13.3, Windows 11 64-bit).
- Git.

### 1. Instantiate Dependencies
```bash
git clone https://github.com/moleculab/MolecuLab.jl.git
cd MolecuLab
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### 2. Run the Test Suite
```bash
julia --project=. test/runtests.jl
```

### 3. Launch the Workbench
```bash
julia --project=. scripts/dev.jl
```

---

## 4. Documentation Index

- [Implementation Plan & Roadmap](docs/IMPLEMENTATION_PLAN.md): Detailed milestones (M0 through M5) and acceptance criteria.
- [System Architecture](docs/ARCHITECTURE.md): Layered architecture, domain invariants, threading model, and storage layout.
- [Dependency & Compatibility Matrix](docs/DEPENDENCY_MATRIX.md): Exact verified versions, licenses, and JLL status.
- [Scientific Methods & Validation](docs/SCIENTIFIC_METHODS.md): Mathematical formulations for geometry, LJ potential, gradients, and optimization.
- [Experiment Reproducibility Standard](docs/REPRODUCIBILITY.md): Schema for immutable snapshots, parameter tracking, and execution manifests.
- [User Guide](docs/USER_GUIDE.md): End-user instructions for managing projects, importing structures, measuring geometries, and running optimizations.

---

## 5. Scientific Limitations & Disclaimers

- The **Lennard-Jones potential** is an educational reference kernel. It models non-bonded van der Waals interactions between neutral particles and does not represent covalent chemical bond breaking, partial charges, or electronic polarization.
- Molecular descriptors (molecular weight, formula, heavy atom count) are topological descriptors and must **never** be interpreted as clinical predictions of toxicity, potency, or bioavailability.
- Hardware acceleration (GPU) is activated only when CUDA devices and compatible kernels are explicitly detected and validated. CPU execution is always the primary, reliable baseline.
