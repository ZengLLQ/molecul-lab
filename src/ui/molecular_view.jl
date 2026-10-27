"""
Interactive 3D Molecular Viewport rendered with Cairo on Gtk4 GtkCanvas.
Features real-time 3D rotation, depth sorting, sphere shading, atom picking, and distance/angle measurements.
"""
module MolecularView

using Cairo
using Gtk4
using ..Structures: Structure, Atom, Bond
using ..Geometry: distance, bond_angle, dihedral_angle, center_of_mass
using ..Descriptors: cpk_color_hex, covalent_radius_angstrom
using ..Theme: parse_hex_color

export MolecularViewport, set_structure!, reset_camera!, select_atom!, clear_selection!

mutable struct Camera3D
    rot_x::Float64    # Pitch in radians
    rot_y::Float64    # Yaw in radians
    pan_x::Float64    # Pan offset in pixels
    pan_y::Float64    # Pan offset in pixels
    scale::Float64    # Zoom factor: pixels per Angstrom
    show_labels::Bool
    show_bonds::Bool
    selected_atoms::Vector{Int}

    function Camera3D()
        new(0.3, 0.4, 0.0, 0.0, 45.0, true, true, Int[])
    end
end

mutable struct MolecularViewport
    canvas::GtkCanvas
    structure::Union{Structure, Nothing}
    camera::Camera3D
    is_dragging::Bool
    last_mouse_x::Float64
    last_mouse_y::Float64
    on_selection_changed::Function

    function MolecularViewport(; on_selection_changed::Function=(indices) -> nothing)
        canvas = GtkCanvas()
        vp = new(canvas, nothing, Camera3D(), false, 0.0, 0.0, on_selection_changed)

        # Attach Cairo draw callback
        Gtk4.draw(canvas) do widget
            cr = Gtk4.cairo_context(widget)
            w = Float64(Gtk4.width(widget))
            h = Float64(Gtk4.height(widget))
            render_viewport!(vp, cr, w, h)
        end

        # Attach mouse event controllers
        setup_mouse_controls!(vp)

        return vp
    end
end

function set_structure!(vp::MolecularViewport, s::Union{Structure, Nothing})
    vp.structure = s
    reset_camera!(vp)
    Gtk4.draw(vp.canvas)
end

function reset_camera!(vp::MolecularViewport)
    vp.camera.rot_x = 0.3
    vp.camera.rot_y = 0.4
    vp.camera.pan_x = 0.0
    vp.camera.pan_y = 0.0
    empty!(vp.camera.selected_atoms)

    if !isnothing(vp.structure) && !isempty(vp.structure.atoms)
        com = center_of_mass(vp.structure.atoms)
        max_dist = maximum(a -> distance((a.x, a.y, a.z), com), vp.structure.atoms)
        # Auto-fit scale to canvas
        vp.camera.scale = clamp(250.0 / max(max_dist, 1.0), 15.0, 120.0)
    else
        vp.camera.scale = 45.0
    end
    Gtk4.draw(vp.canvas)
end

function select_atom!(vp::MolecularViewport, atom_idx::Int)
    if !(atom_idx in vp.camera.selected_atoms)
        push!(vp.camera.selected_atoms, atom_idx)
        # Keep maximum of 4 selected atoms for measurement chain
        if length(vp.camera.selected_atoms) > 4
            popfirst!(vp.camera.selected_atoms)
        end
        vp.on_selection_changed(vp.camera.selected_atoms)
        Gtk4.draw(vp.canvas)
    end
end

function clear_selection!(vp::MolecularViewport)
    empty!(vp.camera.selected_atoms)
    vp.on_selection_changed(vp.camera.selected_atoms)
    Gtk4.draw(vp.canvas)
end

