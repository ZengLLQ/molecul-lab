"""
    MolecuLab — Computational Chemistry Workbench
    Julia-first | Local-first | Scientifically Honest
"""
module MolecuLab

# 1. Domain Layer
include("domain/structures.jl")
include("domain/molecules.jl")
include("domain/projects.jl")
include("domain/experiments.jl")
include("domain/results.jl")

using .Structures
using .Molecules
using .Projects
using .Experiments
using .Results

# 2. Chemistry Core Layer
include("chemistry/descriptors.jl")
include("chemistry/geometry.jl")
include("chemistry/validation.jl")

using .Descriptors
using .Geometry
using .Validation

# 3. Storage Layer
include("storage/artifacts.jl")
include("storage/database.jl")

using .Artifacts
using .Database

# 4. Diagnostics Layer
include("diagnostics/hardware.jl")
include("diagnostics/environment.jl")

using .Hardware
using .Environment

# 5. IO Layer
include("io/importers.jl")
include("io/exporters.jl")

using .Importers
using .Exporters

# 6. Simulation Layer
include("simulation/interface.jl")
include("simulation/molecular_mechanics.jl")
include("simulation/molecular_dynamics.jl")
include("simulation/jobs.jl")

using .SimulationInterface
using .MolecularMechanics
using .MolecularDynamics
using .Jobs

# 7. Application Services Layer
include("application/project_service.jl")
include("application/structure_service.jl")
include("application/experiment_service.jl")

using .ProjectService
using .StructureService
using .ExperimentService

# 8. Presentation Layer (Desktop UI)
include("ui/theme.jl")
include("ui/molecular_view.jl")
include("ui/project_view.jl")
include("ui/experiment_view.jl")
include("ui/results_view.jl")
include("ui/diagnostics_view.jl")
include("app/window.jl")

using .Theme
using .MolecularView
using .ProjectView
using .ExperimentView
using .ResultsView
using .DiagnosticsView
using .MainWindow

# Re-exports of top-level APIs
export Atom, Bond, Structure, count_atoms, count_bonds,
       Molecule, Project, Experiment, Job, JobState, Result, Artifact,
       distance, bond_angle, dihedral_angle, center_of_mass, bounding_box, radius_of_gyration,
       molecular_formula, molecular_weight, heavy_atom_count, formal_charge_sum,
       validate_structure,
       import_xyz, import_mol, import_pdb, import_structure_file,
       export_xyz, export_mol, export_structure,
       lj_pair_potential, lj_pair_force, lj_total_energy, lj_total_gradient!,
       finite_difference_gradient, optimize_geometry, run_md_simulation,
       create_project, open_project, close_project!,
       import_structure_to_project, add_structure_to_molecule,
       get_project_molecules, get_molecule_structures, get_structure_by_id,
       create_experiment, execute_experiment_job, cancel_experiment_job,
       get_project_experiments, get_experiment_result,
       probe_hardware, get_runtime_manifest,
       launch_app

end # module MolecuLab
