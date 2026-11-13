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
# shellcheck source=lib/reminders.sh
source "${DOTFILES_DIR}/lib/reminders.sh"

# --- Pinned releases ---
# influento/tmux-plugins: one tag for tmux-warp, tmux-agent and tmux-revive.
# The sha256 is that of the release's SHA256SUMS, which every asset is
# checked against. tmux.conf, settings.json and the zsh config call these
# binaries, so a new tag is pinned in the same commit as their changes.
readonly TMUX_PLUGINS_REPO=influento/tmux-plugins
readonly TMUX_PLUGINS_VERSION=v0.3.6
readonly TMUX_PLUGINS_SHA256=81d7fbf3bca0bfd340a4ee54d6696a5d4ecf50591512731b9b1ef7923286e6f7

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
  --user USERNAME     Target user; must match the invoking user (default: current user)
  --theme THEME       Color theme (default: from theme.conf or catppuccin-mocha)
  --dry-run           Show what would be done without making changes
  --help              Show this help message

Profiles:
  server       common configs only: shell, editor, terminal tools, Claude Code
  workstation  common + desktop: sway, waybar, ghostty, theming

Examples:
  bash install.sh --profile server
  bash install.sh --profile workstation --user myuser
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile|--user|--theme)
      [[ $# -ge 2 && "$2" != --* ]] || die "Missing value for $1. Use --help for usage." ;;
  esac
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

if [[ $EUID -eq 0 ]]; then
  die "Do not run as root. Run as the target user: sudo -u USERNAME bash install.sh ..."
fi

if [[ -z "$TARGET_USER" ]]; then
  die "Could not determine target user. Pass --user USERNAME."
fi

if [[ "$TARGET_USER" != "$(id -un)" ]]; then
  die "--user ${TARGET_USER} does not match invoking user $(id -un). Run as the target user."
fi

USER_HOME="$HOME"

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
  log_info "  oh-my-zsh, zsh plugins: install if missing"
  log_info "  theme: $THEME (render .tpl templates with theme colors)"
  log_info "  common configs: $(list_config_dirs "${DOTFILES_DIR}/common")"
  log_info "  bat, fd: link ~/.local/bin/{bat,fd} to Debian's batcat, fdfind where only those exist"
  log_info "  npm packages: install from common/npm/packages.conf"
  log_info "  claude-code: install via Anthropic native installer if missing (self-updates)"
  log_info "  workshop: clone/update the private repo over SSH (skipped without access), run its installer"
  log_info "  tmux-plugins ${TMUX_PLUGINS_VERSION} (SHA256SUMS ${TMUX_PLUGINS_SHA256:0:12}…): tmux-warp"
  if [[ "$PROFILE" == "workstation" ]]; then
    log_info "  workstation configs: $(list_config_dirs "${DOTFILES_DIR}/workstation")"
    log_info "  tmux-plugins ${TMUX_PLUGINS_VERSION}: tmux-agent, tmux-revive"
    log_info "  npm packages: install from workstation/npm/packages.conf"
    log_info "  gtk-widgets: clone/update and install from GitHub"
    log_info "  obsidian plugins: install from workstation/obsidian/plugins.conf (if vault exists)"
  fi
  log_info "  dead links: remove symlinks into the repo whose source is gone"
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
link_debian_names "$USER_HOME"
install_npm_packages "${DOTFILES_DIR}/common/npm/packages.conf"
install_claude_code
install_workshop "$USER_HOME"
log_section "Installing tmux-plugins ${TMUX_PLUGINS_VERSION}"
install_release_binary "$USER_HOME" "$TMUX_PLUGINS_REPO" tmux-warp \
  "$TMUX_PLUGINS_VERSION" "$TMUX_PLUGINS_SHA256" tmux-warp.sh

# Deploy workstation configs (workstation profile only)
if [[ "$PROFILE" == "workstation" ]]; then
  deploy_configs "${DOTFILES_DIR}/workstation" "$USER_HOME" "workstation"
  log_section "Installing tmux-plugins ${TMUX_PLUGINS_VERSION} (workstation)"
  install_release_binary "$USER_HOME" "$TMUX_PLUGINS_REPO" tmux-agent \
    "$TMUX_PLUGINS_VERSION" "$TMUX_PLUGINS_SHA256"
  install_release_binary "$USER_HOME" "$TMUX_PLUGINS_REPO" tmux-revive \
    "$TMUX_PLUGINS_VERSION" "$TMUX_PLUGINS_SHA256"
  install_npm_packages "${DOTFILES_DIR}/workstation/npm/packages.conf"
  install_gtk_widgets "$USER_HOME" "$THEME"
  install_obsidian_plugins "$USER_HOME"
fi

# Remove symlinks left behind by scripts or configs deleted or renamed in the repo
prune_dead_links "$USER_HOME"

log_section "Done"
log_info "Dotfiles deployed for $TARGET_USER ($PROFILE profile)."
log_info "Re-run this script anytime to update symlinks."

# --- Post-install reminders ---
while IFS= read -r msg; do
  log_warn "Reminder: $msg"
done < <(pending_reminders "${USER_HOME}/.local/state/dotfiles/completed" \
  "${DOTFILES_DIR}/reminders/common.txt" "${DOTFILES_DIR}/reminders/${PROFILE}.txt")
