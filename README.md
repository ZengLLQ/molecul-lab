# MolecuLab — Computational Chemistry Workbench
### Modern | Julia-first | Local-first | GPU-optional | Scientifically Honest

[![CI](https://github.com/ZengLLQ/molecul-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/ZengLLQ/molecul-lab/actions/workflows/ci.yml)
[![Julia Version](https://img.shields.io/badge/julia-1.10%20%7C%201.11%20%7C%201.13-9558B2?logo=julia)](https://julialang.org)
[![Tests](https://img.shields.io/badge/tests-76%20%2F%2076%20passing-brightgreen)](test/runtests.jl)
[![doc2math](https://img.shields.io/badge/doc2math-MPS%201.0%20Verified-blue)](docs/MATHEMATICAL_SPECIFICATIONS.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**MolecuLab** is a desktop computational chemistry workbench engineered for researchers, molecular modelers, and students. It integrates molecular data management, 3D interactive geometry inspection, topological and physical descriptors, reference potential calculations, geometry optimizations, symplectic molecular dynamics, and reproducible experiment tracking into a single cohesive, high-performance application.

---

## 1. Non-Negotiable Engineering Principles

1. **Julia-First**: All UI logic, domain models, application workflows, geometry engines, numerical kernels, and testing are implemented in pure Julia.
2. **Local-First & Offline**: Project files, SQLite databases, simulation logs, and trajectory artifacts are stored entirely on your local machine. No cloud accounts, external APIs, or telemetry.
3. **Scientific Honesty**: Never claim drug discovery bioactivity, clinical safety, or binding affinity from simple descriptors. If a calculation fails or hits an iteration limit, the system reports `stopped_max_iterations` or `failed`—never a fabricated "converged" status.
4. **Reproducibility**: Every computational experiment records an immutable snapshot of initial coordinates, exact numerical parameters, software environment versions, random seeds, and hardware metadata.
5. **Responsive UI**: Simulations and numerical minimizations run strictly in background tasks via `Base.Threads.@spawn`, keeping the Gtk4 UI event loop responsive at all times.
6. **Package-First & Zero Inventions**: Built on mature Julia packages (`Optim.jl`, `SQLite.jl`, `Unitful.jl`, `Gtk4.jl`, `Cairo.jl`, `MolecularGraph.jl`, `AtomsBase.jl`) using real, verified APIs.

---

## 2. Key Capabilities

- **Interactive 3D Molecular Viewport:** High-performance software-rasterized vector rendering via Gtk4 and Cairo with trackball rotation, zoom, pan, depth-sorting, and atom picking.
- **Chemoinformatic Parsers & Validators:** Native ingestion of `.xyz`, `.mol`/`.sdf`, and `.pdb` formats with automated valence, distance, and singularity checks.
- **Geometry Optimization (MPS-1):** 12-6 Lennard-Jones reference potential with analytical gradients and singularity-repulsion damping, solved via `Optim.jl` (BFGS, L-BFGS, CG, Gradient Descent).
- **Symplectic Molecular Dynamics (MPS-2):** Microcanonical $NVE$ Velocity-Verlet integrator with Maxwell-Boltzmann thermal velocity initialization, center-of-mass momentum drift removal, and $\mathcal{O}(\Delta t^2)$ energy conservation.
- **Auditable Provenance Engine:** Full JSON manifests recording hardware state (CPU threads, RAM, detected GPU), Julia environment fingerprints, and SHA-256 artifact checksums.

---

## 3. Mathematical Problem Specifications (doc2math)

The computational core is formalized into grounded Mathematical Problem Specifications (MPS) under the **doc2math Zero-Inference Protocol**:

- [**MPS-1: Lennard-Jones Geometry Optimization**](docs/MATHEMATICAL_SPECIFICATIONS.md#2-mps-1-molecular-geometry-optimization-12-6-lennard-jones-minimization):
  $$\mathbf{R}^* = \arg\min_{\mathbf{R} \in \mathbb{R}^{3N}} \sum_{i<j} 4\varepsilon \left[ \left(\frac{\sigma}{r_{ij}}\right)^{12} - \left(\frac{\sigma}{r_{ij}}\right)^6 \right]$$
  Subject to core singularity bounds $r_{ij} \ge 0.05\text{ Å}$ and convergence tolerances $\|\nabla E\|_\infty < g_{\text{tol}}$, $|E_{k+1} - E_k| < f_{\text{tol}}$.
- [**MPS-2: Symplectic Velocity-Verlet Molecular Dynamics**](docs/MATHEMATICAL_SPECIFICATIONS.md#3-mps-2-symplectic-microcanonical-nve-molecular-dynamics):
  $$\mathbf{r}_i(t + \Delta t) = \mathbf{r}_i(t) + \mathbf{v}_i(t)\Delta t + \frac{1}{2m_i}\mathbf{F}_i(t)\Delta t^2$$
  $$\mathbf{v}_i(t + \Delta t) = \mathbf{v}_i\left(t + \frac{1}{2}\Delta t\right) + \frac{1}{2m_i}\mathbf{F}_i(t + \Delta t)\Delta t$$
  Subject to exact momentum conservation $\sum m_i \mathbf{v}_i = \mathbf{0}$ and bounded energy drift $\Delta E \in \mathcal{O}(\Delta t^2)$.

Full formal JSON specifications, variable domains, operator arities, and uncertainty characterizations are documented in [`docs/MATHEMATICAL_SPECIFICATIONS.md`](docs/MATHEMATICAL_SPECIFICATIONS.md).

---

## 4. System Architecture

MolecuLab is organized as a clean modular monolith:

```
src/
├── MolecuLab.jl              # Main package module entry point
├── app/                      # Application lifecycle, desktop window, navigation
├── ui/                       # Theme tokens, Cairo 3D canvas, workspace views
├── application/              # Services: Project, Structure, Experiment, Result, JobScheduler
├── domain/                   # Pure entities: Project, Molecule, Structure, Experiment, Job, Result
├── chemistry/                # Geometry math, Lennard-Jones kernel, topological descriptors
├── simulation/               # Computational interfaces, Optim.jl optimization engine, integrators
├── io/                       # Parsers for XYZ, MOL/SDF, and PDB files with validation
├── storage/                  # SQLite schema migrations, persistence, and file artifact manager
└── diagnostics/              # CPU thread count, memory, and NVIDIA GPU / CUDA probes
```

Detailed architectural deep dives, sequence diagrams, and concurrency models are provided in the [**Complete Technical Manual**](docs/TECHNICAL_MANUAL.md).

---

## 5. Quickstart & Installation

### Requirements
- Julia 1.10+ (Tested on Julia 1.10, 1.11, and 1.13.3; Windows, Linux, macOS).
- Git.

### 1. Clone & Instantiate Dependencies
```bash
git clone https://github.com/ZengLLQ/molecul-lab.git
cd molecul-lab
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### 2. Run the Test Suite
```bash
julia --project=. test/runtests.jl
```
*Expected output: `Test Summary: MolecuLab Comprehensive Test Suite | 76 passed, 0 failed, 0 errored`.*

### 3. Validate Hardware & Environment
```bash
julia --project=. scripts/validate_environment.jl
```

### 4. Launch the Workbench
```bash
julia --project=. scripts/dev.jl
```

---

## 6. Complete Documentation Index

| Guide | Description |
|---|---|
| [**Technical Manual**](docs/TECHNICAL_MANUAL.md) | Comprehensive system architecture, component breakdown, design decisions, and operational guide (`docs-architect`). |
| [**Mathematical Specifications**](docs/MATHEMATICAL_SPECIFICATIONS.md) | Formal mathematical problem specifications, variable domains, operators, and constraints (`doc2math`). |
| [**Documentation Index**](docs/README.md) | Central documentation directory and reading paths for researchers, architects, and QA engineers. |
| [**Scientific Methods & Validation**](docs/SCIENTIFIC_METHODS.md) | Physics formulations for geometry, LJ potential, analytical gradients, and integrators. |
| [**System Architecture**](docs/ARCHITECTURE.md) | Modular monolith architecture, hexagonal layers, domain models, and concurrency. |
| [**Experiment Reproducibility Standard**](docs/REPRODUCIBILITY.md) | Immutable coordinate snapshots, parameter manifests, and hardware fingerprinting. |
| [**User Guide**](docs/USER_GUIDE.md) | Step-by-step walkthrough for creating projects, importing files, and running experiments. |
| [**Dependency Matrix**](docs/DEPENDENCY_MATRIX.md) | Verified package versions, licenses, and compatibility notes. |
| [**Implementation Roadmap**](docs/IMPLEMENTATION_PLAN.md) | Milestone tracking (M0–M6), risk mitigations, and acceptance criteria. |

---

## 7. Scientific Limitations & Disclaimers

- The **Lennard-Jones potential** is an educational reference kernel. It models non-bonded van der Waals interactions between neutral particles and does not represent covalent chemical bond breaking, partial charges, or electronic polarization.
- Molecular descriptors (molecular weight, formula, heavy atom count) are topological descriptors and must **never** be interpreted as clinical predictions of toxicity, potency, or bioavailability.
- Hardware acceleration (GPU) is activated only when CUDA devices and compatible kernels are explicitly detected and validated. CPU execution is always the primary, reliable baseline.
