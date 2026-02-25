#!/usr/bin/env bash
# lib/helpers.sh — Idempotent config deployment helpers

# Create a symlink from source to target.
# If target exists and is not already the correct symlink, back it up.
# Usage: link_config "/path/to/source" "/path/to/target"
link_config() {
  local src="$1"
  local target="$2"

  if [[ ! -e "$src" ]]; then
    log_warn "Source does not exist, skipping: $src"
    return 0
  fi

  # Already correctly linked
  if [[ -L "$target" ]]; then
    local current
    current="$(readlink -f "$target")"
    local expected
    expected="$(readlink -f "$src")"
    if [[ "$current" == "$expected" ]]; then
      log_info "Already linked: $target"
      return 0
    fi
  fi

  # Back up existing file/directory (not a symlink to our source)
  if [[ -e "$target" || -L "$target" ]]; then
    local backup
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "Backing up existing: $target → $backup"
    mv "$target" "$backup"
  fi

  # Ensure parent directory exists
  ensure_dir "$(dirname "$target")"

  ln -sf "$src" "$target"
  log_info "Linked: $target → $src"
}

# Create directory if it doesn't exist.
# Usage: ensure_dir "/path/to/dir"
ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
}

# Install oh-my-zsh for a user if not already present.
# Usage: install_omz "/home/username"
install_omz() {
  local user_home="$1"

  if [[ -d "${user_home}/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh already installed, skipping."
    return 0
  fi

  log_info "Installing oh-my-zsh..."

  # Run as the target user if we're root, otherwise run directly
  if [[ $EUID -eq 0 && -n "${TARGET_USER:-}" ]]; then
    sudo -u "$TARGET_USER" bash -c '
      set -euo pipefail
      export RUNZSH=no
      export CHSH=no
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    '
  else
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  log_info "oh-my-zsh installed."
}

# Deploy all config files/directories from a source directory.
# Maps each child of source_dir to the appropriate target location.
# Usage: deploy_configs "/path/to/dotfiles/common" "/home/username" "common"
deploy_configs() {
  local source_dir="$1"
  local user_home="$2"
  local config_type="$3"  # "common" or "workstation"

  if [[ ! -d "$source_dir" ]]; then
    log_warn "Config directory not found: $source_dir"
    return 0
  fi

  log_section "Deploying ${config_type} configs"

  local item
  for item in "${source_dir}"/*/; do
    [[ ! -d "$item" ]] && continue
    local name
    name="$(basename "$item")"

    case "$name" in
      # Files that go directly in $HOME (not .config)
      zsh)
        link_config "${item}.zshrc" "${user_home}/.zshrc"
        ;;
      git)
        link_config "${item}.gitconfig" "${user_home}/.gitconfig"
        ;;
      # Theming has nested subdirectories
      theming)
        local subdir
        for subdir in "${item}"/*/; do
          [[ ! -d "$subdir" ]] && continue
          local subname
          subname="$(basename "$subdir")"
          link_config "$subdir" "${user_home}/.config/${subname}"
        done
        ;;
      # Everything else goes into ~/.config/<name>
      *)
        link_config "$item" "${user_home}/.config/${name}"
        ;;
    esac
  done
}
