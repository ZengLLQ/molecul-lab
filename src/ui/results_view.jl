"""
Run Monitor and Results Explorer view.
Renders real-time convergence plots on Cairo GtkCanvas, tracks live solver metrics,
and presents verified output artifacts with full provenance.
"""
module ResultsView

using Cairo
using Gtk4
using Printf
using ..Results: Result, Job, JobState, is_terminal
using ..Theme: parse_hex_color

export ResultsPanel, update_results_view!, update_live_progress!

mutable struct ResultsPanel
    container::GtkBox
    plot_canvas::GtkCanvas
    lbl_status::GtkLabel
    lbl_metrics::GtkLabel
    btn_cancel::GtkButton
    history_data::Vector{NamedTuple{(:iteration, :energy, :gradient_norm), Tuple{Int, Float64, Float64}}}
    active_job_id::Union{String, Nothing}
    on_cancel_requested::Function

    function ResultsPanel(; on_cancel_requested::Function=() -> nothing)
        box = GtkBox(:v, 14)
        box.margin_start = 20
        box.margin_end = 20
        box.margin_top = 16
        box.margin_bottom = 16

        # Header with Status and Cancel action
        top_bar = GtkBox(:h, 12)
        lbl_status = GtkLabel("Status: <b>IDLE</b>")
        lbl_status.use_markup = true
        Gtk4.halign(lbl_status, Gtk4.Align_START)
        Gtk4.hexpand(lbl_status, true)
        push!(top_bar, lbl_status)

        btn_cancel = GtkButton("Request Cancellation")
        btn_cancel.sensitive = false
        push!(top_bar, btn_cancel)
        push!(box, top_bar)

        # Convergence Plot Canvas
        plot_canvas = GtkCanvas()
        Gtk4.vexpand(plot_canvas, true)
        Gtk4.hexpand(plot_canvas, true)
        push!(box, plot_canvas)

        # Metrics readout
        lbl_metrics = GtkLabel("No calculation active.")
        Gtk4.halign(lbl_metrics, Gtk4.Align_START)
        push!(box, lbl_metrics)

        panel = new(box, plot_canvas, lbl_status, lbl_metrics, btn_cancel,
                    NamedTuple{(:iteration, :energy, :gradient_norm), Tuple{Int, Float64, Float64}}[],
                    nothing, on_cancel_requested)

        # Draw plot
        Gtk4.draw(plot_canvas) do widget
            cr = Gtk4.cairo_context(widget)
            w = Float64(Gtk4.width(widget))
            h = Float64(Gtk4.height(widget))
            render_convergence_plot!(cr, panel.history_data, w, h)
        end

        Gtk4.signal_connect(btn_cancel, "clicked") do _
            panel.on_cancel_requested()
        end

        return panel
    end
end

function update_live_progress!(panel::ResultsPanel, job_id::AbstractString, iter::Int, energy::Float64, gnorm::Float64)
    panel.active_job_id = String(job_id)
    panel.btn_cancel.sensitive = true
    push!(panel.history_data, (iteration=iter, energy=energy, gradient_norm=gnorm))

    panel.lbl_status.label = "Status: <span foreground='#2E7D5B'><b>RUNNING</b></span> (Iter: $iter)"
    panel.lbl_status.use_markup = true

    panel.lbl_metrics.label = @sprintf("Energy: %12.6f kJ/mol  |  ||∇E||: %10.4e  |  Data points: %d", energy, gnorm, length(panel.history_data))
    Gtk4.draw(panel.plot_canvas)
end

function update_results_view!(panel::ResultsPanel, res::Union{Result, Nothing})
    panel.btn_cancel.sensitive = false
    if isnothing(res)
        panel.lbl_status.label = "Status: <b>No Results</b>"
        panel.lbl_status.use_markup = true
        panel.lbl_metrics.label = ""
        empty!(panel.history_data)
        Gtk4.draw(panel.plot_canvas)
        return
    end

    status_color = res.converged ? "#2E7D5B" : "#B7791F"
    panel.lbl_status.label = "Status: <span foreground='$status_color'><b>$(uppercase(res.termination_status))</b></span>"
    panel.lbl_status.use_markup = true

    panel.lbl_metrics.label = @sprintf("Final Energy: %14.6f kJ/mol  |  Final ||∇E||: %10.4e  |  Iterations: %d  |  Artifacts: %d",
                                      res.final_energy, res.gradient_norm, res.iterations, length(res.artifacts))

    # Populate history data if available in metrics
    if haskey(res.metrics, "history")
        hist = res.metrics["history"]
        panel.history_data = [(iteration=Int(h["iteration"]), energy=Float64(h["energy"]), gradient_norm=Float64(h["gradient_norm"])) for h in hist]
    end

    Gtk4.draw(panel.plot_canvas)
