# MolecuLab — Scientific Methods, Formulations & Validation Standards
**Specification Version:** 1.0  
**Scope:** Classical Mechanics, Geometry Analysis, Numerical Optimization, Integrators

---

## 1. Geometric Formulations & Edge Handling

All internal coordinates in MolecuLab use **Cartesian 3-vectors** $\mathbf{r}_i = (x_i, y_i, z_i) \in \mathbb{R}^3$ expressed in **Angstroms (Å)** ($1\text{ Å} = 10^{-10}\text{ m} = 0.1\text{ nm}$).

### 1.1 Pairwise Interatomic Distance
For atoms $i$ and $j$:
$$\mathbf{r}_{ij} = \mathbf{r}_i - \mathbf{r}_j$$
$$d_{ij} = \|\mathbf{r}_{ij}\| = \sqrt{(x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2}$$

**Numerical Safeguard:**
If $d_{ij} < 10^{-12}\text{ Å}$, the atoms are flagged as **coincident**. Any division by $d_{ij}$ is barred, and a `GeometricSingularityError` or validation warning is issued.

### 1.2 Bond Angle
For a triplet of atoms $i - j - k$ where $j$ is the central vertex:
$$\mathbf{u} = \mathbf{r}_i - \mathbf{r}_j, \quad \mathbf{v} = \mathbf{r}_k - \mathbf{r}_j$$
$$\cos \theta = \text{clamp}\left(\frac{\mathbf{u} \cdot \mathbf{v}}{\|\mathbf{u}\| \|\mathbf{v}\|}, -1.0, 1.0\right)$$
$$\theta = \arccos(\cos \theta)$$

**Numerical Safeguard:**
Floating-point rounding errors can cause $\frac{\mathbf{u} \cdot \mathbf{v}}{\|\mathbf{u}\| \|\mathbf{v}\|}$ to evaluate to $1.0000000000000002$ or $-1.0000000000000002$, which causes $\arccos$ in standard arithmetic to return `NaN`. Clamping to the interval $[-1, 1]$ is strictly enforced. If $\|\mathbf{u}\| < 10^{-12}$ or $\|\mathbf{v}\| < 10^{-12}$, the angle is undefined.

### 1.3 Dihedral (Torsion) Angle
For a four-atom chain $i - j - k - l$:
$$\mathbf{b}_1 = \mathbf{r}_j - \mathbf{r}_i, \quad \mathbf{b}_2 = \mathbf{r}_k - \mathbf{r}_j, \quad \mathbf{b}_3 = \mathbf{r}_l - \mathbf{r}_k$$
Normal vectors to the two planes:
$$\mathbf{n}_1 = \mathbf{b}_1 \times \mathbf{b}_2, \quad \mathbf{n}_2 = \mathbf{b}_2 \times \mathbf{b}_3$$
Unit vector along the central bond:
$$\hat{\mathbf{b}}_2 = \frac{\mathbf{b}_2}{\|\mathbf{b}_2\|}$$
$$\phi = \text{atan2}((\mathbf{n}_1 \times \mathbf{n}_2) \cdot \hat{\mathbf{b}}_2, \mathbf{n}_1 \cdot \mathbf{n}_2)$$

Signed range: $[-\pi, \pi]$ radians ($-180^\circ$ to $+180^\circ$). If any of the bond vectors are collinear ($\|\mathbf{n}_1\| < 10^{-12}$ or $\|\mathbf{n}_2\| < 10^{-12}$), the dihedral is undefined.

---

## 2. Reference Energy Kernel: Lennard-Jones (12-6) Potential

MolecuLab implements the 12-6 Lennard-Jones pair potential as an explicitly verified educational and benchmarking kernel:

$$V(r) = 4\varepsilon \left[ \left(\frac{\sigma}{r}\right)^{12} - \left(\frac{\sigma}{r}\right)^6 \right]$$

Where:
- $r$: interatomic distance (Å)
- $\sigma$: finite distance at which the inter-particle potential is zero (Å)
- $\varepsilon$: depth of the potential well (kJ/mol)

### 2.1 Analytical Gradient and Force
The force $\mathbf{F}_i$ on atom $i$ due to atom $j$ is the negative gradient of potential energy with respect to $\mathbf{r}_i$:
$$\mathbf{F}_{ij} = -\nabla_{\mathbf{r}_i} V(r_{ij}) = -\frac{dV}{dr_{ij}} \frac{\mathbf{r}_i - \mathbf{r}_j}{r_{ij}}$$
$$\frac{dV}{dr} = 4\varepsilon \left[ -12 \frac{\sigma^{12}}{r^{13}} + 6 \frac{\sigma^6}{r^7} \right] = -\frac{24\varepsilon}{r} \left[ 2\left(\frac{\sigma}{r}\right)^{12} - \left(\frac{\sigma}{r}\right)^6 \right]$$
$$\mathbf{F}_{ij} = 24\varepsilon \left[ 2\left(\frac{\sigma}{r_{ij}}\right)^{12} - \left(\frac{\sigma}{r_{ij}}\right)^6 \right] \frac{\mathbf{r}_i - \mathbf{r}_j}{r_{ij}^2}$$

Notice Newton's third law: $\mathbf{F}_{ji} = -\mathbf{F}_{ij}$.

### 2.2 Analytical Equilibrium Constants
- Zero crossing: $V(\sigma) = 0$.
- Energy minimum (equilibrium distance):
  $$\frac{dV}{dr} = 0 \implies 2\left(\frac{\sigma}{r_e}\right)^6 = 1 \implies r_e = 2^{1/6}\sigma \approx 1.122462048309373 \cdot \sigma$$
  $$V(r_e) = -\varepsilon$$

### 2.3 Singularity Protection
As $r \to 0$, $r^{-12} \to \infty$. A minimum safe radius $r_{\min} = 0.05\text{ Å}$ is enforced. Configurations with $r < r_{\min}$ receive a clamped harmonic penalty repulsive energy and logged warning rather than producing IEEE `Inf` or `NaN`.

---

## 3. Geometry Optimization Formulation

Find the atomic coordinates $\mathbf{R}^* \in \mathbb{R}^{3N}$ that minimize the potential energy:
$$\mathbf{R}^* = \arg\min_{\mathbf{R}} E(\mathbf{R})$$

### 3.1 Solvers
- **L-BFGS / BFGS**: Quasi-Newton methods with inverse Hessian updates.
- **Conjugate Gradient (CG)**: Low memory requirements for large systems.
- **Gradient Descent**: Robust baseline for rough initial structures.

### 3.2 Convergence Criteria
An optimization run is declared `converged` **only if both**:
1. Max absolute gradient component: $\|\nabla E\|_\infty < g_{\text{tol}}$ (Default: $10^{-4}\text{ kJ/(mol}\cdot\text{Å)}$).
2. Energy change between steps: $|E_{k+1} - E_k| < f_{\text{tol}}$ (Default: $10^{-6}\text{ kJ/mol}$).

If the maximum iteration count is reached before meeting tolerances, the status is explicitly logged as `stopped_max_iterations`, **never** as converged.

---

## 4. Molecular Dynamics: Symplectic Integration

For a system of $N$ particles with masses $m_i$:
$$m_i \frac{d^2 \mathbf{r}_i}{dt^2} = \mathbf{F}_i(\mathbf{R})$$

### 4.1 Velocity-Verlet Algorithm
Velocity-Verlet is time-reversible and symplectic, preserving phase-space volume and ensuring long-term energy stability in NVE simulations:
1. Update positions:
   $$\mathbf{r}_i(t + \Delta t) = \mathbf{r}_i(t) + \mathbf{v}_i(t)\Delta t + \frac{1}{2m_i}\mathbf{F}_i(t)\Delta t^2$$
2. Half-step velocity update:
   $$\mathbf{v}_i(t + \frac{1}{2}\Delta t) = \mathbf{v}_i(t) + \frac{1}{2m_i}\mathbf{F}_i(t)\Delta t$$
3. Compute new forces $\mathbf{F}_i(t + \Delta t)$ from new positions $\mathbf{R}(t + \Delta t)$.
4. Complete velocity update:
   $$\mathbf{v}_i(t + \Delta t) = \mathbf{v}_i(t + \frac{1}{2}\Delta t) + \frac{1}{2m_i}\mathbf{F}_i(t + \Delta t)\Delta t$$

### 4.2 Thermodynamic Quantities
- **Kinetic Energy:**
  $$K = \sum_{i=1}^N \frac{1}{2} m_i \|\mathbf{v}_i\|^2$$
- **Instantaneous Temperature:**
  $$T = \frac{2K}{3N k_B}$$
  (where $k_B$ is the Boltzmann constant).
- **Total Energy:**
  $$E_{\text{tot}} = K + V$$
  In microcanonical (NVE) simulations, drift in $E_{\text{tot}}$ must be bounded by the integration timestep $\mathcal{O}(\Delta t^2)$.

---

## 5. Scope Limitations & Scientific Disclaimers

1. **Empirical Potentials**: Lennard-Jones is a non-bonded pairwise dispersion/repulsion model. It does not account for chemical bond breaking, orbital polarization, or electronic excitation.
2. **Bioactivity & Toxicity**: Molecular descriptors (molecular weight, formula, heavy atom count) are topological and physical properties. They must **never** be interpreted as clinical predictions of toxicity, pharmacological efficacy, or binding affinity without rigorous, empirically validated biological assays.
3. **Quantum Chemistry**: Periodic plane-wave DFT (e.g. DFTK.jl) requires periodic boundary conditions and pseudopotentials. It is not an unconstrained drop-in replacement for all isolated organic molecules.
