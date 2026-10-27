using Test
using MolecuLab

@testset "Integration: Project Lifecycle & SQLite Persistence" begin
    mktempdir() do tmp_dir
        proj_root = joinpath(tmp_dir, "TestResearchProject")

        # 1. Create project
        proj = create_project("Test Research Project", proj_root)
        @test isdir(proj_root)
        @test isfile(joinpath(proj_root, "project.toml"))
        @test isfile(joinpath(proj_root, "database", "project.sqlite"))

        # 2. Import structure fixtures
        fixtures_dir = joinpath(@__DIR__, "..", "fixtures")
        water_xyz = joinpath(fixtures_dir, "water_monomer.xyz")
        ethanol_mol = joinpath(fixtures_dir, "ethanol.mol")
        ala_pdb = joinpath(fixtures_dir, "alanine_dipeptide.pdb")

        mol_water, struct_water = import_structure_to_project(proj, water_xyz; molecule_name="Water")
        @test mol_water.formula == "H2O"
        @test length(struct_water.atoms) == 3

        mol_eth, struct_eth = import_structure_to_project(proj, ethanol_mol; molecule_name="Ethanol")
        @test mol_eth.formula == "C2H6O"
        @test length(struct_eth.atoms) == 9

        mol_ala, struct_ala = import_structure_to_project(proj, ala_pdb; molecule_name="Alanine Dipeptide")
        @test length(struct_ala.atoms) == 12

        # 3. Create experiment & execute job
        dimer_xyz = joinpath(fixtures_dir, "argon_dimer.xyz")
        mol_dimer, struct_dimer = import_structure_to_project(proj, dimer_xyz; molecule_name="Argon Dimer")

        cfg = Dict{String, Any}(
            "epsilon" => 1.0,
            "sigma" => 3.4,
            "g_tol" => 1e-4,
            "f_tol" => 1e-6,
            "max_iterations" => 100,
            "algorithm" => "bfgs"
        )
        exp = create_experiment(proj, struct_dimer, "lennard_jones_optimization", cfg)
        @test exp.status == "draft"

        job_mgr = MolecuLab.Jobs.JobManager(64)
        job = execute_experiment_job(proj, exp, struct_dimer, job_mgr)
        @test !isnothing(job)

        # Wait for worker thread to complete calculation
        wait(job_mgr.handles[job.id].task)

        # 4. Verify result persistence
        res = get_experiment_result(proj, exp.id)
        @test !isnothing(res)
        @test res.converged == true
        @test res.final_energy ≈ -1.0 atol=1e-3
        @test !isempty(res.artifacts)

        # 5. Reopen project and verify persistence
        reopened = open_project(proj_root)
        @test reopened.id == proj.id
        @test reopened.name == proj.name

        mols = get_project_molecules(reopened)
        @test length(mols) == 4

        exps = get_project_experiments(reopened)
        @test length(exps) == 1
        @test first(exps).id == exp.id

        # Close project DB to release file locks on Windows
        close_project!(reopened)
        close_project!(proj)
        GC.gc()
    end
end
