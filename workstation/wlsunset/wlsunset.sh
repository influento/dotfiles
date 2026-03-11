#!/usr/bin/env bash
# wlsunset — Blue light filter for Wayland
# Sourced/executed from Sway config: exec ~/.config/wlsunset/wlsunset.sh
# Temperature is persisted by display-popup widget
set -euo pipefail

temp_file="$HOME/.config/wlsunset/temperature"
temp=4500
if [[ -f "$temp_file" ]]; then
  temp=$(cat "$temp_file")
fi

exec wlsunset -T $((temp + 1)) -t "$temp"
