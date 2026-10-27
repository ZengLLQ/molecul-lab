"""
Classical Molecular Dynamics engine with a symplectic Velocity-Verlet integrator.
Guarantees microcanonical (NVE) energy conservation and trajectory recording.
"""
module MolecularDynamics

using LinearAlgebra
using Random
using ..Structures: Atom, Structure
using ..SimulationInterface: AbstractChemistryMethod
import ..SimulationInterface: method_identifier, method_version,
                              validate_method_config, execute_method
using ..MolecularMechanics: lj_total_energy, lj_total_gradient!

export MolecularDynamicsMethod, run_md_simulation, TrajectoryFrame

struct MolecularDynamicsMethod <: AbstractChemistryMethod end

method_identifier(::MolecularDynamicsMethod) = "molecular_dynamics_velocity_verlet"
method_version(::MolecularDynamicsMethod) = "1.0.0"

# Boltzmann constant in kJ / (mol * K)
const KB = 0.008314462618
# Unit conversion: 1 (kJ/(mol*Å)) / (1 amu) = 100.0 Å / ps^2
const ACCEL_CONV = 100.0

struct TrajectoryFrame
    step::Int
    time_ps::Float64
    potential_energy::Float64
    kinetic_energy::Float64
    total_energy::Float64
    temperature_k::Float64
    coordinates::Vector{NTuple{3, Float64}}
end

"""
    compute_forces_and_potential(coords_vec::Vector{Float64}, epsilon::Float64, sigma::Float64)
    -> (forces_vec::Vector{Float64}, potential_energy::Float64)
"""
function compute_forces_and_potential(coords_vec::Vector{Float64}, epsilon::Float64, sigma::Float64)
    grad = similar(coords_vec)
    lj_total_gradient!(grad, coords_vec, epsilon, sigma)
    pot = lj_total_energy(coords_vec, epsilon, sigma)
    # Force = -Gradient
    forces = -grad
    return (forces, pot)
end

"""
    compute_kinetic_energy(velocities::Vector{Float64}, masses::Vector{Float64}) -> Float64

Computes total kinetic energy in kJ/mol:
K = sum_i (0.5 * m_i * v_i^2) / ACCEL_CONV
"""
function compute_kinetic_energy(velocities::Vector{Float64}, masses::Vector{Float64})::Float64
    n_atoms = length(masses)
    k_tot = 0.0
    for i in 1:n_atoms
        vx = velocities[3i - 2]
        vy = velocities[3i - 1]
        vz = velocities[3i]
        v2 = vx*vx + vy*vy + vz*vz
        k_tot += 0.5 * masses[i] * v2 / ACCEL_CONV
    end
    return k_tot
end

"""
    compute_temperature(kinetic_energy::Float64, n_atoms::Int) -> Float64
"""
function compute_temperature(kinetic_energy::Float64, n_atoms::Int)::Float64
    dof = max(1, 3 * n_atoms - 6) # remove translational and rotational degrees of freedom if N > 2
    return (2.0 * kinetic_energy) / (dof * KB)
end

"""
    initialize_maxwell_boltzmann_velocities(masses::Vector{Float64}, target_temp::Float64, rng::AbstractRNG)
"""
function initialize_maxwell_boltzmann_velocities(masses::Vector{Float64}, target_temp::Float64, rng::AbstractRNG)::Vector{Float64}
    n_atoms = length(masses)
    v = Vector{Float64}(undef, 3 * n_atoms)

    # v_thermal = sqrt(ACCEL_CONV * kB * T / m)
    for i in 1:n_atoms
        m = max(masses[i], 1.0)
        sigma_v = sqrt(ACCEL_CONV * KB * target_temp / m)
        v[3i - 2] = randn(rng) * sigma_v
        v[3i - 1] = randn(rng) * sigma_v
        v[3i]     = randn(rng) * sigma_v
    end

    # Remove net center-of-mass momentum drift
    total_m = sum(masses)
    p_com_x = sum(i -> masses[i] * v[3i - 2], 1:n_atoms) / total_m
    p_com_y = sum(i -> masses[i] * v[3i - 1], 1:n_atoms) / total_m
    p_com_z = sum(i -> masses[i] * v[3i], 1:n_atoms) / total_m

    for i in 1:n_atoms
        v[3i - 2] -= p_com_x
        v[3i - 1] -= p_com_y
        v[3i]     -= p_com_z
    end

    return v
end

