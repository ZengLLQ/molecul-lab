"""
Molecular Mechanics: 12-6 Lennard-Jones reference potential and geometry optimization engine.
Integrates with Optim.jl for robust, gradient-based minimization.
"""
module MolecularMechanics

using LinearAlgebra
using Optim
using ..Structures: Atom, Bond, Structure
using ..Geometry: distance
using ..SimulationInterface: AbstractChemistryMethod
import ..SimulationInterface: method_identifier, method_version,
                              validate_method_config, execute_method

export LennardJonesMethod, lj_pair_potential, lj_pair_force, lj_total_energy,
       lj_total_gradient!, finite_difference_gradient, optimize_geometry

struct LennardJonesMethod <: AbstractChemistryMethod end

method_identifier(::LennardJonesMethod) = "lennard_jones_optimization"
method_version(::LennardJonesMethod) = "1.0.0"

const R_CUTOFF_MIN = 0.05 # Angstroms; singularity prevention threshold

"""
    lj_pair_potential(r::Float64, epsilon::Float64, sigma::Float64) -> Float64

Evaluates the 12-6 Lennard-Jones potential between two particles at distance `r`:
V(r) = 4ε [ (σ/r)^12 - (σ/r)^6 ]
Safely clamps if r < R_CUTOFF_MIN to prevent floating-point overflow.
"""
function lj_pair_potential(r::Float64, epsilon::Float64, sigma::Float64)::Float64
    if r < R_CUTOFF_MIN
        # Singularity defense: harmonic penalty cap
        r_safe = R_CUTOFF_MIN
        sr6 = (sigma / r_safe)^6
        base_v = 4.0 * epsilon * (sr6 * sr6 - sr6)
        dr = R_CUTOFF_MIN - r
        return base_v + 1e5 * dr^2
    end
    sr6 = (sigma / r)^6
    return 4.0 * epsilon * (sr6 * sr6 - sr6)
end

"""
    lj_pair_force(r_vec::NTuple{3, Float64}, r::Float64, epsilon::Float64, sigma::Float64) -> NTuple{3, Float64}

Calculates the force vector F_ij exerted on atom i by atom j (r_vec = r_i - r_j):
F_ij = 24ε [ 2(σ/r)^12 - (σ/r)^6 ] * (r_vec / r^2)
"""
function lj_pair_force(r_vec::NTuple{3, Float64}, r::Float64, epsilon::Float64, sigma::Float64)::NTuple{3, Float64}
    r_safe = max(r, R_CUTOFF_MIN)
    sr6 = (sigma / r_safe)^6
    # coefficient = 24 * epsilon * (2*sr12 - sr6) / r^2
    coef = 24.0 * epsilon * (2.0 * sr6 * sr6 - sr6) / (r_safe * r_safe)
    return (coef * r_vec[1], coef * r_vec[2], coef * r_vec[3])
end

"""
    coords_to_vector(atoms::Vector{Atom}) -> Vector{Float64}

Flattens N 3D atom coordinates into a 3N continuous vector: [x1, y1, z1, x2, y2, z2, ...]
"""
function coords_to_vector(atoms::Vector{Atom})::Vector{Float64}
    v = Vector{Float64}(undef, 3 * length(atoms))
    for (i, a) in enumerate(atoms)
        v[3i - 2] = a.x
        v[3i - 1] = a.y
        v[3i]     = a.z
    end
    return v
end

"""
    vector_to_coords(v::AbstractVector{Float64}) -> Vector{NTuple{3, Float64}}
"""
function vector_to_coords(v::AbstractVector{Float64})::Vector{NTuple{3, Float64}}
    n = length(v) ÷ 3
    coords = Vector{NTuple{3, Float64}}(undef, n)
    for i in 1:n
        coords[i] = (v[3i - 2], v[3i - 1], v[3i])
    end
    return coords
end

