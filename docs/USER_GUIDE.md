# MolecuLab — User Guide & Operations Manual
**Workbench Version:** 1.0  
**Target Audience:** Computational Chemists, Molecular Modelers, Materials Researchers, Students

---

## 1. Introduction

MolecuLab is a local-first, Julia-powered computational chemistry workbench. It provides a cohesive desktop environment for molecular structure inspection, geometry measurements, reference potential calculations, geometry optimizations, and reproducible experiment tracking.

### Core Philosophy
- **Everything Local:** Your molecular geometries, experiments, and trajectories reside entirely on your local machine.
- **Scientific Transparency:** You will never see artificial "100% complete" progress bars or simulated convergence. All numbers reflect actual mathematical states reported by the underlying Julia solvers.

---

## 2. Quickstart & Launching

### Prerequisites
- Julia 1.10+ installed and on system `PATH`.
- Windows 10/11, Linux, or macOS.

### Launching the Workbench
From the `MolecuLab` root directory:
```powershell
julia --project=. scripts/dev.jl
```
Or for headless test execution:
```powershell
julia --project=. test/runtests.jl
```

---

## 3. Project Management

MolecuLab organizes your research into self-contained project directories:
1. **Create New Project**:
   - Provide a project name and destination directory.
   - MolecuLab initializes `project.toml`, the SQLite metadata database (`database/project.sqlite`), and directory structures for molecules, snapshots, experiments, and exports.
2. **Open Existing Project**:
   - Select any directory containing a valid `project.toml` file.
   - MolecuLab validates database schema integrity and loads recent molecules and experiments.
3. **Immutability of Historical Data**:
   - When an experiment is launched, a frozen snapshot of the molecule's geometry is archived.
   - Modifying a molecule in the workspace will never alter past experiment configurations or results.

---

## 4. Molecular Workspace & Geometry Analysis

### Supported Formats
- **XYZ (`.xyz`)**: Standard Cartesian coordinate format with element symbols.
- **MDL Molfile / SDF (`.mol`, `.sdf`)**: V2000 format with explicit connection tables and bond orders.
- **PDB (`.pdb`)**: Protein Data Bank format (ATOM/HETATM coordinate records).

### Interactive Measurements
- **Bond Distance**: Select any two atoms to calculate the Euclidean distance in Angstroms:
  $$d_{ij} = \|\mathbf{r}_i - \mathbf{r}_j\|$$
- **Bond Angle**: Select three atoms ($i - j - k$) to calculate the angle centered at atom $j$:
  $$\theta = \arccos\left(\text{clamp}\left(\frac{\mathbf{r}_{ij} \cdot \mathbf{r}_{kj}}{\|\mathbf{r}_{ij}\| \|\mathbf{r}_{kj}\|}, -1, 1\right)\right)$$
- **Dihedral Angle**: Select four consecutively bonded atoms ($i - j - k - l$) to compute the signed torsion angle ($-\pi$ to $+\pi$).

### Descriptors
- **Elemental Composition & Molecular Formula**: Standard Hill notation (e.g., $\text{C}_6\text{H}_{12}\text{O}_6$).
- **Molecular Weight**: Sum of standard atomic weights based on IUPAC standard isotopic abundances.
- **Heavy Atom Count**: Total non-hydrogen atoms.

---

## 5. Experiment Designer & Optimization

### Configuring a Geometry Optimization
1. Navigate to **Experiments > New Experiment**.
2. Select an input molecule/structure from the current project.
3. Choose the computational method:
   - **Lennard-Jones Pair Potential (Reference)**: Educational dispersion-repulsion model.
4. Configure parameters:
   - $\varepsilon$ (well depth in kJ/mol).
   - $\sigma$ (collision diameter in Å).
   - Optimization algorithm: `BFGS`, `L-BFGS`, `ConjugateGradient`, or `GradientDescent`.
   - Gradient tolerance $g_{\text{tol}}$ (default: $10^{-4}$).
   - Energy tolerance $f_{\text{tol}}$ (default: $10^{-6}$).
   - Maximum iterations.
5. Click **Validate Configuration**: The system checks for coordinate singularities or unphysical parameters.
6. Click **Run Experiment**: The job is dispatched to a background worker thread.

---

## 6. Run Monitor & Results Explorer

### Monitoring Live Calculations
- The UI remains completely responsive during computation.
- View real-time elapsed time, completed iterations, current potential energy, and gradient norms.
- **Cooperative Cancellation**: Click **Request Cancellation** to halt the solver cleanly. The worker stops at the next iteration boundary and saves partial checkpoints.

### Inspecting Results
- **Final Metrics**: Minimum potential energy $E^*$, final gradient norm, iterations executed, and termination reason (`converged`, `stopped_max_iterations`, `cancelled`).
- **Artifacts**: Download or export the optimized structure (`final_structure.xyz`) or full convergence logs (`convergence_history.json`).
- **Reproducibility Manifest**: Inspect the exact runtime environment (Julia version, CPU/GPU, package manifest hash, random seed).

---

## 7. Troubleshooting & Diagnostics

- Navigate to **Diagnostics** to inspect:
  - System CPU thread count and available memory.
  - Active GPU device name and CUDA functionality status.
  - SQLite database connection health and disk space.
