# MolecuLab — Technical Documentation Index
**Document Standard:** docs-architect Specification Version 1.0  
**Project:** MolecuLab — Computational Chemistry Workbench  
**Language:** Julia 1.10+ (Julia 1.13 tested)  
**Repository:** [ZengLLQ/molecul-lab](https://github.com/ZengLLQ/molecul-lab)  

---

## 1. Documentation Overview

Welcome to the MolecuLab technical documentation suite. This repository contains complete architectural manuals, scientific method descriptions, grounded mathematical problem specifications, reproducibility standards, and user guides.

```
docs/
├── README.md                      # This index & navigation map
├── TECHNICAL_MANUAL.md            # Comprehensive architecture & developer manual (docs-architect)
├── MATHEMATICAL_SPECIFICATIONS.md # Grounded mathematical problem specifications (doc2math)
├── ARCHITECTURE.md                # System design, modular monolith layers, and invariants
├── SCIENTIFIC_METHODS.md          # Formulations, energy kernels, gradients, and disclaimers
├── REPRODUCIBILITY.md             # Experiment manifests, provenance standards, and auditing
├── USER_GUIDE.md                  # Desktop application walkthrough and workflows
├── DEPENDENCY_MATRIX.md           # Package dependencies, license matrix, and compatibility
└── IMPLEMENTATION_PLAN.md         # Phased roadmap, milestones (M0-M6), and acceptance criteria
```

---

## 2. Document Catalog

| Document | Primary Audience | Key Topics Covered |
|---|---|---|
| [**TECHNICAL_MANUAL.md**](TECHNICAL_MANUAL.md) | Architects, Developers | Complete system deep dive, component breakdown, design decisions, data flow, concurrency model, and security architecture. |
| [**MATHEMATICAL_SPECIFICATIONS.md**](MATHEMATICAL_SPECIFICATIONS.md) | Theorists, Comp Chemists | Grounded Mathematical Problem Specifications (MPS) for geometry optimization and symplectic MD under the doc2math Zero-Inference Protocol. |
| [**ARCHITECTURE.md**](ARCHITECTURE.md) | Developers, Reviewers | High-level Hexagonal layers, domain invariants, asynchronous worker thread lifecycle, and storage layout. |
| [**SCIENTIFIC_METHODS.md**](SCIENTIFIC_METHODS.md) | Comp Chemists, Analysts | Analytical geometry calculations, Lennard-Jones (12-6) potential, Optim.jl solvers, Velocity-Verlet integrator, and scientific disclaimers. |
| [**REPRODUCIBILITY.md**](REPRODUCIBILITY.md) | QA, Auditing, Researchers | Immutable coordinate snapshots, JSON manifests, runtime hardware/software fingerprinting, and artifact checksums. |
| [**USER_GUIDE.md**](USER_GUIDE.md) | End Users, Evaluators | Getting started, importing `.xyz`/`.sdf`/`.pdb` structures, running geometry optimizations and MD simulations, and exporting data. |
| [**DEPENDENCY_MATRIX.md**](DEPENDENCY_MATRIX.md) | Maintainers, Release Eng | Dependency inventory, licensing compliance, native C/Fortran libraries, and version compatibility. |
| [**IMPLEMENTATION_PLAN.md**](IMPLEMENTATION_PLAN.md) | Project Managers, Devs | Phased development milestones (M0 through M6), technical spikes, risks, and acceptance criteria. |

---

## 3. Reading Paths

### 🔬 For Computational Chemists & Researchers
1. Read [**Scientific Methods**](SCIENTIFIC_METHODS.md) to review the exact physics, analytical gradients, and method limitations.
2. Review [**Mathematical Specifications**](MATHEMATICAL_SPECIFICATIONS.md) for formal optimization and simulation problem definitions.
3. Consult the [**User Guide**](USER_GUIDE.md) for day-to-day workflow instructions.
4. Review [**Reproducibility Standards**](REPRODUCIBILITY.md) for publication-grade data provenance.

### 🏛️ For Software Architects & Core Engineers
1. Study the [**Technical Manual**](TECHNICAL_MANUAL.md) for the end-to-end architectural manual and system boundaries.
2. Review [**Architecture Overview**](ARCHITECTURE.md) for component isolation and dependency rules.
3. Check the [**Dependency Matrix**](DEPENDENCY_MATRIX.md) before introducing or upgrading packages.
4. Inspect [`src/simulation/interface.jl`](../src/simulation/interface.jl) to extend MolecuLab with new computational chemistry adapters.

### 🧪 For QA, Release & DevSecOps Engineers
1. Review the [**Reproducibility & Provenance Standard**](REPRODUCIBILITY.md) to audit manifest schemas and verification tests.
2. Run test suites: `julia --project=. test/runtests.jl`.
3. Execute environment validation: `julia --project=. scripts/validate_environment.jl`.
4. Audit dependency licenses in [**Dependency Matrix**](DEPENDENCY_MATRIX.md).
