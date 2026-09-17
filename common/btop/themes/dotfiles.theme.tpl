# btop theme — rendered from the active dotfiles palette (themes/<name>.sh).
# Managed by dotfiles repo: edit dotfiles.theme.tpl, never the generated file.
# Key layout follows catppuccin/btop; every value is a palette token so the
# file follows theme.conf like the rest of the templates.

# Main background, empty for terminal default, need to be empty if you want transparent background
theme[main_bg]="@@BASE@@"

# Main text color
theme[main_fg]="@@TEXT@@"

# Title color for boxes
theme[title]="@@TEXT@@"

# Highlight color for keyboard shortcuts
theme[hi_fg]="@@BLUE@@"

# Background color of selected item in processes box
theme[selected_bg]="@@SURFACE1@@"

# Foreground color of selected item in processes box
theme[selected_fg]="@@BLUE@@"

# Color of inactive/disabled text
theme[inactive_fg]="@@OVERLAY1@@"

# Color of text appearing on top of graphs, i.e uptime and current network graph scaling
theme[graph_text]="@@ROSEWATER@@"

# Background color of the percentage meters
theme[meter_bg]="@@SURFACE1@@"

# Misc colors for processes box including mini cpu graphs, details memory graph and details status text
theme[proc_misc]="@@ROSEWATER@@"

# CPU, Memory, Network, Proc box outline colors
theme[cpu_box]="@@MAUVE@@"
theme[mem_box]="@@GREEN@@"
theme[net_box]="@@MAROON@@"
theme[proc_box]="@@BLUE@@"

# Box divider line and small boxes line color
theme[div_line]="@@OVERLAY0@@"

# Temperature graph color (Green -> Yellow -> Red)
theme[temp_start]="@@GREEN@@"
theme[temp_mid]="@@YELLOW@@"
theme[temp_end]="@@RED@@"

# CPU graph colors (Teal -> Lavender)
theme[cpu_start]="@@TEAL@@"
theme[cpu_mid]="@@SAPPHIRE@@"
theme[cpu_end]="@@LAVENDER@@"

# Mem/Disk free meter (Mauve -> Lavender -> Blue)
theme[free_start]="@@MAUVE@@"
theme[free_mid]="@@LAVENDER@@"
theme[free_end]="@@BLUE@@"

# Mem/Disk cached meter (Sapphire -> Lavender)
theme[cached_start]="@@SAPPHIRE@@"
theme[cached_mid]="@@BLUE@@"
theme[cached_end]="@@LAVENDER@@"

# Mem/Disk available meter (Peach -> Red)
theme[available_start]="@@PEACH@@"
theme[available_mid]="@@MAROON@@"
theme[available_end]="@@RED@@"

# Mem/Disk used meter (Green -> Sky)
theme[used_start]="@@GREEN@@"
theme[used_mid]="@@TEAL@@"
theme[used_end]="@@SKY@@"

# Download graph colors (Peach -> Red)
theme[download_start]="@@PEACH@@"
theme[download_mid]="@@MAROON@@"
theme[download_end]="@@RED@@"

# Upload graph colors (Green -> Sky)
theme[upload_start]="@@GREEN@@"
theme[upload_mid]="@@TEAL@@"
theme[upload_end]="@@SKY@@"

# Process box color gradient for threads, mem and cpu usage (Sapphire -> Mauve)
theme[process_start]="@@SAPPHIRE@@"
theme[process_mid]="@@LAVENDER@@"
theme[process_end]="@@MAUVE@@"
