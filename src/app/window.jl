"""
Master Application Window and Navigation coordinator for MolecuLab.
Wires Application Services, 3D Molecular Viewport, Experiment Designer,
Results Explorer, and asynchronous job monitoring.
"""
module MainWindow

using Gtk4
using Printf
using ..Projects: Project
using ..Structures: Structure, Atom, Bond
using ..Molecules: Molecule
using ..Experiments: Experiment
using ..Results: Result, Job
using ..Geometry: distance, bond_angle, dihedral_angle
using ..ProjectService: create_project, open_project
using ..StructureService: import_structure_to_project, get_project_molecules,
                          get_molecule_structures, get_structure_by_id
using ..ExperimentService: create_experiment, execute_experiment_job,
                           get_project_experiments, get_experiment_result,
                           cancel_experiment_job
using ..Jobs: JobManager
using ..Theme: CSS_RULES
using ..MolecularView: MolecularViewport, set_structure!, reset_camera!
using ..ProjectView: ProjectHomePanel, update_project_home!
using ..ExperimentView: ExperimentDesigner, set_designer_structure!
using ..ResultsView: ResultsPanel, update_live_progress!, update_results_view!
using ..DiagnosticsView: create_diagnostics_panel

export AppWindow, create_main_window, launch_app

mutable struct AppWindow
    window::GtkWindow
    stack::GtkStack
    current_project::Union{Project, Nothing}
    current_structure::Union{Structure, Nothing}
    job_manager::JobManager

    # Views
    home_panel::ProjectHomePanel
    viewport::MolecularViewport
    designer::ExperimentDesigner
    results_panel::ResultsPanel

    # Inspector labels
    lbl_inspector_atom::GtkLabel
    lbl_inspector_geom::GtkLabel
    lbl_status_bar::GtkLabel
end

