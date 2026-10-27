# scripts/dev.jl — MolecuLab Development & Quickstart Launcher

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..")))

println(">>> Starting MolecuLab Development Environment...")

using MolecuLab
using MolecuLab.ProjectService
using MolecuLab.StructureService

# Establish default development workspace directory
workspace_dir = normpath(joinpath(@__DIR__, "..", "workspace"))
isdir(workspace_dir) || mkpath(workspace_dir)

sample_project_path = joinpath(workspace_dir, "Demo_Workspace")

if !isdir(sample_project_path)
    println(">>> Initializing default demo project at: $sample_project_path")
    proj = ProjectService.create_project("MolecuLab Demo", sample_project_path)
    
    # Pre-populate sample structures from test fixtures
    fixtures_dir = normpath(joinpath(@__DIR__, "..", "test", "fixtures"))
    
    water_path = joinpath(fixtures_dir, "water_monomer.xyz")
    if isfile(water_path)
        println(">>> Importing sample: Water Monomer (H2O)...")
        StructureService.import_structure_to_project(proj, water_path; molecule_name="Water Monomer")
    end
    
    argon_path = joinpath(fixtures_dir, "argon_dimer.xyz")
    if isfile(argon_path)
        println(">>> Importing sample: Argon Dimer (Ar2)...")
        StructureService.import_structure_to_project(proj, argon_path; molecule_name="Argon Dimer")
    end
    
    ethanol_path = joinpath(fixtures_dir, "ethanol.mol")
    if isfile(ethanol_path)
        println(">>> Importing sample: Ethanol (C2H5OH)...")
        StructureService.import_structure_to_project(proj, ethanol_path; molecule_name="Ethanol")
    end
else
    println(">>> Found existing demo project at: $sample_project_path")
end

println(">>> Launching MolecuLab Desktop Application...")
# Launch the Gtk4 desktop application with the sample project
MolecuLab.launch_app(sample_project_path)
