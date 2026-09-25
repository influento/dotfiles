#!/usr/bin/env bash
# cliphist — Clipboard history picker (gtk-widgets launcher --dmenu)
#
# Sway config autostart (to start listening):
#   exec wl-paste --watch cliphist -max-items 100 store
#
# Sway config keybind:
#   bindsym $mod+v exec ~/.config/cliphist/cliphist-pick.sh
set -euo pipefail

# Esc makes launcher exit non-zero with no output; stop there, or wl-copy
# would run on empty input and clear the clipboard
sel=$(cliphist list | launcher --dmenu --prompt Clipboard --after-tab) || exit 0
printf '%s\n' "$sel" | cliphist decode | wl-copy
