#!/usr/bin/env bash
# swaybg — Wallpaper launcher for Sway
# Sourced/executed from Sway config: exec ~/.config/swaybg/wallpaper.sh
set -euo pipefail

WALLPAPER_DIR="${HOME}/.config/swaybg/wallpapers"
DEFAULT_COLOR="@@BASE@@"

# Use first image found in wallpaper dir, or fall back to solid color
if [[ -d "$WALLPAPER_DIR" ]]; then
  wallpaper="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | head -1)"
fi

if [[ -n "${wallpaper:-}" ]]; then
  exec swaybg -i "$wallpaper" -m fill
else
  exec swaybg -c "$DEFAULT_COLOR"
fi
