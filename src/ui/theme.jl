"""
Design tokens and styling rules for MolecuLab desktop UI.
Minimalist, high-contrast scientific aesthetic.
"""
module Theme

export PALETTE, CSS_RULES, parse_hex_color

const PALETTE = Dict{String, String}(
    "canvas_light"    => "#F5F5F2",
    "surface_light"   => "#FFFFFF",
    "text_primary"    => "#171717",
    "text_secondary"  => "#666666",
    "border"          => "#DADAD5",
    "canvas_dark"     => "#111111",
    "surface_dark"    => "#1B1B1B",
    "text_dark"       => "#F4F4F0",
    "accent"          => "#6D78D8",
    "accent_hover"    => "#5661BC",
    "status_success"  => "#2E7D5B",
    "status_warning"  => "#B7791F",
    "status_error"    => "#B83A3A"
)

function parse_hex_color(hex_str::AbstractString)::Tuple{Float64, Float64, Float64}
    s = strip(hex_str)
    s = startswith(s, "#") ? s[2:end] : s
    if length(s) == 6
        r = parse(Int, s[1:2], base=16) / 255.0
        g = parse(Int, s[3:4], base=16) / 255.0
        b = parse(Int, s[5:6], base=16) / 255.0
        return (r, g, b)
    end
    return (0.5, 0.5, 0.5)
end

const CSS_RULES = """
window.moleculab-main {
    background-color: $(PALETTE["canvas_light"]);
    color: $(PALETTE["text_primary"]);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}

.sidebar-nav {
    background-color: $(PALETTE["surface_light"]);
    border-right: 1px solid $(PALETTE["border"]);
    padding: 12px;
}

.panel-container {
    background-color: $(PALETTE["canvas_light"]);
    padding: 16px;
}

.surface-card {
    background-color: $(PALETTE["surface_light"]);
    border: 1px solid $(PALETTE["border"]);
    border-radius: 6px;
    padding: 16px;
}

.header-title {
    font-size: 18px;
    font-weight: 600;
    color: $(PALETTE["text_primary"]);
}

.header-subtitle {
    font-size: 13px;
    color: $(PALETTE["text_secondary"]);
}

button.primary-action {
    background-color: $(PALETTE["accent"]);
    color: #FFFFFF;
    font-weight: 500;
    border-radius: 4px;
    padding: 6px 14px;
    border: none;
}

button.primary-action:hover {
    background-color: $(PALETTE["accent_hover"]);
}

.badge-success {
    color: $(PALETTE["status_success"]);
    font-weight: 600;
}

.badge-error {
    color: $(PALETTE["status_error"]);
    font-weight: 600;
}

.badge-warning {
    color: $(PALETTE["status_warning"]);
    font-weight: 600;
}
"""

end # module Theme
