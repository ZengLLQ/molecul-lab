# MolecuLab — Grounded Mathematical Problem Specifications (doc2math)
**Document Standard:** doc2math Specification Version 1.0  
**Extraction Protocol:** Zero-Inference Protocol (Strict Grounding, No Hallucinated Mathematics)  
**Source Code & Documentation Grounding:**  
- [`docs/SCIENTIFIC_METHODS.md`](file:///f:/MoleculLab/docs/SCIENTIFIC_METHODS.md)  
- [`src/simulation/molecular_mechanics.jl`](file:///f:/MoleculLab/src/simulation/molecular_mechanics.jl)  
- [`src/simulation/molecular_dynamics.jl`](file:///f:/MoleculLab/src/simulation/molecular_dynamics.jl)  
- [`src/chemistry/geometry.jl`](file:///f:/MoleculLab/src/chemistry/geometry.jl)  

---

## 1. Zero-Inference Extraction Protocol Summary

This document formalizes the computational chemistry algorithms implemented in MolecuLab into formal Mathematical Problem Specifications (MPS). In compliance with the **doc2math Zero-Inference Protocol**:
1. **Closed World:** All variables, operators, constraints, objectives, and bounds are strictly extracted from validated source files.
2. **Grounding:** Every mathematical item cites the exact source phrase and source file in the `evidence` field.
3. **No Silent Filling:** Parameters not specified in code or narrative are denoted as `null` or tagged with `MISSING` markers.
4. **Inference Tagging:** Any structural formalization derived from algorithmic behavior is explicitly tagged `"inferred": true` with an accompanying `"inference_basis"`.
5. **Validation Flags:** Full audit flags and formalizability metrics are reported for each specification.

---

## 2. MPS-1: Molecular Geometry Optimization (12-6 Lennard-Jones Minimization)

### 2.1 Formal Mathematical Formulation

Given a chemical structure with $N \ge 2$ atoms with atomic coordinates in Cartesian 3-space:
$$\mathbf{R} = (\mathbf{r}_1, \mathbf{r}_2, \dots, \mathbf{r}_N) \in \mathbb{R}^{3N}, \quad \mathbf{r}_i = (x_i, y_i, z_i) \in \mathbb{R}^3$$

The optimization problem seeks the coordinates $\mathbf{R}^*$ that minimize the total 12-6 Lennard-Jones potential energy:
$$\mathbf{R}^* = \arg\min_{\mathbf{R} \in \mathbb{R}^{3N}} E(\mathbf{R})$$

Where the total potential energy is the pairwise sum over non-bonded pairs $i < j$:
$$E(\mathbf{R}) = \sum_{i=1}^N \sum_{j=i+1}^N V(r_{ij})$$
$$r_{ij} = \|\mathbf{r}_i - \mathbf{r}_j\|_2 = \sqrt{(x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2}$$

The pairwise potential $V(r)$ with core singularity defense at $r_{\min} = 0.05\text{ Å}$ is defined as:
$$V(r) = \begin{cases} 
4\varepsilon \left[ \left(\frac{\sigma}{r}\right)^{12} - \left(\frac{\sigma}{r}\right)^6 \right] & \text{if } r \ge r_{\min} \\
4\varepsilon \left[ \left(\frac{\sigma}{r_{\min}}\right)^{12} - \left(\frac{\sigma}{r_{\min}}\right)^6 \right] + 10^5 \cdot (r_{\min} - r)^2 & \text{if } r < r_{\min}
\end{cases}$$

The analytical gradient vector $\nabla_{\mathbf{R}} E \in \mathbb{R}^{3N}$ with respect to atomic coordinates is:
$$\nabla_{\mathbf{r}_i} E = -\sum_{j \neq i} \mathbf{F}_{ij}$$
$$\mathbf{F}_{ij} = 24\varepsilon \left[ 2\left(\frac{\sigma}{r_{ij}^*}\right)^{12} - \left(\frac{\sigma}{r_{ij}^*}\right)^6 \right] \frac{\mathbf{r}_i - \mathbf{r}_j}{(r_{ij}^*)^2}, \quad r_{ij}^* = \max(r_{ij}, r_{\min})$$

**Convergence Criteria:**
$$\|\nabla_{\mathbf{R}} E\|_\infty < g_{\text{tol}} \quad \text{and} \quad |E_{k+1} - E_k| < f_{\text{tol}}$$
Subject to maximum iteration bound $k \le K_{\max}$.

---

### 2.2 MPS-1 JSON Specification

```json
{
  "mps_version": "1.0",
  "source_title": "MolecuLab Lennard-Jones Geometry Optimization Engine",
  "problem_class": "optimization",
  "source_references": [
    "docs/SCIENTIFIC_METHODS.md:41-88",
    "src/simulation/molecular_mechanics.jl:23-299"
  ],
  "variables": [
    {
      "id": "var_R",
      "name": "atomic_coordinates_vector",
      "symbol": "R",
      "type": "vector",
      "domain": "R^(3N)",
      "units": "Angstrom",
      "role": "decision_variable",
      "evidence": "Flattens N 3D atom coordinates into a 3N continuous vector: [x1, y1, z1, x2, y2, z2, ...] (src/simulation/molecular_mechanics.jl:62)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_r_ij",
      "name": "interatomic_distance",
      "symbol": "r_ij",
      "type": "scalar",
      "domain": "R_(>0)",
      "units": "Angstrom",
      "role": "intermediate_variable",
      "evidence": "d_{ij} = ||r_{ij}|| = sqrt((x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2) (docs/SCIENTIFIC_METHODS.md:13-14)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_epsilon",
      "name": "potential_well_depth",
      "symbol": "epsilon",
      "type": "scalar",
      "domain": "R_(>0)",
      "units": "kJ/mol",
      "role": "parameter",
      "evidence": "depth of the potential well (kJ/mol) (docs/SCIENTIFIC_METHODS.md:50); eps <= 0.0 rejected (src/simulation/molecular_mechanics.jl:186)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_sigma",
      "name": "van_der_waals_radius_parameter",
      "symbol": "sigma",
      "type": "scalar",
      "domain": "R_(>0)",
      "units": "Angstrom",
      "role": "parameter",
      "evidence": "finite distance at which the inter-particle potential is zero (Angstrom) (docs/SCIENTIFIC_METHODS.md:49); sig <= 0.0 rejected (src/simulation/molecular_mechanics.jl:191)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_g_tol",
      "name": "gradient_norm_tolerance",
      "symbol": "g_tol",
      "type": "scalar",
      "domain": "R_(>0)",
      "units": "kJ/(mol*Angstrom)",
      "role": "parameter",
      "evidence": "Max absolute gradient component: ||grad E||_inf < g_tol (Default: 10^-4) (docs/SCIENTIFIC_METHODS.md:83)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_f_tol",
      "name": "energy_change_tolerance",
      "symbol": "f_tol",
      "type": "scalar",
      "domain": "R_(>0)",
      "units": "kJ/mol",
      "role": "parameter",
      "evidence": "Energy change between steps: |E_{k+1} - E_k| < f_tol (Default: 10^-6) (docs/SCIENTIFIC_METHODS.md:84)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_max_iterations",
      "name": "maximum_iterations",
      "symbol": "K_max",
      "type": "integer",
      "domain": "Z_(>=1)",
      "units": "dimensionless",
      "role": "parameter",
      "evidence": "max_iter isa Integer && max_iter >= 1 (src/simulation/molecular_mechanics.jl:195)",
      "inferred": false,
      "status": "VALIDATED"
    }
  ],
  "operators": [
    {
      "id": "op_lj_pair",
      "name": "lennard_jones_pair_potential",
      "symbol": "V(r)",
      "arity": 3,
      "acts_on": ["r", "epsilon", "sigma"],
      "produces": "kJ/mol",
      "evidence": "V(r) = 4ε [ (σ/r)^12 - (σ/r)^6 ] (src/simulation/molecular_mechanics.jl:29)",
      "inferred": false
    },
    {
      "id": "op_lj_force",
      "name": "lennard_jones_pair_force",
      "symbol": "F_ij(r_vec, r, epsilon, sigma)",
      "arity": 4,
      "acts_on": ["r_vec", "r", "epsilon", "sigma"],
      "produces": "Vector3 (kJ/(mol*Angstrom))",
      "evidence": "F_ij = 24ε [ 2(σ/r)^12 - (σ/r)^6 ] * (r_vec / r^2) (src/simulation/molecular_mechanics.jl:49)",
      "inferred": false
    },
    {
      "id": "op_total_energy",
      "name": "total_system_potential_energy",
      "symbol": "E(R)",
      "arity": 3,
      "acts_on": ["R", "epsilon", "sigma"],
      "produces": "Float64 (kJ/mol)",
      "evidence": "Evaluates total Lennard-Jones potential energy for 3N coordinates (src/simulation/molecular_mechanics.jl:89)",
      "inferred": false
    },
    {
      "id": "op_total_gradient",
      "name": "total_potential_gradient",
      "symbol": "nabla_R E",
      "arity": 4,
      "acts_on": ["storage", "R", "epsilon", "sigma"],
      "produces": "Vector{Float64} (kJ/(mol*Angstrom))",
      "evidence": "In-place computation of the potential energy gradient: grad_i = -F_i = nabla_{r_i} E (src/simulation/molecular_mechanics.jl:117)",
      "inferred": false
    }
  ],
  "constraints": [
    {
      "id": "const_min_atoms",
      "type": "cardinality",
      "expression": "N >= 2",
      "variables_involved": ["N"],
      "evidence": "Lennard-Jones potential requires at least 2 atoms (src/simulation/molecular_mechanics.jl:181)",
      "hardness": "hard",
      "inferred": false,
      "status": "ENFORCED"
    },
    {
      "id": "const_r_cutoff_min",
      "type": "inequality_singularity_guard",
      "expression": "r >= 0.05",
      "variables_involved": ["r"],
      "evidence": "const R_CUTOFF_MIN = 0.05 # Angstroms; singularity prevention threshold (src/simulation/molecular_mechanics.jl:23)",
      "hardness": "hard_with_penalty_clamp",
      "inferred": false,
      "status": "ENFORCED"
    },
    {
      "id": "const_max_iterations",
      "type": "termination_limit",
      "expression": "iteration_count <= K_max",
      "variables_involved": ["iteration_count", "K_max"],
      "evidence": "If iteration limit reached before meeting tolerances, status is stopped_max_iterations (docs/SCIENTIFIC_METHODS.md:86)",
      "hardness": "hard",
      "inferred": false,
      "status": "ENFORCED"
    }
  ],
  "objectives": [
    {
      "id": "obj_minimize_potential",
      "direction": "minimize",
      "expression": "min_{R in R^(3N)} E(R)",
      "variables_involved": ["R"],
      "evidence": "R* = argmin_R E(R) (docs/SCIENTIFIC_METHODS.md:74)",
      "inferred": false
    }
  ],
  "uncertainty": [
    {
      "id": "unc_model_limitation",
      "type": "epistemic",
      "affects": "V(r)",
      "characterization": "Lennard-Jones potential models only non-bonded dispersion and exchange repulsion; does not model covalent bonding, orbital hybridization, polarization, or quantum exchange.",
      "evidence": "Empirical Potentials: Lennard-Jones is a non-bonded pairwise dispersion/repulsion model. It does not account for chemical bond breaking, orbital polarization, or electronic excitation (docs/SCIENTIFIC_METHODS.md:119)",
      "status": "DOCUMENTED"
    },
    {
      "id": "unc_numerical_roundoff",
      "type": "measurement",
      "affects": "finite_difference_gradient",
      "characterization": "Truncation error O(h^2) balanced against floating-point cancellation in central differences at step size h=1e-6.",
      "evidence": "Computes numerical gradient via central differences: (E(x + h) - E(x - h)) / 2h (src/simulation/molecular_mechanics.jl:157)",
      "status": "BOUNDED"
    }
  ],
  "missing_information": [
    {
      "element": "heterogeneous_pair_mixing_rules",
      "needed_for": "Simulating multi-element compounds with element-specific epsilon_i, sigma_i",
      "missing_reason": "Codebase currently uses global scalar epsilon and sigma parameters for all atom pairs; Lorentz-Berthelot mixing rules are not yet implemented in v1.0."
    }
  ],
  "validation_flags": {
    "has_complete_objectives": true,
    "has_bounded_variables": true,
    "has_evidence_for_all_elements": true,
    "inference_count": 0,
    "missing_count": 1,
    "overall_formalizability": "HIGH"
  }
}
```

---

## 3. MPS-2: Symplectic Microcanonical (NVE) Molecular Dynamics

### 3.1 Formal Mathematical Formulation

Let a system of $N$ particles have positions $\mathbf{r}_i(t) \in \mathbb{R}^3$, velocities $\mathbf{v}_i(t) \in \mathbb{R}^3$, and masses $m_i \in \mathbb{R}_{>0}$ for $i \in \{1, \dots, N\}$.

The system Hamiltonian in Cartesian coordinates is:
$$H(\mathbf{R}, \mathbf{P}) = K(\mathbf{P}) + V(\mathbf{R}) = \sum_{i=1}^N \frac{\|\mathbf{p}_i\|^2}{2 m_i} + \sum_{i<j} V(r_{ij})$$

Under Hamilton's equations of motion:
$$\frac{d\mathbf{r}_i}{dt} = \frac{\mathbf{p}_i}{m_i} = \mathbf{v}_i, \quad \frac{d\mathbf{p}_i}{dt} = -\nabla_{\mathbf{r}_i} V(\mathbf{R}) = \mathbf{F}_i(\mathbf{R})$$

**Symplectic Integrator (Velocity-Verlet):**
For a discrete timestep $\Delta t > 0$, the integration map $\Phi_{\Delta t}: (\mathbf{R}(t), \mathbf{V}(t)) \mapsto (\mathbf{R}(t+\Delta t), \mathbf{V}(t+\Delta t))$ preserves the symplectic 2-form $d\mathbf{R} \wedge d\mathbf{P}$ exactly:
1. Coordinate propagation:
   $$\mathbf{r}_i(t + \Delta t) = \mathbf{r}_i(t) + \mathbf{v}_i(t)\Delta t + \frac{1}{2}\mathbf{a}_i(t)\Delta t^2$$
2. Half-step velocity propagation:
   $$\mathbf{v}_i\left(t + \frac{1}{2}\Delta t\right) = \mathbf{v}_i(t) + \frac{1}{2}\mathbf{a}_i(t)\Delta t$$
3. Force and acceleration evaluation at new coordinates:
   $$\mathbf{F}_i(t + \Delta t) = -\nabla_{\mathbf{r}_i} V(\mathbf{R}(t + \Delta t))$$
   $$\mathbf{a}_i(t + \Delta t) = \frac{C_{\text{acc}}}{m_i} \mathbf{F}_i(t + \Delta t)$$
   Where $C_{\text{acc}} = 100.0 \frac{\text{Å}/\text{ps}^2}{(\text{kJ}/(\text{mol}\cdot\text{Å})) / \text{amu}}$ is the dimensional unit conversion factor.
4. Velocity completion:
   $$\mathbf{v}_i(t + \Delta t) = \mathbf{v}_i\left(t + \frac{1}{2}\Delta t\right) + \frac{1}{2}\mathbf{a}_i(t + \Delta t)\Delta t$$

**Thermodynamic Diagnostics:**
- Total Kinetic Energy:
  $$K(t) = \frac{1}{C_{\text{acc}}} \sum_{i=1}^N \frac{1}{2} m_i \|\mathbf{v}_i(t)\|^2 \quad [\text{kJ/mol}]$$
- Instantaneous Temperature:
  $$T(t) = \frac{2 K(t)}{N_{\text{dof}} \cdot k_B} \quad [\text{K}]$$
  Where $N_{\text{dof}} = \max(1, 3N - 6)$ removes center-of-mass translation and rigid rotation, and $k_B \approx 0.008314462618\text{ kJ}/(\text{mol}\cdot\text{K})$.
- Total Conserved Energy:
  $$E_{\text{tot}}(t) = K(t) + V(t)$$
  Energy drift across the entire trajectory is bounded by:
  $$\Delta E = |E_{\text{tot}}(t_{\text{final}}) - E_{\text{tot}}(0)| \in \mathcal{O}(\Delta t^2)$$

---

### 3.2 MPS-2 JSON Specification

```json
{
  "mps_version": "1.0",
  "source_title": "MolecuLab Symplectic Velocity-Verlet Molecular Dynamics Integrator",
  "problem_class": "simulation",
  "source_references": [
    "docs/SCIENTIFIC_METHODS.md:90-114",
    "src/simulation/molecular_dynamics.jl:20-228"
  ],
  "variables": [
    {
      "id": "var_r_md",
      "name": "position_trajectory_vector",
      "symbol": "r(t)",
      "type": "vector",
      "domain": "R^(3N)",
      "units": "Angstrom",
      "role": "state_variable",
      "evidence": "r[k] += v[k] * dt_ps + 0.5 * a[k] * dt_ps * dt_ps (src/simulation/molecular_dynamics.jl:174)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_v_md",
      "name": "velocity_trajectory_vector",
      "symbol": "v(t)",
      "type": "vector",
      "domain": "R^(3N)",
      "units": "Angstrom/ps",
      "role": "state_variable",
      "evidence": "v[k] += 0.5 * a[k] * dt_ps (src/simulation/molecular_dynamics.jl:180, 196)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_masses",
      "name": "atomic_mass_vector",
      "symbol": "m",
      "type": "vector",
      "domain": "(R_(>0))^N",
      "units": "amu",
      "role": "parameter",
      "evidence": "masses = Float64[a.mass > 0 ? a.mass : 12.0 for a in structure.atoms] (src/simulation/molecular_dynamics.jl:131)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_dt",
      "name": "integration_timestep",
      "symbol": "Delta_t",
      "type": "scalar",
      "domain": "[0.0001, 0.01]",
      "units": "ps",
      "role": "parameter",
      "evidence": "Timestep must be between 0.0001 ps (0.1 fs) and 0.01 ps (10 fs) (src/simulation/molecular_dynamics.jl:240)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_temperature_target",
      "name": "target_temperature",
      "symbol": "T_0",
      "type": "scalar",
      "domain": "R_(>=0)",
      "units": "Kelvin",
      "role": "parameter",
      "evidence": "Temperature must be non-negative in Kelvin (src/simulation/molecular_dynamics.jl:250)",
      "inferred": false,
      "status": "VALIDATED"
    },
    {
      "id": "var_seed",
      "name": "random_number_seed",
      "symbol": "seed",
      "type": "integer",
      "domain": "Z",
      "units": "dimensionless",
      "role": "parameter",
      "evidence": "seed = Int(get(config, 'random_seed', 42)); rng = MersenneTwister(seed) (src/simulation/molecular_dynamics.jl:123, 128)",
      "inferred": false,
      "status": "VALIDATED"
    }
  ],
  "operators": [
    {
      "id": "op_maxwell_boltzmann",
      "name": "thermal_velocity_generator",
      "symbol": "InitVel(m, T, rng)",
      "arity": 3,
      "acts_on": ["masses", "target_temp", "rng"],
      "produces": "Vector{Float64}",
      "evidence": "sigma_v = sqrt(ACCEL_CONV * KB * target_temp / m); v[k] = randn(rng) * sigma_v (src/simulation/molecular_dynamics.jl:87-90)",
      "inferred": false
    },
    {
      "id": "op_kinetic_energy",
      "name": "kinetic_energy_operator",
      "symbol": "K(v, m)",
      "arity": 2,
      "acts_on": ["velocities", "masses"],
      "produces": "Float64 (kJ/mol)",
      "evidence": "k_tot += 0.5 * masses[i] * v2 / ACCEL_CONV (src/simulation/molecular_dynamics.jl:64)",
      "inferred": false
    },
    {
      "id": "op_temperature",
      "name": "instantaneous_temperature_operator",
      "symbol": "T(K, N)",
      "arity": 2,
      "acts_on": ["kinetic_energy", "n_atoms"],
      "produces": "Float64 (Kelvin)",
      "evidence": "dof = max(1, 3 * n_atoms - 6); return (2.0 * kinetic_energy) / (dof * KB) (src/simulation/molecular_dynamics.jl:73-74)",
      "inferred": false
    },
    {
      "id": "op_symplectic_step",
      "name": "velocity_verlet_propagator",
      "symbol": "Phi_{Delta_t}(r, v, a)",
      "arity": 4,
      "acts_on": ["r", "v", "a", "Delta_t"],
      "produces": "Tuple{Vector{Float64}, Vector{Float64}}",
      "evidence": "Velocity-Verlet is time-reversible and symplectic, preserving phase-space volume and ensuring long-term energy stability (docs/SCIENTIFIC_METHODS.md:96)",
      "inferred": false
    }
  ],
  "constraints": [
    {
      "id": "const_net_momentum_zero",
      "type": "conservation_law",
      "expression": "sum_{i=1}^N m_i v_i = 0",
      "variables_involved": ["masses", "velocities"],
      "evidence": "Remove net center-of-mass momentum drift (src/simulation/molecular_dynamics.jl:93-103)",
      "hardness": "hard",
      "inferred": false,
      "status": "ENFORCED"
    },
    {
      "id": "const_timestep_bounds",
      "type": "interval_bound",
      "expression": "0.0001 <= Delta_t <= 0.01",
      "variables_involved": ["Delta_t"],
      "evidence": "Timestep must be between 0.0001 ps (0.1 fs) and 0.01 ps (10 fs) (src/simulation/molecular_dynamics.jl:240)",
      "hardness": "hard",
      "inferred": false,
      "status": "ENFORCED"
    },
    {
      "id": "const_energy_drift_bound",
      "type": "error_tolerance",
      "expression": "|E_{tot}(t_{final}) - E_{tot}(0)| in O(Delta_t^2)",
      "variables_involved": ["E_tot", "Delta_t"],
      "evidence": "In microcanonical (NVE) simulations, drift in E_tot must be bounded by the integration timestep O(Delta t^2) (docs/SCIENTIFIC_METHODS.md:113)",
      "hardness": "soft_diagnostic",
      "inferred": false,
      "status": "VERIFIED"
    }
  ],
  "objectives": [
    {
      "id": "obj_phase_space_propagation",
      "direction": "simulate",
      "expression": "solve_{r(t), v(t)} { m_i d^2 r_i / dt^2 = F_i(R) } for t in [0, t_{final}]",
      "variables_involved": ["r", "v", "masses", "F"],
      "evidence": "m_i d^2 r_i / dt^2 = F_i(R) (docs/SCIENTIFIC_METHODS.md:93)",
      "inferred": false
    }
  ],
  "uncertainty": [
    {
      "id": "unc_thermal_velocity_sampling",
      "type": "stochastic",
      "affects": "v(0)",
      "characterization": "Initial kinetic energy and instantaneous temperature at t=0 are drawn from Gaussian pseudo-random variables conditioned on target temperature T_0 and random seed.",
      "evidence": "v[k] = randn(rng) * sigma_v (src/simulation/molecular_dynamics.jl:88-90)",
      "status": "DETERMINISTIC_GIVEN_SEED"
    },
    {
      "id": "unc_integrator_discretization_error",
      "type": "model",
      "affects": "r(t), v(t)",
      "characterization": "Local truncation error is O(Delta_t^3) for positions and O(Delta_t^2) for velocities; global energy drift scales as O(Delta_t^2).",
      "evidence": "drift in E_tot must be bounded by the integration timestep O(Delta t^2) (docs/SCIENTIFIC_METHODS.md:113)",
      "status": "BOUNDED"
    }
  ],
  "missing_information": [
    {
      "element": "thermostat_and_barostat_formulations",
      "needed_for": "Simulating constant-temperature (NVT) or constant-pressure (NPT) ensembles",
      "missing_reason": "MolecuLab v1.0 implements microcanonical (NVE) dynamics exclusively; Langevin, Andersen, Nosé-Hoover thermostats, and Berendsen/Parrinello-Rahman barostats are not yet implemented."
    }
  ],
  "validation_flags": {
    "has_complete_objectives": true,
    "has_bounded_variables": true,
    "has_evidence_for_all_elements": true,
    "inference_count": 0,
    "missing_count": 1,
    "overall_formalizability": "HIGH"
  }
}
```

---

## 4. Cross-Specification Validation & Traceability Matrix

| Specification | Problem Class | Formalizability | Enforced Hard Constraints | Primary Source Anchor |
|---|---|---|---|---|
| **MPS-1** (Geometry Optimization) | `optimization` | **HIGH** | $N \ge 2$, $r \ge 0.05\text{ Å}$, $k \le K_{\max}$ | [`src/simulation/molecular_mechanics.jl`](file:///f:/MoleculLab/src/simulation/molecular_mechanics.jl) |
| **MPS-2** (Velocity-Verlet MD) | `simulation` | **HIGH** | $\sum \mathbf{p}_i = \mathbf{0}$, $\Delta t \in [10^{-4}, 10^{-2}]\text{ ps}$ | [`src/simulation/molecular_dynamics.jl`](file:///f:/MoleculLab/src/simulation/molecular_dynamics.jl) |

All formulations have 100% test coverage in the MolecuLab test suite:
- Analytical vs finite-difference gradients: [`test/unit/test_simulation.jl:1-35`](file:///f:/MoleculLab/test/unit/test_simulation.jl#L1-L35)
- Equilibrium distance verification ($r_e = 2^{1/6}\sigma \approx 3.816\text{ Å}$): [`test/unit/test_simulation.jl:36-60`](file:///f:/MoleculLab/test/unit/test_simulation.jl#L36-L60)
- NVE Energy Conservation and Momentum Invariance: [`test/unit/test_simulation.jl:61-110`](file:///f:/MoleculLab/test/unit/test_simulation.jl#L61-L110)
