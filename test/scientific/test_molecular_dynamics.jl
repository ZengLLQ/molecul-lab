using Test
using MolecuLab

@testset "Molecular Dynamics: Velocity-Verlet & Energy Conservation" begin
    # 3-atom argon cluster
    argon_cluster = [
        Atom(1, "Ar", 18, 0.0, 0.0, 0.0, 39.95),
        Atom(2, "Ar", 18, 3.8, 0.0, 0.0, 39.95),
        Atom(3, "Ar", 18, 1.9, 3.3, 0.0, 39.95)
    ]
    struct_cluster = Structure("s-md-01", "m-md-01", "Ar3 Cluster", argon_cluster)

    config_md = Dict{String, Any}(
        "timestep_ps" => 0.001, # 1 fs
        "steps" => 200,
        "sample_interval" => 10,
        "temperature_k" => 150.0,
        "epsilon" => 1.0,
        "sigma" => 3.4,
        "random_seed" => 1234
    )

    md_res = run_md_simulation(struct_cluster, config_md)
    @test md_res["status"] == "completed"
    @test md_res["total_steps_executed"] == 200
    @test length(md_res["trajectory"]) > 10

    e_init = md_res["initial_total_energy"]
    e_final = md_res["final_total_energy"]
    drift_rel = abs(e_final - e_init) / max(abs(e_init), 1e-6)

    # Symplectic Verlet preserves total energy with minimal drift in NVE
    @test drift_rel < 0.02 # < 2% drift over 200 fs in microcanonical ensemble

    # Test cooperative cancellation
    cancel_token = Base.Threads.Atomic{Bool}(true) # Already cancelled
    md_cancel = run_md_simulation(struct_cluster, config_md; cancel_token=cancel_token)
    @test md_cancel["status"] == "cancelled"
end
