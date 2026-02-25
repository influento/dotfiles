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

# --- Defaults ---
PROFILE=""
TARGET_USER="${USER:-}"
USER_HOME=""
DRY_RUN=0

# --- CLI argument parsing ---

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy user-level configuration (dotfiles) with profile-based selection.

Options:
  --profile PROFILE   Required. server | workstation
  --user USERNAME     Target user (default: current user)
  --dry-run           Show what would be done without making changes
  --help              Show this help message

Profiles:
  server       CLI tools only: zsh, neovim, tmux, git, starship
  workstation  CLI tools + desktop: hyprland, waybar, ghostty, theming

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

export TARGET_USER

# --- Summary ---

log_section "Dotfiles Installer"
log_info "Profile:    $PROFILE"
log_info "User:       $TARGET_USER"
log_info "Home:       $USER_HOME"
log_info "Dotfiles:   $DOTFILES_DIR"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_info ""
  log_info "Dry run — would deploy:"
  log_info "  common configs: zsh, nvim, tmux, git, starship"
  if [[ "$PROFILE" == "workstation" ]]; then
    log_info "  workstation configs: hypr, waybar, ghostty, theming"
  fi
  log_info "  oh-my-zsh: install if missing"
  exit 0
fi

# --- Deploy ---

# Install oh-my-zsh (prerequisite for zsh config)
install_omz "$USER_HOME"

# Deploy common configs (all profiles)
deploy_configs "${DOTFILES_DIR}/common" "$USER_HOME" "common"

# Deploy workstation configs (workstation profile only)
if [[ "$PROFILE" == "workstation" ]]; then
  deploy_configs "${DOTFILES_DIR}/workstation" "$USER_HOME" "workstation"
fi

# --- Fix ownership if running as root ---

if [[ $EUID -eq 0 && "$TARGET_USER" != "root" ]]; then
  log_info "Fixing ownership for $TARGET_USER..."
  chown -R "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.config" 2>/dev/null || true
  chown -h "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.zshrc" 2>/dev/null || true
  chown -h "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.gitconfig" 2>/dev/null || true
  chown -h "${TARGET_USER}:${TARGET_USER}" "$USER_HOME/.oh-my-zsh" 2>/dev/null || true
fi

log_section "Done"
log_info "Dotfiles deployed for $TARGET_USER ($PROFILE profile)."
log_info "Re-run this script anytime to update symlinks."
