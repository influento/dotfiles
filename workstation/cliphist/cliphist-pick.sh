#!/usr/bin/env bash
# cliphist — Clipboard history picker (wofi)
#
# Sway config autostart (to start listening):
#   exec wl-paste --watch cliphist store
#
# Sway config keybind:
#   bindsym $mod+v exec ~/.config/cliphist/cliphist-pick.sh
set -euo pipefail

cliphist list | wofi --dmenu --prompt "Clipboard" | cliphist decode | wl-copy