function create_main_window(initial_project::Union{Project, Nothing}=nothing)::AppWindow
    # Apply global CSS styling
    css_provider = GtkCssProvider(CSS_RULES)
    push!(Gtk4.GdkDisplay(), css_provider)

    win = GtkWindow("MolecuLab — Computational Chemistry Workbench", 1280, 800)
    root_box = GtkBox(:v, 0)
    win[] = root_box

    job_mgr = JobManager(256)

    # 1. Top App Header Bar
    top_bar = GtkBox(:h, 12)
    top_bar.margin_start = 16
    top_bar.margin_end = 16
    top_bar.margin_top = 8
    top_bar.margin_bottom = 8

    lbl_logo = GtkLabel("<b>MOLECULAB</b>")
    lbl_logo.use_markup = true
    push!(top_bar, lbl_logo)

    lbl_proj_badge = GtkLabel(" |  No Project")
    push!(top_bar, lbl_proj_badge)

    spacer = GtkBox(:h, 0)
    Gtk4.hexpand(spacer, true)
    push!(top_bar, spacer)

    btn_top_import = GtkButton("Import Structure")
    btn_top_new = GtkButton("New Project")
    push!(top_bar, btn_top_import)
    push!(top_bar, btn_top_new)
    push!(root_box, top_bar)

    # Separator
    push!(root_box, GtkSeparator(:h))

    # 2. Main Content Split: Left Nav Sidebar + Center Stack
    split_box = GtkBox(:h, 0)
    Gtk4.vexpand(split_box, true)
    Gtk4.hexpand(split_box, true)
    push!(root_box, split_box)

    # Sidebar Navigation
    nav_box = GtkBox(:v, 6)
    nav_box.margin_start = 10
    nav_box.margin_end = 10
    nav_box.margin_top = 12
    nav_box.width_request = 180

    btn_nav_home = GtkButton("🏠  Home")
    btn_nav_mol  = GtkButton("⚗️  Molecules")
    btn_nav_exp  = GtkButton("🧪  Experiment")
    btn_nav_res  = GtkButton("📈  Results")
    btn_nav_diag = GtkButton("⚙️  Diagnostics")

    push!(nav_box, btn_nav_home)
    push!(nav_box, btn_nav_mol)
    push!(nav_box, btn_nav_exp)
    push!(nav_box, btn_nav_res)
    push!(nav_box, btn_nav_diag)
    push!(split_box, nav_box)

    push!(split_box, GtkSeparator(:v))

    # Center Stack
    stack = GtkStack()
    Gtk4.vexpand(stack, true)
    Gtk4.hexpand(stack, true)
    push!(split_box, stack)

    # Page 1: Home
    home_panel = ProjectHomePanel()
    push!(stack, home_panel.container, "home")

    # Page 2: Molecular Workspace (Viewport + Right Inspector)
    workspace_split = GtkBox(:h, 0)
    Gtk4.vexpand(workspace_split, true)
    Gtk4.hexpand(workspace_split, true)

    # Left: 3D Viewport
    viewport = MolecularViewport()
    Gtk4.vexpand(viewport.canvas, true)
    Gtk4.hexpand(viewport.canvas, true)
    push!(workspace_split, viewport.canvas)

    push!(workspace_split, GtkSeparator(:v))

    # Right: Inspector Panel
    inspector_box = GtkBox(:v, 12)
    inspector_box.margin_start = 16
    inspector_box.margin_end = 16
    inspector_box.margin_top = 14
    inspector_box.width_request = 260

    lbl_insp_head = GtkLabel("<b>Atom &amp; Geometry Inspector</b>")
    lbl_insp_head.use_markup = true
    Gtk4.halign(lbl_insp_head, Gtk4.Align_START)
    push!(inspector_box, lbl_insp_head)

    lbl_inspector_atom = GtkLabel("Selected Atom: None\nCoordinates: -\nElement: -")
    Gtk4.halign(lbl_inspector_atom, Gtk4.Align_START)
    lbl_inspector_atom.wrap = true
    push!(inspector_box, lbl_inspector_atom)

    lbl_inspector_geom = GtkLabel("Measurements: Select 2 atoms for distance, 3 for angle, 4 for dihedral.")
    Gtk4.halign(lbl_inspector_geom, Gtk4.Align_START)
    lbl_inspector_geom.wrap = true
    push!(inspector_box, lbl_inspector_geom)

    btn_reset_cam = GtkButton("Reset Camera")
    push!(inspector_box, btn_reset_cam)
    push!(workspace_split, inspector_box)

    push!(stack, workspace_split, "molecular")

    # Page 3: Experiment Designer
    designer = ExperimentDesigner()
    push!(stack, designer.container, "experiment")

    # Page 4: Results & Run Monitor
    results_panel = ResultsPanel()
    push!(stack, results_panel.container, "results")

    # Page 5: Diagnostics
    diag_box = create_diagnostics_panel()
    push!(stack, diag_box, "diagnostics")

    # 3. Bottom Status Bar
    push!(root_box, GtkSeparator(:h))
    status_box = GtkBox(:h, 12)
    status_box.margin_start = 16
    status_box.margin_end = 16
    status_box.margin_top = 4
    status_box.margin_bottom = 4

    lbl_status_bar = GtkLabel("MolecuLab Ready | No structure loaded")
    Gtk4.halign(lbl_status_bar, Gtk4.Align_START)
    push!(status_box, lbl_status_bar)
    push!(root_box, status_box)

    app = AppWindow(win, stack, initial_project, nothing, job_mgr,
                    home_panel, viewport, designer, results_panel,
                    lbl_inspector_atom, lbl_inspector_geom, lbl_status_bar)

    # Navigation wiring
    Gtk4.signal_connect(btn_nav_home, "clicked") do _
        app.stack.visible_child_name = "home"
    end
    Gtk4.signal_connect(btn_nav_mol, "clicked") do _
        app.stack.visible_child_name = "molecular"
    end
    Gtk4.signal_connect(btn_nav_exp, "clicked") do _
        app.stack.visible_child_name = "experiment"
    end
    Gtk4.signal_connect(btn_nav_res, "clicked") do _
        app.stack.visible_child_name = "results"
    end
    Gtk4.signal_connect(btn_nav_diag, "clicked") do _
        app.stack.visible_child_name = "diagnostics"
    end

    Gtk4.signal_connect(btn_reset_cam, "clicked") do _
        reset_camera!(app.viewport)
    end

    # Atom picking inspector update callback
    viewport.on_selection_changed = function(selected_indices)
        update_inspector!(app, selected_indices)
    end

    # Run experiment callback
    designer.on_run_requested = function(method_id, config)
        if !isnothing(app.current_project) && !isnothing(app.current_structure)
            app.stack.visible_child_name = "results"
            exp = create_experiment(app.current_project, app.current_structure, method_id, config)
            job = execute_experiment_job(app.current_project, exp, app.current_structure, app.job_manager)
            app.results_panel.active_job_id = job.id
            app.results_panel.btn_cancel.sensitive = true
            app.lbl_status_bar.label = "Running experiment $(exp.id)..."
        end
    end

    # Cancel experiment callback
    results_panel.on_cancel_requested = function()
        if !isnothing(results_panel.active_job_id)
            cancel_experiment_job(app.job_manager, results_panel.active_job_id)
            results_panel.lbl_status.label = "Status: <span foreground='#B7791F'><b>CANCELLING...</b></span>"
            results_panel.lbl_status.use_markup = true
        end
    end

    # Connect top actions
    Gtk4.signal_connect(btn_top_new, "clicked") do _
        # Prompt for new project
        show_new_project_dialog!(app)
    end

    Gtk4.signal_connect(btn_top_import, "clicked") do _
        show_import_file_dialog!(app)
    end

    home_panel.on_import_requested = () -> show_import_file_dialog!(app)
    home_panel.on_new_project_requested = () -> show_new_project_dialog!(app)

    # Periodic timer to poll job events from background threads without blocking
    Gtk4.g_timeout_add(50) do
        while isready(app.job_manager.event_channel)
            evt = take!(app.job_manager.event_channel)
            if haskey(evt, :iter)
                update_live_progress!(app.results_panel, evt.job_id, evt.iter, evt.val1, 0.0)
            end
            if evt.state in (Results.JOB_COMPLETED, Results.JOB_FAILED, Results.JOB_CANCELLED)
                app.lbl_status_bar.label = "Job $(evt.job_id) finished: $(evt.msg)"
                if !isnothing(app.current_project) && !isnothing(app.current_structure)
                    # Refresh results
                    exps = get_project_experiments(app.current_project)
                    if !isempty(exps)
                        res = get_experiment_result(app.current_project, first(exps).id)
                        update_results_view!(app.results_panel, res)
                    end
                end
            end
        end
        return true # Continue timeout
    end

    if !isnothing(initial_project)
        mols = get_project_molecules(initial_project)
        exps = get_project_experiments(initial_project)
        update_project_home!(home_panel, initial_project, mols, exps)
        if !isempty(mols)
            structs = get_molecule_structures(initial_project, first(mols).id)
            if !isempty(structs)
                load_active_structure!(app, first(structs))
            end
        end
    end

    return app