end

"""
    render_convergence_plot!(cr, data, w::Float64, h::Float64)

Renders a publication-quality 2D scientific convergence plot with labeled axes and units.
"""
function render_convergence_plot!(cr, data, w::Float64, h::Float64)
    # Background
    Cairo.set_source_rgb(cr, 0.98, 0.98, 0.97)
    Cairo.rectangle(cr, 0.0, 0.0, w, h)
    Cairo.fill(cr)

    margin_left = 65.0
    margin_right = 25.0
    margin_top = 30.0
    margin_bottom = 45.0

    plot_w = max(10.0, w - margin_left - margin_right)
    plot_h = max(10.0, h - margin_top - margin_bottom)

    # Plot area background
    Cairo.set_source_rgb(cr, 1.0, 1.0, 1.0)
    Cairo.rectangle(cr, margin_left, margin_top, plot_w, plot_h)
    Cairo.fill(cr)

    # Plot border
    Cairo.set_source_rgb(cr, 0.85, 0.85, 0.83)
    Cairo.set_line_width(cr, 1.0)
    Cairo.rectangle(cr, margin_left, margin_top, plot_w, plot_h)
    Cairo.stroke(cr)

    # Labels
    Cairo.set_source_rgb(cr, 0.15, 0.15, 0.15)
    Cairo.set_font_size(cr, 11.0)
    Cairo.select_font_face(cr, "sans-serif", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)

    # X-axis label
    lbl_x = "Optimization Iteration"
    ext_x = Cairo.text_extents(cr, lbl_x)
    Cairo.move_to(cr, margin_left + (plot_w - ext_x[3]) / 2.0, h - 12.0)
    Cairo.show_text(cr, lbl_x)

    # Y-axis label (Rotated)
    Cairo.save(cr)
    Cairo.move_to(cr, 16.0, margin_top + (plot_h + 80.0) / 2.0)
    Cairo.rotate(cr, -π / 2.0)
    Cairo.show_text(cr, "Potential Energy (kJ/mol)")
    Cairo.restore(cr)

    if length(data) < 2
        Cairo.set_source_rgb(cr, 0.55, 0.55, 0.58)
        Cairo.move_to(cr, margin_left + plot_w / 2.0 - 65.0, margin_top + plot_h / 2.0)
        Cairo.show_text(cr, "No convergence history")
        return
    end

    # Calculate data bounds
    min_x = minimum(d -> d.iteration, data)
    max_x = maximum(d -> d.iteration, data)
    min_y = minimum(d -> d.energy, data)
    max_y = maximum(d -> d.energy, data)

    # Expand Y bounds slightly to prevent edge clipping
    y_range = max(1e-6, max_y - min_y)
    min_y -= y_range * 0.05
    max_y += y_range * 0.05
    x_range = max(1, max_x - min_x)

    # Coordinates mapping helper
    to_screen(iter, val) = (
        margin_left + ((iter - min_x) / x_range) * plot_w,
        margin_top + (1.0 - (val - min_y) / (max_y - min_y)) * plot_h
    )

    # Draw grid lines
    Cairo.set_source_rgb(cr, 0.92, 0.92, 0.90)
    Cairo.set_line_width(cr, 0.75)
    for i in 1:4
        y_val = min_y + (i / 5.0) * (max_y - min_y)
        _, sy = to_screen(min_x, y_val)
        Cairo.move_to(cr, margin_left, sy)
        Cairo.line_to(cr, margin_left + plot_w, sy)
        Cairo.stroke(cr)

        # Tick label
        Cairo.set_source_rgb(cr, 0.45, 0.45, 0.45)
        Cairo.set_font_size(cr, 9.0)
        @printf(cr, "")
        tick_str = @sprintf("%.2f", y_val)
        Cairo.move_to(cr, 20.0, sy + 3.0)
        Cairo.show_text(cr, tick_str)
    end

    # Plot convergence curve
    Cairo.set_source_rgb(cr, 0.43, 0.47, 0.85) # Accent color
    Cairo.set_line_width(cr, 2.0)

    p0 = to_screen(data[1].iteration, data[1].energy)
    Cairo.move_to(cr, p0[1], p0[2])
    for d in data[2:end]
        pt = to_screen(d.iteration, d.energy)
        Cairo.line_to(cr, pt[1], pt[2])
    end
    Cairo.stroke(cr)

    # Plot data points
    Cairo.set_source_rgb(cr, 0.25, 0.28, 0.65)
    for d in data
        pt = to_screen(d.iteration, d.energy)
        Cairo.arc(cr, pt[1], pt[2], 3.0, 0.0, 2π)
        Cairo.fill(cr)
    end
end

end # module ResultsView