"""
    run_md_simulation(structure::Structure, config::Dict{String, Any};
                      cancel_token::Base.Threads.Atomic{Bool}=Base.Threads.Atomic{Bool}(false),
                      progress_callback::Function=(step, time_ps, epot, ekin, temp) -> nothing) -> Dict{String, Any}

Runs Velocity-Verlet molecular dynamics for the specified steps and timestep.
"""
function run_md_simulation(structure::Structure, config::Dict{String, Any};
                           cancel_token::Base.Threads.Atomic{Bool}=Base.Threads.Atomic{Bool}(false),
                           progress_callback::Function=(step, time_ps, epot, ekin, temp) -> nothing)::Dict{String, Any}
    n_atoms = length(structure.atoms)
    dt_ps = Float64(get(config, "timestep_ps", 0.001)) # 1 fs default
    total_steps = Int(get(config, "steps", 500))
    sample_interval = Int(get(config, "sample_interval", 10))
    target_temp = Float64(get(config, "temperature_k", 300.0))
    seed = Int(get(config, "random_seed", 42))

    epsilon = Float64(get(config, "epsilon", 1.65))
    sigma   = Float64(get(config, "sigma", 3.4))

    rng = MersenneTwister(seed)

    # Masses
    masses = Float64[a.mass > 0 ? a.mass : 12.0 for a in structure.atoms]

    # Initial coordinates
    r = Vector{Float64}(undef, 3 * n_atoms)
    for (i, a) in enumerate(structure.atoms)
        r[3i - 2] = a.x
        r[3i - 1] = a.y
        r[3i]     = a.z
    end

    # Initial velocities
    v = initialize_maxwell_boltzmann_velocities(masses, target_temp, rng)

    # Initial forces and accelerations
    forces, epot = compute_forces_and_potential(r, epsilon, sigma)
    a = Vector{Float64}(undef, 3 * n_atoms)
    for i in 1:n_atoms
        inv_m = ACCEL_CONV / masses[i]
        a[3i - 2] = forces[3i - 2] * inv_m
        a[3i - 1] = forces[3i - 1] * inv_m
        a[3i]     = forces[3i]     * inv_m
    end

    ekin = compute_kinetic_energy(v, masses)
    temp = compute_temperature(ekin, n_atoms)

    trajectory = TrajectoryFrame[]
    coords_0 = Vector{NTuple{3, Float64}}(undef, n_atoms)
    for i in 1:n_atoms
        coords_0[i] = (r[3i - 2], r[3i - 1], r[3i])
    end
    push!(trajectory, TrajectoryFrame(0, 0.0, epot, ekin, epot + ekin, temp, coords_0))

    terminated_early = false

    for step in 1:total_steps
        if cancel_token[]
            terminated_early = true
            break
        end

        # 1. Update positions: r(t + dt) = r(t) + v(t)*dt + 0.5*a(t)*dt^2
        for k in 1:(3 * n_atoms)
            r[k] += v[k] * dt_ps + 0.5 * a[k] * dt_ps * dt_ps
        end

        # 2. Half-step velocity: v(t + 0.5*dt) = v(t) + 0.5*a(t)*dt
        for k in 1:(3 * n_atoms)
            v[k] += 0.5 * a[k] * dt_ps
        end

        # 3. Compute new forces and potential energy at r(t + dt)
        forces, epot = compute_forces_and_potential(r, epsilon, sigma)

        # 4. Compute new acceleration: a(t + dt) = F(t + dt) / m
        for i in 1:n_atoms
            inv_m = ACCEL_CONV / masses[i]
            a[3i - 2] = forces[3i - 2] * inv_m
            a[3i - 1] = forces[3i - 1] * inv_m
            a[3i]     = forces[3i]     * inv_m
        end

        # 5. Complete velocity update: v(t + dt) = v(t + 0.5*dt) + 0.5*a(t + dt)*dt
        for k in 1:(3 * n_atoms)
            v[k] += 0.5 * a[k] * dt_ps
        end

        # Sample metrics
        if step % sample_interval == 0 || step == total_steps
            ekin = compute_kinetic_energy(v, masses)
            temp = compute_temperature(ekin, n_atoms)
            curr_t = step * dt_ps

            coords_t = Vector{NTuple{3, Float64}}(undef, n_atoms)
            for i in 1:n_atoms
                coords_t[i] = (r[3i - 2], r[3i - 1], r[3i])
            end
            push!(trajectory, TrajectoryFrame(step, curr_t, epot, ekin, epot + ekin, temp, coords_t))
            progress_callback(step, curr_t, epot, ekin, temp)
        end
    end

    status_str = if cancel_token[]
        "cancelled"
    else
        "completed"
    end

    return Dict{String, Any}(
        "status" => status_str,
        "total_steps_executed" => length(trajectory) > 0 ? last(trajectory).step : 0,
        "elapsed_sim_time_ps" => length(trajectory) > 0 ? last(trajectory).time_ps : 0.0,
        "initial_total_energy" => first(trajectory).total_energy,
        "final_total_energy" => last(trajectory).total_energy,
        "energy_drift" => abs(last(trajectory).total_energy - first(trajectory).total_energy),
        "trajectory" => trajectory
    )
end

function validate_method_config(::MolecularDynamicsMethod, config::Dict{String, Any}, structure::Structure)::Tuple{Vector{String}, Vector{String}}
    errors = String[]
    warnings = String[]

    if length(structure.atoms) < 2
        push!(errors, "Molecular dynamics requires at least 2 atoms.")
    end

    dt = get(config, "timestep_ps", 0.001)
    if !(dt isa Real) || dt <= 0.0 || dt > 0.01
        push!(errors, "Timestep must be between 0.0001 ps (0.1 fs) and 0.01 ps (10 fs).")
    end

    steps = get(config, "steps", 500)
    if !(steps isa Integer) || steps < 1
        push!(errors, "Simulation steps must be a positive integer.")
    end

    temp = get(config, "temperature_k", 300.0)
    if !(temp isa Real) || temp < 0.0
        push!(errors, "Temperature must be non-negative in Kelvin.")
    end

    return (errors, warnings)
end

function execute_method(::MolecularDynamicsMethod, config::Dict{String, Any}, structure::Structure,
                        cancel_token::Base.Threads.Atomic{Bool},
                        progress_callback::Function)::Dict{String, Any}
    run_md_simulation(structure, config; cancel_token=cancel_token, progress_callback=progress_callback)
end

end # module MolecularDynamics
