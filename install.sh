#!/usr/bin/env bash
# install.sh — Dotfiles installer
# Deploys user-level configuration with profile-based selection.
# Idempotent: safe to re-run at any time.
#
# Usage:
#   bash install.sh --profile server --user myuser
#   bash install.sh --profile workstation
#   bash install.sh --help
# shellcheck source-path=SCRIPTDIR
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/log.sh
source "${DOTFILES_DIR}/lib/log.sh"
# shellcheck source=lib/helpers.sh
source "${DOTFILES_DIR}/lib/helpers.sh"
# shellcheck source=lib/theme.sh
source "${DOTFILES_DIR}/lib/theme.sh"

# --- Defaults ---
PROFILE=""
TARGET_USER="${USER:-}"
USER_HOME=""
DRY_RUN=0
THEME=""

# --- CLI argument parsing ---

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy user-level configuration (dotfiles) with profile-based selection.

Options:
  --profile PROFILE   Required. server | workstation
  --user USERNAME     Target user (default: current user)
  --theme THEME       Color theme (default: from theme.conf or catppuccin-mocha)
  --dry-run           Show what would be done without making changes
  --help              Show this help message

Profiles:
  server       CLI tools only: zsh, neovim, tmux, git, starship
  workstation  CLI tools + desktop: sway, waybar, ghostty, theming

Examples:
  bash install.sh --profile server
  bash install.sh --profile workstation --user myuser
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)   PROFILE="$2"; shift 2 ;;
    --user)      TARGET_USER="$2"; shift 2 ;;
    --theme)     THEME="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --help)      usage ;;
    *)           die "Unknown option: $1. Use --help for usage." ;;
  esac
done

# --- Validation ---

if [[ -z "$PROFILE" ]]; then
  die "Missing required option: --profile (server | workstation)"
fi

case "$PROFILE" in
  server|workstation) ;;
  *) die "Invalid profile: $PROFILE. Must be 'server' or 'workstation'." ;;
esac

if [[ -z "$TARGET_USER" ]]; then
  die "Could not determine target user. Pass --user USERNAME."
fi

# Resolve user home directory
if [[ $EUID -eq 0 ]]; then
  USER_HOME=$(eval echo "~${TARGET_USER}")
else
  USER_HOME="$HOME"
fi

if [[ ! -d "$USER_HOME" ]]; then
  die "Home directory not found: $USER_HOME"
fi

# Resolve theme: CLI flag > theme.conf > fallback
if [[ -z "$THEME" ]]; then
  if [[ -f "${DOTFILES_DIR}/theme.conf" ]]; then
    # shellcheck source=/dev/null
    source "${DOTFILES_DIR}/theme.conf"
  fi
  THEME="${THEME:-catppuccin-mocha}"
fi

export TARGET_USER

# --- Summary ---

log_section "Dotfiles Installer"
log_info "Profile:    $PROFILE"
log_info "User:       $TARGET_USER"
log_info "Home:       $USER_HOME"
log_info "Dotfiles:   $DOTFILES_DIR"
log_info "Theme:      $THEME"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_info ""
  log_info "Dry run — would deploy:"
  log_info "  theme: $THEME (render .tpl templates with theme colors)"
  log_info "  common configs: zsh, nvim, tmux, git, starship, fontconfig, lazygit, btop, fastfetch"
  if [[ "$PROFILE" == "workstation" ]]; then
    log_info "  workstation configs: sway, waybar, ghostty, swaylock, swayidle, mako, swaybg, wlsunset, swayosd, cliphist, theming"
    log_info "  obsidian plugins: install from workstation/obsidian/plugins.conf (if vault exists)"
  fi
  log_info "  oh-my-zsh: install if missing"
  exit 0
fi

# --- Deploy ---

# Install oh-my-zsh (prerequisite for zsh config)
install_omz "$USER_HOME"
install_zsh_plugins "$USER_HOME"

# Load theme and render templates
load_theme "$THEME"
build_sed_script
render_templates "${DOTFILES_DIR}/common" "common"
if [[ "$PROFILE" == "workstation" ]]; then
  render_templates "${DOTFILES_DIR}/workstation" "workstation"
fi
validate_rendered "${DOTFILES_DIR}/common"
if [[ "$PROFILE" == "workstation" ]]; then
  validate_rendered "${DOTFILES_DIR}/workstation"
fi

# Deploy common configs (all profiles)
deploy_configs "${DOTFILES_DIR}/common" "$USER_HOME" "common"

# Deploy workstation configs (workstation profile only)
if [[ "$PROFILE" == "workstation" ]]; then
  deploy_configs "${DOTFILES_DIR}/workstation" "$USER_HOME" "workstation"
  install_obsidian_plugins "$USER_HOME"
fi

# --- Fix ownership if running as root ---

if [[ $EUID -eq 0 && "$TARGET_USER" != "root" ]]; then
  log_info "Fixing ownership for $TARGET_USER..."
  chown -R "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.config" 2>/dev/null || true
  chown -R "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.local" 2>/dev/null || true
  chown -h "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.zshrc" 2>/dev/null || true
  chown -h "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.gitconfig" 2>/dev/null || true
  chown -h "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.oh-my-zsh" 2>/dev/null || true
  # Fix ownership for Obsidian vault plugin files if they were created
  if [[ -d "${USER_HOME}/dropbox/data-vault/.obsidian" ]]; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/dropbox/data-vault/.obsidian" 2>/dev/null || true
  fi
fi

log_section "Done"
log_info "Dotfiles deployed for $TARGET_USER ($PROFILE profile)."
log_info "Re-run this script anytime to update symlinks."