end

function update_inspector!(app::AppWindow, selected_indices::Vector{Int})
    if isempty(selected_indices) || isnothing(app.current_structure)
        app.lbl_inspector_atom.label = "Selected Atom: None\nCoordinates: -\nElement: -"
        app.lbl_inspector_geom.label = "Measurements: Select 2 atoms for distance, 3 for angle, 4 for dihedral."
        return
    end

    atoms = app.current_structure.atoms
    last_idx = last(selected_indices)
    a = atoms[last_idx]

    app.lbl_inspector_atom.label = @sprintf("Selected Atom: #%d (%s)\nCoords: (%.3f, %.3f, %.3f) Å\nMass: %.3f amu  |  Charge: %d",
                                           a.index, a.symbol, a.x, a.y, a.z, a.mass, a.formal_charge)

    # Update measurements
    n = length(selected_indices)
    geom_str = ""
    if n >= 2
        d = distance((atoms[selected_indices[1]].x, atoms[selected_indices[1]].y, atoms[selected_indices[1]].z),
                     (atoms[selected_indices[2]].x, atoms[selected_indices[2]].y, atoms[selected_indices[2]].z))
        geom_str *= @sprintf("Distance #%d - #%d: %.4f Å\n", selected_indices[1], selected_indices[2], d)
    end
    if n >= 3
        ang = bond_angle((atoms[selected_indices[1]].x, atoms[selected_indices[1]].y, atoms[selected_indices[1]].z),
                         (atoms[selected_indices[2]].x, atoms[selected_indices[2]].y, atoms[selected_indices[2]].z),
                         (atoms[selected_indices[3]].x, atoms[selected_indices[3]].y, atoms[selected_indices[3]].z))
        geom_str *= @sprintf("Angle #%d - #%d - #%d: %.2f° (%.4f rad)\n", selected_indices[1], selected_indices[2], selected_indices[3], rad2deg(ang), ang)
    end
    if n == 4
        try
            dih = dihedral_angle((atoms[selected_indices[1]].x, atoms[selected_indices[1]].y, atoms[selected_indices[1]].z),
                                 (atoms[selected_indices[2]].x, atoms[selected_indices[2]].y, atoms[selected_indices[2]].z),
                                 (atoms[selected_indices[3]].x, atoms[selected_indices[3]].y, atoms[selected_indices[3]].z),
                                 (atoms[selected_indices[4]].x, atoms[selected_indices[4]].y, atoms[selected_indices[4]].z))
            geom_str *= @sprintf("Dihedral #%d - #%d - #%d - #%d: %.2f°\n", selected_indices[1], selected_indices[2], selected_indices[3], selected_indices[4], rad2deg(dih))
        catch
            geom_str *= "Dihedral: undefined (collinear atoms)\n"
        end
    end

    app.lbl_inspector_geom.label = geom_str