# 3D Coordinate rotation around center of mass
function project_point(pt::NTuple{3, Float64}, com::NTuple{3, Float64}, cam::Camera3D, w::Float64, h::Float64)
    # Translate to origin
    x0 = pt[1] - com[1]
    y0 = pt[2] - com[2]
    z0 = pt[3] - com[3]

    # Rotate around Y axis (Yaw)
    cos_y = cos(cam.rot_y)
    sin_y = sin(cam.rot_y)
    x1 = x0 * cos_y + z0 * sin_y
    z1 = -x0 * sin_y + z0 * cos_y

    # Rotate around X axis (Pitch)
    cos_x = cos(cam.rot_x)
    sin_x = sin(cam.rot_x)
    y2 = y0 * cos_x - z1 * sin_x
    z2 = y0 * sin_x + z1 * cos_x

    # Screen projection
    screen_x = w / 2.0 + cam.pan_x + x1 * cam.scale
    screen_y = h / 2.0 + cam.pan_y - y2 * cam.scale

    return (screen_x, screen_y, z2)
end

struct DrawableItem
    depth::Float64
    item_type::Symbol  # :bond or :atom
    idx1::Int
    idx2::Int
end

"""
    render_viewport!(vp::MolecularViewport, cr, w::Float64, h::Float64)

Draws the 3D molecular representation using Cairo.
"""
function render_viewport!(vp::MolecularViewport, cr, w::Float64, h::Float64)
    # 1. Dark canvas background
    Cairo.set_source_rgb(cr, 0.08, 0.08, 0.09)
    Cairo.rectangle(cr, 0.0, 0.0, w, h)
    Cairo.fill(cr)

    if isnothing(vp.structure) || isempty(vp.structure.atoms)
        # Empty state prompt
        Cairo.set_source_rgb(cr, 0.45, 0.45, 0.48)
        Cairo.set_font_size(cr, 14.0)
        Cairo.select_font_face(cr, "sans-serif", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
        Cairo.move_to(cr, w / 2.0 - 110.0, h / 2.0)
        Cairo.show_text(cr, "No structure loaded in workspace")
        return
    end

    atoms = vp.structure.atoms
    bonds = vp.structure.bonds
    cam = vp.camera
    com = center_of_mass(atoms)

    # 2. Project all atom positions to screen coordinates
    proj = [project_point((a.x, a.y, a.z), com, cam, w, h) for a in atoms]

    # 3. Create drawable items for depth-sorting (bonds and atoms)
    items = DrawableItem[]

    # Add bonds
    if cam.show_bonds
        for (b_idx, b) in enumerate(bonds)
            z_avg = (proj[b.atom1][3] + proj[b.atom2][3]) / 2.0
            push!(items, DrawableItem(z_avg, :bond, b.atom1, b.atom2))
        end
    end

    # Add atoms
    for i in 1:length(atoms)
        push!(items, DrawableItem(proj[i][3], :atom, i, 0))
    end

    # Sort from furthest (lowest z) to closest (highest z)
    sort!(items, by=item -> item.depth)

    # 4. Render items in painter's order
    for item in items
        if item.item_type == :bond
            p1 = proj[item.idx1]
            p2 = proj[item.idx2]

            # Bond line width scales with zoom
            b_width = clamp(cam.scale * 0.12, 2.0, 8.0)
            Cairo.set_line_width(cr, b_width)
            Cairo.set_source_rgb(cr, 0.35, 0.37, 0.40)
            Cairo.move_to(cr, p1[1], p1[2])
            Cairo.line_to(cr, p2[1], p2[2])
            Cairo.stroke(cr)

        elseif item.item_type == :atom
            a_idx = item.idx1
            a = atoms[a_idx]
            p = proj[a_idx]
            r_cov = covalent_radius_angstrom(a.symbol)
            sphere_r = clamp(r_cov * cam.scale * 0.38, 5.0, 45.0)

            # Atom base color
            rgb = parse_hex_color(cpk_color_hex(a.symbol))

            # Radial gradient for 3D sphere illusion
            pat = Cairo.pattern_create_radial(p[1] - sphere_r * 0.3, p[2] - sphere_r * 0.3, sphere_r * 0.1,
                                              p[1], p[2], sphere_r)
            Cairo.pattern_add_color_stop_rgb(pat, 0.0, min(1.0, rgb[1] + 0.35), min(1.0, rgb[2] + 0.35), min(1.0, rgb[3] + 0.35))
            Cairo.pattern_add_color_stop_rgb(pat, 1.0, rgb[1] * 0.65, rgb[2] * 0.65, rgb[3] * 0.65)
            Cairo.set_source(cr, pat)

            Cairo.arc(cr, p[1], p[2], sphere_r, 0.0, 2π)
            Cairo.fill(cr)
            Cairo.destroy(pat)

            # Selection highlight ring
            if a_idx in cam.selected_atoms
                sel_rank = findfirst(==(a_idx), cam.selected_atoms)
                Cairo.set_line_width(cr, 3.0)
                Cairo.set_source_rgb(cr, 0.43, 0.47, 0.85) # Accent color
                Cairo.arc(cr, p[1], p[2], sphere_r + 4.0, 0.0, 2π)
                Cairo.stroke(cr)

                # Selection number badge
                Cairo.set_source_rgb(cr, 1.0, 1.0, 1.0)
                Cairo.set_font_size(cr, 10.0)
                Cairo.move_to(cr, p[1] + sphere_r + 6.0, p[2] - sphere_r)
                Cairo.show_text(cr, "#$sel_rank")
            end

            # Text label
            if cam.show_labels
                Cairo.set_source_rgb(cr, 0.95, 0.95, 0.95)
                Cairo.set_font_size(cr, clamp(sphere_r * 0.75, 9.0, 14.0))
                Cairo.select_font_face(cr, "sans-serif", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
                lbl = "$(a.symbol)$(a.index)"
                # Center label
                ext = Cairo.text_extents(cr, lbl)
                Cairo.move_to(cr, p[1] - ext[3] / 2.0, p[2] + ext[4] / 2.0)
                Cairo.show_text(cr, lbl)
            end
        end
    end

    # 5. Render analytical measurements for selected atoms
    render_measurements_overlay!(cr, atoms, proj, cam.selected_atoms, w, h)
end

function render_measurements_overlay!(cr, atoms::Vector{Atom}, proj, selected_indices::Vector{Int}, w::Float64, h::Float64)
    n_sel = length(selected_indices)
    if n_sel < 2
        return
    end

    Cairo.set_source_rgb(cr, 0.90, 0.75, 0.20) # Golden yellow for measurements
    Cairo.set_line_width(cr, 1.5)

    # 1. Distance measurement between first two selected atoms
    if n_sel >= 2
        i1 = selected_indices[1]
        i2 = selected_indices[2]
        p1 = proj[i1]
        p2 = proj[i2]

        # Dashed line
        Cairo.set_dash(cr, [4.0, 3.0], 0.0)
        Cairo.move_to(cr, p1[1], p1[2])
        Cairo.line_to(cr, p2[1], p2[2])
        Cairo.stroke(cr)
        Cairo.set_dash(cr, Float64[], 0.0)

        # Distance label
        d = distance((atoms[i1].x, atoms[i1].y, atoms[i1].z), (atoms[i2].x, atoms[i2].y, atoms[i2].z))
        mid_x = (p1[1] + p2[1]) / 2.0
        mid_y = (p1[2] + p2[2]) / 2.0 - 8.0
        lbl = "$(round(d, digits=3)) Å"
        Cairo.set_font_size(cr, 12.0)
        Cairo.move_to(cr, mid_x, mid_y)
        Cairo.show_text(cr, lbl)
    end

    # 2. Angle measurement if 3 atoms selected
    if n_sel >= 3
        i1 = selected_indices[1]
        i2 = selected_indices[2] # vertex
        i3 = selected_indices[3]
        theta_rad = bond_angle((atoms[i1].x, atoms[i1].y, atoms[i1].z),
                               (atoms[i2].x, atoms[i2].y, atoms[i2].z),
                               (atoms[i3].x, atoms[i3].y, atoms[i3].z))
        theta_deg = round(rad2deg(theta_rad), digits=2)
        p2 = proj[i2]
        Cairo.move_to(cr, p2[1] + 12.0, p2[2] + 20.0)
        Cairo.show_text(cr, "∠: $(theta_deg)°")
    end

    # 3. Dihedral measurement if 4 atoms selected
    if n_sel == 4
        i1 = selected_indices[1]
        i2 = selected_indices[2]
        i3 = selected_indices[3]
        i4 = selected_indices[4]
        try
            phi_rad = dihedral_angle((atoms[i1].x, atoms[i1].y, atoms[i1].z),
                                     (atoms[i2].x, atoms[i2].y, atoms[i2].z),
                                     (atoms[i3].x, atoms[i3].y, atoms[i3].z),
                                     (atoms[i4].x, atoms[i4].y, atoms[i4].z))
            phi_deg = round(rad2deg(phi_rad), digits=2)
            p3 = proj[i3]
            Cairo.move_to(cr, p3[1] + 12.0, p3[2] + 20.0)
            Cairo.show_text(cr, "Torsion: $(phi_deg)°")
        catch
            # Collinear / undefined dihedral
        end
    end
end

function setup_mouse_controls!(vp::MolecularViewport)
    # Drag gesture for 3D Orbit
    gesture_drag = GtkGestureDrag(vp.canvas)
    Gtk4.signal_connect(gesture_drag, "drag-begin") do controller, x, y
        vp.is_dragging = true
        vp.last_mouse_x = x
        vp.last_mouse_y = y
    end

    Gtk4.signal_connect(gesture_drag, "drag-update") do controller, x, y
        if vp.is_dragging
            dx = x - vp.last_mouse_x
            dy = y - vp.last_mouse_y
            vp.camera.rot_y += dx * 0.015
            vp.camera.rot_x += dy * 0.015
            vp.last_mouse_x = x
            vp.last_mouse_y = y
            Gtk4.draw(vp.canvas)
        end
    end

    Gtk4.signal_connect(gesture_drag, "drag-end") do controller, x, y
        vp.is_dragging = false
    end

    # Click gesture for Atom Picking
    gesture_click = GtkGestureClick(vp.canvas)
    Gtk4.signal_connect(gesture_click, "pressed") do controller, n_press, x, y
        if !isnothing(vp.structure) && !isempty(vp.structure.atoms)
            w = Float64(Gtk4.width(vp.canvas))
            h = Float64(Gtk4.height(vp.canvas))
            com = center_of_mass(vp.structure.atoms)

            # Find closest atom to click
            closest_idx = 0
            min_screen_dist = 20.0 # Pick threshold in pixels

            for (i, a) in enumerate(vp.structure.atoms)
                p = project_point((a.x, a.y, a.z), com, vp.camera, w, h)
                sd = sqrt((p[1] - x)^2 + (p[2] - y)^2)
                if sd < min_screen_dist
                    min_screen_dist = sd
                    closest_idx = i
                end
            end

            if closest_idx > 0
                select_atom!(vp, closest_idx)
            else
                clear_selection!(vp)
            end
        end
    end

    # Scroll controller for Zoom
    ctrl_scroll = GtkEventControllerScroll(Gtk4.EventControllerScrollFlags_VERTICAL, vp.canvas)
    Gtk4.signal_connect(ctrl_scroll, "scroll") do controller, dx, dy
        if dy < 0
            vp.camera.scale *= 1.15
        else
            vp.camera.scale *= 0.85
        end
        vp.camera.scale = clamp(vp.camera.scale, 5.0, 300.0)
        Gtk4.draw(vp.canvas)
        return true
    end
end

end # module MolecularView
