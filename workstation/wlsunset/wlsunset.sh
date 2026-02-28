#!/usr/bin/env bash
# wlsunset — Static blue light filter for Wayland
# Sourced/executed from Sway config: exec ~/.config/wlsunset/wlsunset.sh
set -euo pipefail

# Fixed color temperature (4500K — subtle warmth, always on)
exec wlsunset -T 4501 -t 4500