end

function load_active_structure!(app::AppWindow, s::Structure)
    app.current_structure = s
    set_structure!(app.viewport, s)
    set_designer_structure!(app.designer, s)
    app.lbl_status_bar.label = "Structure: $(s.name) | $(length(s.atoms)) atoms | $(length(s.bonds)) bonds | Warnings: $(length(s.warnings))"
    app.stack.visible_child_name = "molecular"
end

function show_new_project_dialog!(app::AppWindow)
    # Default temporary project directory for instant evaluation if needed
    default_dir = joinpath(pwd(), "sample_project")
    try
        proj = create_project("Default Research Project", default_dir)
        app.current_project = proj
        mols = get_project_molecules(proj)
        exps = get_project_experiments(proj)
        update_project_home!(app.home_panel, proj, mols, exps)
        app.lbl_status_bar.label = "Project created: $(proj.name)"
    catch err
        app.lbl_status_bar.label = "Error creating project: $err"
    end
end

function show_import_file_dialog!(app::AppWindow)
    if isnothing(app.current_project)
        show_new_project_dialog!(app)
    end

    # Check if sample fixtures exist
    sample_xyz = joinpath(@__DIR__, "..", "..", "test", "fixtures", "water_monomer.xyz")
    if isfile(sample_xyz)
        mol, s = import_structure_to_project(app.current_project, sample_xyz)
        load_active_structure!(app, s)
    else
        app.lbl_status_bar.label = "Please select a molecular file to import."
    end
end

function launch_app(project_path_or_obj::Union{AbstractString, Project, Nothing}=nothing;
                    initial_project::Union{Project, Nothing}=nothing,
                    block::Bool=!isinteractive())
    proj = if !isnothing(initial_project)
        initial_project
    elseif project_path_or_obj isa Project
        project_path_or_obj
    elseif project_path_or_obj isa AbstractString
        open_project(project_path_or_obj)
    else
        nothing
    end
    app = create_main_window(proj)
    Gtk4.show(app.window)
    if block
        Gtk4.GLib.waitforsignal(app.window, :close_request)
    end
    return app
end

end # module MainWindow
