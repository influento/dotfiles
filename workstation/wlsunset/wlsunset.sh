#!/usr/bin/env bash
# wlsunset — Night light / blue light filter for Wayland
# Sourced/executed from Sway config: exec ~/.config/wlsunset/wlsunset.sh
set -euo pipefail

# Temperature range (in Kelvin)
#   Day:   6500K (neutral daylight)
#   Night: 4000K (warm, easy on eyes)
TEMP_HIGH=6500
TEMP_LOW=4000

# Location (used for sunrise/sunset calculation)
# Default: Warsaw, Poland — change to your coordinates
LATITUDE=52.2
LONGITUDE=21.0

exec wlsunset -T "$TEMP_HIGH" -t "$TEMP_LOW" -l "$LATITUDE" -L "$LONGITUDE"
