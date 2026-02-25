#!/usr/bin/env bash
# cliphist — Clipboard history picker
# Uses Walker's clipboard provider if available, falls back to wofi/dmenu.
#
# Sway config autostart (to start listening):
#   exec wl-paste --watch cliphist store
#
# Sway config keybind:
#   bindsym $mod+v exec ~/.config/cliphist/cliphist-pick.sh
set -euo pipefail

if command -v walker &>/dev/null; then
  exec walker --modules clipboard
else
  cliphist list | wofi --dmenu --prompt "Clipboard" | cliphist decode | wl-copy
fi
