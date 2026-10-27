# MolecuLab — Dependency & Compatibility Matrix
**Specification Version:** 1.0  
**Host Platform:** Windows 11 (x86_64-w64-mingw32) | CPU: AMD Ryzen 5 5600 6C/12T | GPU: NVIDIA GeForce RTX 3050 8GB  
**Julia Runtime:** 1.13.3 (Verified)

---

## 1. Package Status & Validation Matrix

| Package | Resolved Version | License | Primary Purpose | Native Dependencies / JLL | Feasibility Spike Status | Notes / Alternatives |
|---|---|---|---|---|---|---|
| **SQLite.jl** | v1.9.0 | MIT | Local relational metadata & project index store | `SQLite_jll` (v3.54.0), `dlfcn_win32_jll` | **Verified & Precompiled** | Rock-solid embedded database. WAL mode, thread-safe access. |
| **JSON3.jl** | v1.14.3 | MIT | Fast JSON serialization for configs & manifests | Pure Julia | **Verified & Precompiled** | Standard for configs; alternative is `JSON.jl` or `TOML`. |
| **Unitful.jl** | v1.29.0 | MIT | Physical unit typing and conversion (Å, nm, kJ/mol, K, ps) | Pure Julia | **Verified & Precompiled** | Guarantees dimensional consistency across coordinates, forces, and energies. |
| **Optim.jl** | v2.3.2 | MIT | Multi-variable optimization (BFGS, L-BFGS, CG, GradientDescent) | `OpenBLAS_jll` | **Verified & Precompiled** | Used for molecular geometry minimization $R^* = \arg\min_R E(R)$. |
| **Aqua.jl** | v0.8.18 | MIT | Automated package quality and hygiene assurance | Pure Julia | **Verified & Precompiled** | Used in CI/test suite for piracy, unbound type params, stale deps. |
| **Gtk4.jl** | v0.7.14 | MIT | Native Desktop GUI window, panels, and forms | `GTK4_jll` (v4.18.6), `Glib_jll` (v2.90.1), `Cairo_jll`, `Pango_jll` | **Verified & Precompiled** | Native desktop shell. Verified on Windows with GtkCanvas and Cairo rendering. |
| **Cairo.jl** | v1.1.1 | MIT | 2D vector graphics and 3D projection rendering | `Cairo_jll` (v1.18.8) | **Verified & Precompiled** | Fast, high-fidelity rendering of molecular structures, bonds, and convergence plots. |
| **AtomsBase.jl** | v0.5.3 | MIT | Standard atomistic structure interface | Pure Julia | **Verified & Precompiled** | Standard Julia atomistic interface for system representations. |
| **MolecularGraph.jl** | v1.1.0 | MIT | Graph representation, topological descriptors | `libinchi_jll`, `coordgenlibs_jll` | **Verified & Precompiled** | Graph topology, molecular formula, standard cheminformatics properties. |
| **Molly.jl** | Candidate (v0.22+) | MIT | Classical molecular dynamics | Pure Julia / GPU optional | *Pending Spike* | Classical MD engine. Internal reference Velocity-Verlet engine serves as educational baseline. |
| **DFTK.jl** | Candidate | MIT | Plane-wave DFT for periodic systems | BLAS/LAPACK, FFTW | *Pending Spike* | Quantum chemistry extension. Strict periodic boundaries; documented scope limitations. |
| **CUDA.jl** | Optional | MIT | NVIDIA GPU acceleration | CUDA driver runtime | *Hardware Detected (RTX 3050)* | Optional compute accelerator. Validated via runtime `functional()` checks. |

---

## 2. Standard Library Usage (Zero Overhead, 100% Locked)

| Stdlib | Purpose |
|---|---|
| `LinearAlgebra` | Matrix operations, Euclidean distances, dot/cross products, eigenvalues |
| `Dates` | ISO 8601 timestamps for experiment provenance and run tracking |
| `UUIDs` | Cryptographically unique identifiers (UUIDv4) for projects, molecules, jobs |
| `Logging` | Bounded memory logging and structured file audit trails |
| `TOML` | Project metadata (`project.toml`) serialization and parsing |
| `SHA` | Cryptographic SHA-256 content hashes for input structures and configs |
| `Test` | Standard testing framework for unit, integration, and scientific regression |
| `Base.Threads` | Multi-threaded asynchronous job execution |

---

## 3. Package Policy & Rules

1. Every dependency must be recorded with its exact resolved version in `Manifest.toml`.
2. Do not introduce speculative dependencies without a verified feasibility spike.
3. If an external package fails to build or has incompatible binary requirements on Windows, fallback to a robust internal implementation with identical scientific contracts and clear user documentation.
