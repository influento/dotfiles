#!/usr/bin/env bash
# cliphist — Clipboard history picker (gtk-widgets launcher --dmenu)
#
# Sway config autostart (to start listening):
#   exec wl-paste --watch cliphist -max-items 100 store
#
# Sway config keybind:
#   bindsym $mod+v exec ~/.config/cliphist/cliphist-pick.sh
set -euo pipefail

# Esc makes launcher exit 1 with no output; stop there, or wl-copy would run
# on empty input and clear the clipboard. The Clear button exits 10: empty
# the history and the current clipboard
status=0
sel=$(cliphist list | launcher --dmenu --prompt Clipboard --after-tab --action Clear) || status=$?
case "$status" in
  0) printf '%s\n' "$sel" | cliphist decode | wl-copy ;;
  10)
    wl-copy --clear
    cliphist wipe
    ;;
esac