"""
    lj_total_energy(coords::AbstractVector{Float64}, epsilon::Float64, sigma::Float64) -> Float64

Evaluates total Lennard-Jones potential energy for 3N coordinates.
"""
function lj_total_energy(x::AbstractVector{Float64}, epsilon::Float64, sigma::Float64)::Float64
    n_atoms = length(x) ÷ 3
    e_tot = 0.0

    for i in 1:n_atoms
        xi = x[3i - 2]
        yi = x[3i - 1]
        zi = x[3i]
        for j in (i+1):n_atoms
            xj = x[3j - 2]
            yj = x[3j - 1]
            zj = x[3j]
            dx = xi - xj
            dy = yi - yj
            dz = zi - zj
            r = sqrt(dx*dx + dy*dy + dz*dz)
            e_tot += lj_pair_potential(r, epsilon, sigma)
        end
    end
    return e_tot
end

"""
    lj_total_gradient!(grad::AbstractVector{Float64}, x::AbstractVector{Float64}, epsilon::Float64, sigma::Float64)

In-place computation of the potential energy gradient: grad_i = -F_i = ∇_{r_i} E.
"""
function lj_total_gradient!(grad::AbstractVector{Float64}, x::AbstractVector{Float64},
                            epsilon::Float64, sigma::Float64)
    fill!(grad, 0.0)
    n_atoms = length(x) ÷ 3

    for i in 1:n_atoms
        xi = x[3i - 2]
        yi = x[3i - 1]
        zi = x[3i]
        for j in (i+1):n_atoms
            xj = x[3j - 2]
            yj = x[3j - 1]
            zj = x[3j]
            dx = xi - xj
            dy = yi - yj
            dz = zi - zj
            r = sqrt(dx*dx + dy*dy + dz*dz)

            # Force on i from j: F_ij
            f_ij = lj_pair_force((dx, dy, dz), r, epsilon, sigma)

            # Gradient = -Force
            # grad_i -= F_ij
            grad[3i - 2] -= f_ij[1]
            grad[3i - 1] -= f_ij[2]
            grad[3i]     -= f_ij[3]

            # Newton's 3rd law: F_ji = -F_ij => grad_j -= F_ji = +F_ij
            grad[3j - 2] += f_ij[1]
            grad[3j - 1] += f_ij[2]
            grad[3j]     += f_ij[3]
        end
    end
    return grad
end

"""
    finite_difference_gradient(x::AbstractVector{Float64}, epsilon::Float64, sigma::Float64, h::Float64=1e-6) -> Vector{Float64}

Computes numerical gradient via central differences: (E(x + h) - E(x - h)) / 2h.
Used for rigorous unit testing of the analytical gradient.
"""
function finite_difference_gradient(x::AbstractVector{Float64}, epsilon::Float64, sigma::Float64, h::Float64=1e-6)::Vector{Float64}
    grad_num = similar(x)
    x_pert = copy(x)
    for k in eachindex(x)
        x_pert[k] = x[k] + h
        e_plus = lj_total_energy(x_pert, epsilon, sigma)

        x_pert[k] = x[k] - h
        e_minus = lj_total_energy(x_pert, epsilon, sigma)

        x_pert[k] = x[k]
        grad_num[k] = (e_plus - e_minus) / (2.0 * h)
    end
    return grad_num
end

function validate_method_config(::LennardJonesMethod, config::Dict{String, Any}, structure::Structure)::Tuple{Vector{String}, Vector{String}}
    errors = String[]
    warnings = String[]

    if length(structure.atoms) < 2
        push!(errors, "Lennard-Jones potential requires at least 2 atoms.")
    end

    eps = get(config, "epsilon", 1.0)
    if !(eps isa Real) || eps <= 0.0
        push!(errors, "Parameter 'epsilon' must be a positive number (got $eps).")
    end

    sig = get(config, "sigma", 3.0)
    if !(sig isa Real) || sig <= 0.0
        push!(errors, "Parameter 'sigma' must be a positive number (got $sig).")
    end

    max_iter = get(config, "max_iterations", 200)
    if !(max_iter isa Integer) || max_iter < 1
        push!(errors, "Parameter 'max_iterations' must be a positive integer (got $max_iter).")
    end

    return (errors, warnings)
end

