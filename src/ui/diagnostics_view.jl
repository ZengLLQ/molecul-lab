"""
Diagnostics and system capabilities view.
Displays CPU, RAM, NVIDIA GPU/CUDA status, and environment provenance.
"""
module DiagnosticsView

using Gtk4
using ..Hardware: probe_hardware
using ..Environment: get_runtime_manifest

export create_diagnostics_panel

function create_diagnostics_panel()::GtkBox
    box = GtkBox(:v, 16)
    box.margin_start = 24
    box.margin_end = 24
    box.margin_top = 20
    box.margin_bottom = 20

    # Title
    lbl_title = GtkLabel("System Capabilities & Diagnostics")
    Gtk4.halign(lbl_title, Gtk4.Align_START)
    push!(box, lbl_title)

    lbl_sub = GtkLabel("Local hardware probes and environment reproducibility manifest")
    Gtk4.halign(lbl_sub, Gtk4.Align_START)
    push!(box, lbl_sub)

    hw = probe_hardware()
    manifest = get_runtime_manifest()

    # Hardware Card
    card_hw = GtkBox(:v, 8)
    lbl_hw_head = GtkLabel("<b>Hardware Architecture</b>")
    lbl_hw_head.use_markup = true
    Gtk4.halign(lbl_hw_head, Gtk4.Align_START)
    push!(card_hw, lbl_hw_head)

    push!(card_hw, GtkLabel("CPU: $(hw.cpu_model) ($(hw.cpu_threads) threads)"))
    push!(card_hw, GtkLabel("Memory: $(hw.free_memory_gb) GB free / $(hw.total_memory_gb) GB total"))

    gpu_status_str = if hw.gpu_detected
        "<span foreground='#2E7D5B'><b>Detected:</b></span> $(hw.gpu_name) ($(round(hw.gpu_vram_mb / 1024, digits=1)) GB VRAM, Driver $(hw.gpu_driver_version))"
    else
        "<span foreground='#666666'>No supported NVIDIA GPU detected (CPU baseline active)</span>"
    end
    lbl_gpu = GtkLabel(gpu_status_str)
    lbl_gpu.use_markup = true
    Gtk4.halign(lbl_gpu, Gtk4.Align_START)
    push!(card_hw, lbl_gpu)

    push!(box, card_hw)

    # Software Manifest Card
    card_sw = GtkBox(:v, 8)
    lbl_sw_head = GtkLabel("<b>Software Runtime &amp; Manifest</b>")
    lbl_sw_head.use_markup = true
    Gtk4.halign(lbl_sw_head, Gtk4.Align_START)
    push!(card_sw, lbl_sw_head)

    push!(card_sw, GtkLabel("Julia Runtime: v$(VERSION) on $(Sys.KERNEL) $(Sys.ARCH)"))
    push!(card_sw, GtkLabel("MolecuLab Workbench: v1.0.0 (Local-first)"))
    push!(card_sw, GtkLabel("Manifest SHA-256: $(isempty(manifest["manifest_sha256"]) ? "Not locked" : manifest["manifest_sha256"][1:16] * "...")"))

    push!(box, card_sw)

    return box
end

end # module DiagnosticsView
