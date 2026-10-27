"""
Experiment Designer UI panel.
Guides users through method selection, parameter configuration, live scientific validation,
and calculation dispatch.
"""
module ExperimentView

using Gtk4
using ..Structures: Structure
using ..SimulationInterface: validate_method_config
using ..MolecularMechanics: LennardJonesMethod
using ..MolecularDynamics: MolecularDynamicsMethod

export ExperimentDesigner, set_designer_structure!

mutable struct ExperimentDesigner
    container::GtkBox
    active_structure::Union{Structure, Nothing}
    combo_method::GtkDropDown
    entry_epsilon::GtkEntry
    entry_sigma::GtkEntry
    entry_gtol::GtkEntry
    entry_ftol::GtkEntry
    entry_max_iter::GtkEntry
    combo_optimizer::GtkDropDown
    lbl_validation::GtkLabel
    lbl_method_info::GtkLabel
    btn_run::GtkButton
    on_run_requested::Function

    function ExperimentDesigner(; on_run_requested::Function=(method_id, config) -> nothing)
        box = GtkBox(:v, 14)
        box.margin_start = 24
        box.margin_end = 24
        box.margin_top = 16
        box.margin_bottom = 16

        # Header
        lbl_head = GtkLabel("<b>Experiment Designer &amp; Calculation Setup</b>")
        lbl_head.use_markup = true
        Gtk4.halign(lbl_head, Gtk4.Align_START)
        push!(box, lbl_head)

        grid = GtkGrid()
        grid.column_spacing = 14
        grid.row_spacing = 10

        # 1. Method selector
        grid[1, 1] = GtkLabel("Method:")
        methods_list = ["Lennard-Jones Geometry Optimization", "Molecular Dynamics (Velocity-Verlet)"]
        combo_method = GtkDropDown(methods_list)
        grid[2, 1] = combo_method

        # 2. Parameters
        grid[1, 2] = GtkLabel("Well depth ε (kJ/mol):")
        entry_epsilon = GtkEntry()
        entry_epsilon.text = "1.65"
        grid[2, 2] = entry_epsilon

        grid[1, 3] = GtkLabel("Collision diameter σ (Å):")
        entry_sigma = GtkEntry()
        entry_sigma.text = "3.40"
        grid[2, 3] = entry_sigma

        grid[1, 4] = GtkLabel("Optimizer Algorithm:")
        combo_optimizer = GtkDropDown(["BFGS (Quasi-Newton)", "L-BFGS (Low Memory)", "Conjugate Gradient"])
        grid[2, 4] = combo_optimizer

        grid[1, 5] = GtkLabel("Gradient Tol ||∇E||:")
        entry_gtol = GtkEntry()
        entry_gtol.text = "1e-4"
        grid[2, 5] = entry_gtol

        grid[1, 6] = GtkLabel("Energy Tol |ΔE|:")
        entry_ftol = GtkEntry()
        entry_ftol.text = "1e-6"
        grid[2, 6] = entry_ftol

        grid[1, 7] = GtkLabel("Max Iterations:")
        entry_max_iter = GtkEntry()
        entry_max_iter.text = "200"
        grid[2, 7] = entry_max_iter

        push!(box, grid)

        # Method Information / Scientific Assumptions
        lbl_method_info = GtkLabel("<b>Assumptions:</b> Pairwise 12-6 non-bonded dispersion-repulsion model. Suitable for neutral van der Waals clusters. Does not model covalent chemical bond breakage or partial charges.")
        lbl_method_info.use_markup = true
        lbl_method_info.wrap = true
        Gtk4.halign(lbl_method_info, Gtk4.Align_START)
        push!(box, lbl_method_info)

        # Validation feedback box
        lbl_validation = GtkLabel("<span foreground='#666666'>Ready to configure calculation.</span>")
        lbl_validation.use_markup = true
        Gtk4.halign(lbl_validation, Gtk4.Align_START)
        push!(box, lbl_validation)

        # Actions
        btn_box = GtkBox(:h, 12)
        btn_validate = GtkButton("Validate Configuration")
        btn_run = GtkButton("Run Experiment")
        btn_run.sensitive = false
        push!(btn_box, btn_validate)
        push!(btn_box, btn_run)
        push!(box, btn_box)

        designer = new(box, nothing, combo_method, entry_epsilon, entry_sigma,
                       entry_gtol, entry_ftol, entry_max_iter, combo_optimizer,
                       lbl_validation, lbl_method_info, btn_run, on_run_requested)

        Gtk4.signal_connect(btn_validate, "clicked") do _
            validate_form!(designer)
        end

        Gtk4.signal_connect(btn_run, "clicked") do _
            if validate_form!(designer)
                cfg = extract_config(designer)
                method_id = combo_method.selected == 0 ? "lennard_jones_optimization" : "molecular_dynamics_velocity_verlet"
                designer.on_run_requested(method_id, cfg)
            end
        end

        return designer
    end
end

function set_designer_structure!(d::ExperimentDesigner, s::Union{Structure, Nothing})
    d.active_structure = s
    validate_form!(d)
end

function extract_config(d::ExperimentDesigner)::Dict{String, Any}
    algo_idx = d.combo_optimizer.selected
    algo_str = algo_idx == 0 ? "bfgs" : (algo_idx == 1 ? "lbfgs" : "cg")

    return Dict{String, Any}(
        "epsilon" => tryparse(Float64, d.entry_epsilon.text) !== nothing ? parse(Float64, d.entry_epsilon.text) : 1.65,
        "sigma" => tryparse(Float64, d.entry_sigma.text) !== nothing ? parse(Float64, d.entry_sigma.text) : 3.40,
        "g_tol" => tryparse(Float64, d.entry_gtol.text) !== nothing ? parse(Float64, d.entry_gtol.text) : 1e-4,
        "f_tol" => tryparse(Float64, d.entry_ftol.text) !== nothing ? parse(Float64, d.entry_ftol.text) : 1e-6,
        "max_iterations" => tryparse(Int, d.entry_max_iter.text) !== nothing ? parse(Int, d.entry_max_iter.text) : 200,
        "algorithm" => algo_str
    )
end

function validate_form!(d::ExperimentDesigner)::Bool
    if isnothing(d.active_structure) || isempty(d.active_structure.atoms)
        d.lbl_validation.label = "<span foreground='#B83A3A'><b>Error:</b> No active structure selected in workspace.</span>"
        d.lbl_validation.use_markup = true
        d.btn_run.sensitive = false
        return false
    end

    cfg = extract_config(d)
    method = d.combo_method.selected == 0 ? LennardJonesMethod() : MolecularDynamicsMethod()
    errors, warnings = validate_method_config(method, cfg, d.active_structure)

    if !isempty(errors)
        d.lbl_validation.label = "<span foreground='#B83A3A'><b>Invalid:</b> " * join(errors, "; ") * "</span>"
        d.lbl_validation.use_markup = true
        d.btn_run.sensitive = false
        return false
    elseif !isempty(warnings)
        d.lbl_validation.label = "<span foreground='#B7791F'><b>Warnings:</b> " * join(warnings, "; ") * "</span>"
        d.lbl_validation.use_markup = true
        d.btn_run.sensitive = true
        return true
    else
        d.lbl_validation.label = "<span foreground='#2E7D5B'><b>Ready:</b> Configuration valid. Ready to run calculation.</span>"
        d.lbl_validation.use_markup = true
        d.btn_run.sensitive = true
        return true
    end
end

end # module ExperimentView
