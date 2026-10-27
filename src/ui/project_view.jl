"""
Home and Projects management view.
Provides project creation, opening, structure import triggers, and recent jobs overview.
"""
module ProjectView

using Gtk4
using ..Projects: Project
using ..Molecules: Molecule
using ..Experiments: Experiment

export ProjectHomePanel, update_project_home!

mutable struct ProjectHomePanel
    container::GtkBox
    lbl_project_title::GtkLabel
    lbl_project_path::GtkLabel
    lbl_molecules_count::GtkLabel
    lbl_experiments_count::GtkLabel
    btn_import_structure::GtkButton
    btn_new_project::GtkButton
    on_import_requested::Function
    on_new_project_requested::Function

    function ProjectHomePanel(; on_import_requested::Function=() -> nothing,
                                on_new_project_requested::Function=() -> nothing)
        box = GtkBox(:v, 16)
        box.margin_start = 24
        box.margin_end = 24
        box.margin_top = 20
        box.margin_bottom = 20

        # Welcome Card
        lbl_welcome = GtkLabel("<b>MolecuLab Research Workspace</b>")
        lbl_welcome.use_markup = true
        Gtk4.halign(lbl_welcome, Gtk4.Align_START)
        push!(box, lbl_welcome)

        lbl_desc = GtkLabel("Local-first computational chemistry workbench for molecular modeling, geometry optimization, and reproducible experiments.")
        Gtk4.halign(lbl_desc, Gtk4.Align_START)
        lbl_desc.wrap = true
        push!(box, lbl_desc)

        # Project Info Card
        card_proj = GtkBox(:v, 8)
        lbl_project_title = GtkLabel("Project: <b>No Project Loaded</b>")
        lbl_project_title.use_markup = true
        Gtk4.halign(lbl_project_title, Gtk4.Align_START)
        push!(card_proj, lbl_project_title)

        lbl_project_path = GtkLabel("Path: -")
        Gtk4.halign(lbl_project_path, Gtk4.Align_START)
        push!(card_proj, lbl_project_path)

        lbl_molecules_count = GtkLabel("Molecules: 0")
        Gtk4.halign(lbl_molecules_count, Gtk4.Align_START)
        push!(card_proj, lbl_molecules_count)

        lbl_experiments_count = GtkLabel("Experiments: 0")
        Gtk4.halign(lbl_experiments_count, Gtk4.Align_START)
        push!(card_proj, lbl_experiments_count)

        push!(box, card_proj)

        # Quick Actions
        actions_box = GtkBox(:h, 12)
        btn_import_structure = GtkButton("Import Structure (XYZ / MOL / PDB)")
        btn_new_project = GtkButton("New Project")
        push!(actions_box, btn_import_structure)
        push!(actions_box, btn_new_project)
        push!(box, actions_box)

        panel = new(box, lbl_project_title, lbl_project_path,
                    lbl_molecules_count, lbl_experiments_count,
                    btn_import_structure, btn_new_project,
                    on_import_requested, on_new_project_requested)

        Gtk4.signal_connect(btn_import_structure, "clicked") do _
            panel.on_import_requested()
        end

        Gtk4.signal_connect(btn_new_project, "clicked") do _
            panel.on_new_project_requested()
        end

        return panel
    end
end

function update_project_home!(panel::ProjectHomePanel, proj::Union{Project, Nothing},
                              molecules::Vector{Molecule}, experiments::Vector{Experiment})
    if isnothing(proj)
        panel.lbl_project_title.label = "Project: <b>No Project Loaded</b>"
        panel.lbl_project_title.use_markup = true
        panel.lbl_project_path.label = "Path: -"
        panel.lbl_molecules_count.label = "Molecules: 0"
        panel.lbl_experiments_count.label = "Experiments: 0"
        panel.btn_import_structure.sensitive = false
    else
        panel.lbl_project_title.label = "Project: <b>$(proj.name)</b>"
        panel.lbl_project_title.use_markup = true
        panel.lbl_project_path.label = "Path: $(proj.root_path)"
        panel.lbl_molecules_count.label = "Molecules: $(length(molecules))"
        panel.lbl_experiments_count.label = "Experiments: $(length(experiments))"
        panel.btn_import_structure.sensitive = true
    end
end

end # module ProjectView
