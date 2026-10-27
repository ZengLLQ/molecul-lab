# MolecuLab — Experiment Reproducibility & Provenance Standard
**Specification Version:** 1.0  
**Compliance Level:** Strict Local Auditing

---

## 1. Principles of Scientific Reproducibility

In computational chemistry, an experiment without complete provenance cannot be verified, reproduced, or peer-reviewed. MolecuLab adheres to the following principles:

1. **Immutable Inputs**: When an experiment is created, a copy of the active atomic coordinates, topology, and parameters is frozen into a content-hashed snapshot file (`structures/snapshots/<hash>.json`). Editing the molecule in the workspace never alters historical experiment inputs.
2. **Explicit Parameter Manifests**: The exact parameters passed to the solver (tolerances, step sizes, random seeds, cutoff radii) are recorded in full. Hashes are used for integrity verification, not as a replacement for raw data.
3. **Execution Environment Provenance**: Every experiment run records the Julia runtime version, exact package manifest hash, CPU model, detected GPU hardware, and timestamps.
4. **Deterministic Random Seeds**: Any stochastic algorithm (velocity initialization in MD, Monte Carlo sampling) requires an explicit or recorded pseudo-random generator seed.
5. **No Telemetry / Offline Integrity**: All manifests are stored locally in the project repository using standard, human-readable JSON formats.

---

## 2. Reproducibility Manifest Schema

Every completed or terminated experiment directory (`experiments/<id>/`) contains an `environment.json` and `manifest.json`:

```json
{
  "$schema": "https://moleculab.org/schemas/v1/experiment-manifest.json",
  "experiment_id": "EXP-2026-0001",
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "method": {
    "identifier": "geometry_optimization_lj",
    "version": "1.0.0",
    "solver": "Optim.jl/BFGS"
  },
  "provenance": {
    "input_structure_id": "struct-3f8a...",
    "input_structure_hash_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "snapshot_path": "structures/snapshots/e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.json",
    "configuration_hash_sha256": "4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a"
  },
  "configuration": {
    "potential": "lennard_jones_12_6",
    "parameters": {
      "epsilon_kj_per_mol": 1.65,
      "sigma_angstrom": 3.4
    },
    "optimizer": {
      "algorithm": "BFGS",
      "gradient_tolerance": 1e-4,
      "energy_tolerance": 1e-6,
      "max_iterations": 200
    },
    "random_seed": 42
  },
  "runtime_environment": {
    "julia_version": "1.13.3",
    "moleculab_version": "1.0.0",
    "os": "Windows 11 (x86_64-w64-mingw32)",
    "cpu": "AMD Ryzen 5 5600 6-Core Processor",
    "cpu_threads": 12,
    "gpu_detected": "NVIDIA GeForce RTX 3050 (8GB)",
    "gpu_active": false,
    "backend": "CPU",
    "numeric_precision": "Float64"
  },
  "execution": {
    "started_at": "2026-10-27T16:30:00.123Z",
    "finished_at": "2026-10-27T16:30:01.456Z",
    "elapsed_seconds": 1.333,
    "termination_status": "converged",
    "validation_status": "passed",
    "iterations_completed": 18
  },
  "artifacts": [
    {
      "name": "final_structure.xyz",
      "type": "chemical/x-xyz",
      "path": "experiments/EXP-2026-0001/results/final_structure.xyz",
      "sha256": "a1b2c3..."
    },
    {
      "name": "convergence_history.json",
      "type": "application/json",
      "path": "experiments/EXP-2026-0001/results/convergence_history.json",
      "sha256": "d4e5f6..."
    },
    {
      "name": "execution.log",
      "type": "text/plain",
      "path": "experiments/EXP-2026-0001/logs/execution.log",
      "sha256": "789abc..."
    }
  ]
}
```

---

## 3. Data Integrity & Verification Workflow

1. **Pre-Run Verification**: Check that initial coordinates contain no NaN, Inf, or zero-distance singularities.
2. **Post-Run Verification**: Check that result files exist on disk, their SHA-256 matches the manifest, and values are physically reasonable (no negative temperatures in MD, energies bounded).
3. **Re-execution Integrity Check**: Users can select any historical experiment and click "Verify Reproducibility". MolecuLab will re-run the calculation with the stored snapshot and parameters, comparing the new energy $E_{\text{new}}$ with $E_{\text{orig}}$ to within numerical tolerance ($10^{-8}$).