"""
    optimize_geometry(structure::Structure, config::Dict{String, Any};
                      cancel_token::Base.Threads.Atomic{Bool}=Base.Threads.Atomic{Bool}(false),
                      progress_callback::Function=(iter, energy, gnorm) -> nothing) -> Dict{String, Any}

Runs geometry optimization using Optim.jl with analytical gradients.
Honors cooperative cancellation.
"""
function optimize_geometry(structure::Structure, config::Dict{String, Any};
                           cancel_token::Base.Threads.Atomic{Bool}=Base.Threads.Atomic{Bool}(false),
                           progress_callback::Function=(iter, energy, gnorm) -> nothing)::Dict{String, Any}
    epsilon = Float64(get(config, "epsilon", 1.65)) # kJ/mol
    sigma   = Float64(get(config, "sigma", 3.4))    # Angstrom
    g_tol   = Float64(get(config, "g_tol", 1e-4))
    f_tol   = Float64(get(config, "f_tol", 1e-6))
    max_iter = Int(get(config, "max_iterations", 200))
    algo_str = lowercase(get(config, "algorithm", "bfgs"))

    optimizer = if algo_str == "lbfgs"
        LBFGS()
    elseif algo_str == "cg" || algo_str == "conjugate_gradient"
        ConjugateGradient()
    elseif algo_str == "gradient_descent"
        GradientDescent()
    else
        BFGS()
    end

    x0 = coords_to_vector(structure.atoms)
    initial_energy = lj_total_energy(x0, epsilon, sigma)

    # Iteration tracking
    history = Vector{NamedTuple{(:iteration, :energy, :gradient_norm), Tuple{Int, Float64, Float64}}}()
    push!(history, (iteration=0, energy=initial_energy, gradient_norm=norm(finite_difference_gradient(x0, epsilon, sigma))))

    f(x) = lj_total_energy(x, epsilon, sigma)
    g!(storage, x) = lj_total_gradient!(storage, x, epsilon, sigma)

    opt_state = :running
    term_reason = "in_progress"

    # Custom callback to capture progress and support cooperative cancellation
    callback = function(os)
        if cancel_token[]
            term_reason = "cancelled_by_user"
            return true # Stop optimization
        end
        iter = length(history)
        val = hasproperty(os, :f_x) ? Float64(os.f_x) : (hasproperty(os, :value) ? Float64(os.value) : 0.0)
        gn = hasproperty(os, :g_x) ? norm(os.g_x) : (hasproperty(os, :g_norm) ? Float64(os.g_norm) : 0.0)
        push!(history, (iteration=iter, energy=val, gradient_norm=gn))
        progress_callback(iter, val, gn)
        return false # Continue
    end

    res = Optim.optimize(f, g!, x0, optimizer,
                         Optim.Options(g_tol=g_tol, f_reltol=f_tol, f_abstol=f_tol, iterations=max_iter,
                                       callback=callback, show_trace=false))

    x_final = Optim.minimizer(res)
    final_energy = Optim.minimum(res)
    grad_final = similar(x_final)
    lj_total_gradient!(grad_final, x_final, epsilon, sigma)
    final_gnorm = norm(grad_final)
    n_iters = Optim.iterations(res)

    converged = Optim.converged(res) && !cancel_token[]

    termination_status = if cancel_token[]
        "cancelled"
    elseif converged
        "converged"
    elseif Optim.iteration_limit_reached(res)
        "stopped_max_iterations"
    else
        "failed"
    end

    # Build updated atoms
    new_coords = vector_to_coords(x_final)
    new_atoms = Vector{Atom}(undef, length(structure.atoms))
    for (i, a) in enumerate(structure.atoms)
        new_atoms[i] = Atom(a.index, a.symbol, a.atomic_number,
                            new_coords[i][1], new_coords[i][2], new_coords[i][3],
                            a.mass, a.formal_charge)
    end

    return Dict{String, Any}(
        "converged" => converged,
        "termination_status" => termination_status,
        "initial_energy" => initial_energy,
        "final_energy" => final_energy,
        "gradient_norm" => final_gnorm,
        "iterations" => n_iters,
        "history" => history,
        "optimized_atoms" => new_atoms
    )
end

function execute_method(::LennardJonesMethod, config::Dict{String, Any}, structure::Structure,
                        cancel_token::Base.Threads.Atomic{Bool},
                        progress_callback::Function)::Dict{String, Any}
    optimize_geometry(structure, config; cancel_token=cancel_token, progress_callback=progress_callback)
end

end # module MolecularMechanics
