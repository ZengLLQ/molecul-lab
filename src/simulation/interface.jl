"""
Abstract interfaces and contracts for computational chemistry methods.
"""
module SimulationInterface

using ..Structures: Structure

export AbstractChemistryMethod, AbstractExperimentConfig, AbstractExperimentResult,
       validate_method_config, execute_method, method_identifier, method_version

abstract type AbstractChemistryMethod end
abstract type AbstractExperimentConfig end
abstract type AbstractExperimentResult end

"""
    method_identifier(m::AbstractChemistryMethod) -> String
"""
function method_identifier end

"""
    method_version(m::AbstractChemistryMethod) -> String
"""
function method_version end

"""
    validate_method_config(method::AbstractChemistryMethod, config::Dict{String, Any}, structure::Structure) -> Tuple{Vector{String}, Vector{String}}

Validates configuration parameters against method requirements.
Returns `(errors, warnings)`.
"""
function validate_method_config end

"""
    execute_method(method::AbstractChemistryMethod, config::Dict{String, Any}, structure::Structure,
                   cancel_token::Base.Threads.Atomic{Bool},
                   progress_callback::Function) -> Dict{String, Any}

Executes the calculation, calling `progress_callback` with periodic status events.
Returns result dictionary containing energies, final coordinates, iterations, and convergence flag.
"""
function execute_method end

end # module SimulationInterface
