#!/usr/bin/env bash
# themes/catppuccin-mocha.sh — Catppuccin Mocha color palette
# https://github.com/catppuccin/catppuccin
set -euo pipefail

# Used by lib/theme.sh after sourcing
# shellcheck disable=SC2034
declare -gA THEME_META=(
  [NAME]="catppuccin-mocha"
  [DISPLAY_NAME]="Catppuccin Mocha"
)

# shellcheck disable=SC2034
declare -gA THEME_COLORS=(
  # Base colors
  [BASE]="1e1e2e"
  [MANTLE]="181825"
  [CRUST]="11111b"

  # Surface colors
  [SURFACE0]="313244"
  [SURFACE1]="45475a"
  [SURFACE2]="585b70"

  # Overlay colors
  [OVERLAY0]="6c7086"
  [OVERLAY1]="7f849c"
  [OVERLAY2]="9399b2"

  # Text colors
  [SUBTEXT0]="a6adc8"
  [SUBTEXT1]="bac2de"
  [TEXT]="cdd6f4"

  # Accent colors
  [ROSEWATER]="f5e0dc"
  [FLAMINGO]="f2cdcd"
  [PINK]="f5c2e7"
  [MAUVE]="cba6f7"
  [RED]="f38ba8"
  [MAROON]="eba0ac"
  [PEACH]="fab387"
  [YELLOW]="f9e2af"
  [GREEN]="a6e3a1"
  [TEAL]="94e2d5"
  [SKY]="89dceb"
  [SAPPHIRE]="74c7ec"
  [BLUE]="89b4fa"
  [LAVENDER]="b4befe"

  # Semantic aliases
  [ACCENT]="b4befe"
  [ERROR]="f38ba8"
  [WARNING]="fab387"
  [SUCCESS]="a6e3a1"
  [INFO]="89b4fa"
)
