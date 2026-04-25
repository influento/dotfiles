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
    current="$(readlink -f "$target" 2>/dev/null)" || current=""
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
    sudo -Hu "$TARGET_USER" bash -c '
      set -euo pipefail
      export RUNZSH=no
      export CHSH=no
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    '
  else
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  # Remove the default .zshrc that oh-my-zsh creates — we deploy our own
  rm -f "${user_home}/.zshrc"

  log_info "oh-my-zsh installed."
}

# Install zsh plugins into oh-my-zsh custom plugins directory.
# Clones zsh-autosuggestions and zsh-syntax-highlighting if not already present.
# Usage: install_zsh_plugins "/home/username"
install_zsh_plugins() {
  local user_home="$1"
  local custom_dir="${user_home}/.oh-my-zsh/custom/plugins"

  if [[ ! -d "${user_home}/.oh-my-zsh" ]]; then
    log_warn "oh-my-zsh not found, skipping zsh plugin installation."
    return 0
  fi

  ensure_dir "$custom_dir"

  local -a plugins=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
  )

  local repo plugin_name dest
  for repo in "${plugins[@]}"; do
    plugin_name="${repo##*/}"
    dest="${custom_dir}/${plugin_name}"

    if [[ -d "$dest" ]]; then
      log_info "zsh plugin already installed: ${plugin_name}"
      continue
    fi

    log_info "Installing zsh plugin: ${plugin_name}..."

    if [[ $EUID -eq 0 && -n "${TARGET_USER:-}" ]]; then
      sudo -Hu "$TARGET_USER" git clone --depth 1 \
        "https://github.com/${repo}.git" "$dest"
    else
      git clone --depth 1 "https://github.com/${repo}.git" "$dest"
    fi

    log_info "zsh plugin installed: ${plugin_name}"
  done
}

# Install Obsidian community plugins from plugins.conf into a vault.
# Downloads plugin assets from GitHub releases if not already installed.
# Updates community-plugins.json to register each plugin.
# Usage: install_obsidian_plugins "/home/username"
install_obsidian_plugins() {
  local user_home="$1"
  local vault_dir="${user_home}/Dropbox/data-vault"
  local plugins_file="${DOTFILES_DIR}/workstation/obsidian/plugins.conf"

  if [[ ! -f "$plugins_file" ]]; then
    log_warn "No plugins.conf found, skipping Obsidian plugins."
    return 0
  fi

  if [[ ! -d "$vault_dir" ]]; then
    log_info "Obsidian vault not found at ${vault_dir}, skipping plugins."
    return 0
  fi

  log_section "Installing Obsidian plugins"

  local plugins_dir="${vault_dir}/.obsidian/plugins"
  ensure_dir "$plugins_dir"

  local community_json="${vault_dir}/.obsidian/community-plugins.json"
  if [[ ! -f "$community_json" ]]; then
    echo '[]' > "$community_json"
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    local repo plugin_id
    repo="$(echo "$line" | awk '{print $1}')"
    plugin_id="$(echo "$line" | awk '{print $2}')"

    if [[ -z "$repo" || -z "$plugin_id" ]]; then
      log_warn "Malformed line in plugins.conf: $line"
      continue
    fi

    local plugin_dir="${plugins_dir}/${plugin_id}"

    if [[ -d "$plugin_dir" && -f "${plugin_dir}/manifest.json" ]]; then
      log_info "Plugin already installed: ${plugin_id}"
    else
      log_info "Installing plugin: ${plugin_id} from ${repo}..."
      ensure_dir "$plugin_dir"

      local base_url="https://github.com/${repo}/releases/latest/download"
      local dl_cmd="curl -fsSL"

      if [[ $EUID -eq 0 && -n "${TARGET_USER:-}" ]]; then
        sudo -u "$TARGET_USER" bash -c "
          set -euo pipefail
          ${dl_cmd} '${base_url}/main.js' -o '${plugin_dir}/main.js'
          ${dl_cmd} '${base_url}/manifest.json' -o '${plugin_dir}/manifest.json'
          ${dl_cmd} '${base_url}/styles.css' -o '${plugin_dir}/styles.css' 2>/dev/null || true
        "
      else
        ${dl_cmd} "${base_url}/main.js" -o "${plugin_dir}/main.js"
        ${dl_cmd} "${base_url}/manifest.json" -o "${plugin_dir}/manifest.json"
        ${dl_cmd} "${base_url}/styles.css" -o "${plugin_dir}/styles.css" 2>/dev/null || true
      fi

      if [[ ! -f "${plugin_dir}/manifest.json" ]]; then
        log_warn "Failed to download plugin: ${plugin_id}"
        continue
      fi

      log_info "Plugin installed: ${plugin_id}"
    fi

    # Register plugin in community-plugins.json if not already present
    if command -v jq &>/dev/null; then
      local already_registered
      already_registered="$(jq -r --arg id "$plugin_id" 'index($id) // empty' "$community_json" 2>/dev/null || true)"
      if [[ -z "$already_registered" ]]; then
        local tmp_json="${community_json}.tmp"
        jq --arg id "$plugin_id" '. + [$id]' "$community_json" > "$tmp_json"
        mv "$tmp_json" "$community_json"
        log_info "Registered ${plugin_id} in community-plugins.json"
      fi
    else
      # Fallback without jq: simple grep check and text manipulation
      if ! grep -q "\"${plugin_id}\"" "$community_json" 2>/dev/null; then
        local current
        current="$(cat "$community_json")"
        if [[ "$current" == "[]" ]]; then
          echo "[\"${plugin_id}\"]" > "$community_json"
        else
          # Replace trailing ] with ,"plugin-id"]
          sed -i "s/\]$/,\"${plugin_id}\"]/" "$community_json"
        fi
        log_info "Registered ${plugin_id} in community-plugins.json"
      fi
    fi
  done < "$plugins_file"
}

# Download tmux plugin binaries from influento/tmux-plugins GitHub Releases.
# Installs each binary into ~/.local/bin/.
# Usage: install_tmux_plugins "/home/username"
install_tmux_plugins() {
  local user_home="$1"
  local bin_dir="${user_home}/.local/bin"
  local repo="influento/tmux-plugins"

  local arch
  case "$(uname -m)" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) log_warn "Unsupported architecture for tmux plugins: $(uname -m), skipping."; return 0 ;;
  esac

  ensure_dir "$bin_dir"

  log_section "Installing tmux plugins"

  local -a plugins=("tmux-warp")
  local plugin
  for plugin in "${plugins[@]}"; do
    local target="${bin_dir}/${plugin}"

    if [[ -x "$target" ]]; then
      log_info "tmux plugin already installed: ${plugin}"
      continue
    fi

    local url="https://github.com/${repo}/releases/latest/download/${plugin}-linux-${arch}"
    log_info "Downloading ${plugin} for linux/${arch}..."

    local dl_cmd="curl -fsSL"
    if [[ $EUID -eq 0 && -n "${TARGET_USER:-}" ]]; then
      sudo -u "$TARGET_USER" bash -c "${dl_cmd} '${url}' -o '${target}' && chmod +x '${target}'"
    else
      ${dl_cmd} "${url}" -o "${target}" && chmod +x "${target}"
    fi

    if [[ -x "$target" ]]; then
      log_info "tmux plugin installed: ${plugin}"
    else
      log_warn "Failed to download tmux plugin: ${plugin}"
      continue
    fi

    # Download shell wrapper if it exists
    local wrapper_url="https://raw.githubusercontent.com/${repo}/main/${plugin}/${plugin}.sh"
    local wrapper_target="${bin_dir}/${plugin}.sh"
    if [[ $EUID -eq 0 && -n "${TARGET_USER:-}" ]]; then
      sudo -u "$TARGET_USER" bash -c "${dl_cmd} '${wrapper_url}' -o '${wrapper_target}' && chmod +x '${wrapper_target}'" 2>/dev/null || true
    else
      ${dl_cmd} "${wrapper_url}" -o "${wrapper_target}" && chmod +x "${wrapper_target}" 2>/dev/null || true
    fi
  done
}

# Clone (or update) and install gtk-widgets from GitHub.
# Symlinks widget scripts into ~/.local/bin/ via the repo's own installer.
# Usage: install_gtk_widgets "/home/username" "theme-name"
install_gtk_widgets() {
  local user_home="$1"
  local theme="$2"
  local repo_url="https://github.com/influento/gtk-widgets.git"
  local install_dir
  install_dir="$(cd "${DOTFILES_DIR}/.." && pwd)/gtk-widgets"

  log_section "Installing gtk-widgets"

  if [[ -d "$install_dir/.git" ]]; then
    git -C "$install_dir" pull --ff-only --quiet 2>/dev/null || true
  else
    git clone --depth 1 "$repo_url" "$install_dir"
  fi

  log_info "Running gtk-widgets installer..."
  (cd "$install_dir" && bash install.sh --theme "$theme")
  log_info "gtk-widgets installed"
}

# Install global npm packages from one or more packages.conf files if not already present.
# Usage: install_npm_packages file1 [file2 ...]
install_npm_packages() {
  if [[ $# -eq 0 ]]; then
    log_warn "install_npm_packages: no package files specified, skipping."
    return 0
  fi

  if ! command -v npm &>/dev/null; then
    log_warn "npm not found, skipping global package installation."
    return 0
  fi

  log_section "Installing global npm packages"

  # Install globals under the user's home so npm never writes to pacman-owned
  # /usr/lib/node_modules. This avoids "exists in filesystem" conflicts when
  # pacman later upgrades node-gyp or its bundled deps. ~/.local/bin is already
  # on PATH, so `-g` binaries resolve the same way as before.
  npm config set prefix "$HOME/.local"

  local installed
  installed="$(npm list -g --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -I{} basename {} || true)"

  local packages_file
  for packages_file in "$@"; do
    if [[ ! -f "$packages_file" ]]; then
      log_warn "No npm packages.conf found at ${packages_file}, skipping."
      continue
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// /}" ]] && continue

      local pkg="$line"
      # Package name for checking: @scope/name → name
      local pkg_short="${pkg##*/}"

      if echo "$installed" | grep -qxF "$pkg_short"; then
        log_info "npm package already installed: ${pkg}"
      else
        log_info "Installing npm package: ${pkg}..."
        npm install -g "$pkg"
        log_info "npm package installed: ${pkg}"
      fi
    done < "$packages_file"
  done
}

# Install Claude Code via Anthropic's native installer if not already present.
# The native installer puts claude in ~/.local/share/claude/versions/ and
# self-updates in the background — no cron step needed. Re-runs are no-ops.
install_claude_code() {
  log_section "Installing Claude Code"

  if command -v claude &>/dev/null; then
    log_info "Claude Code already installed: $(claude --version 2>/dev/null | head -1)"
    return 0
  fi

  log_info "Running Anthropic's native installer..."
  curl -fsSL https://claude.ai/install.sh | bash
  log_info "Claude Code installed"
}

# Deploy all config files/directories from a source directory.
# Maps each child of source_dir to the appropriate target location.
# Usage: deploy_configs "/path/to/dotfiles/common" "/home/username" "common"
deploy_configs() {
  local source_dir="$1"
  local user_home="$2"
  local config_type="$3"  # "common", "server", or "workstation"

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
      # Handled by dedicated functions, not symlinked
      obsidian|npm|systemd)
        continue
        ;;
      # Files that go directly in $HOME (not .config)
      zsh)
        # common/zsh: symlink .zshrc
        # workstation/zsh: symlink .zshrc-workstation
        if [[ "$config_type" == "common" ]]; then
          link_config "${item}.zshrc" "${user_home}/.zshrc"
        else
          link_config "${item}.zshrc-workstation" "${user_home}/.zshrc-workstation"
        fi
        ;;
      git)
        link_config "${item}.gitconfig" "${user_home}/.gitconfig"
        ;;
      ideavim)
        link_config "${item}.ideavimrc" "${user_home}/.ideavimrc"
        ;;
      # XDG MIME associations: single file directly in ~/.config/
      mimeapps)
        link_config "${item}mimeapps.list" "${user_home}/.config/mimeapps.list"
        ;;
      # Claude Code: skills dir + settings.json into ~/.claude/
      claude-code)
        ensure_dir "${user_home}/.claude"
        link_config "${item}skills" "${user_home}/.claude/skills"
        link_config "${item}settings.json" "${user_home}/.claude/settings.json"
        ;;
      # Scripts are symlinked individually into ~/.local/bin/
      scripts)
        ensure_dir "${user_home}/.local/bin"
        local script
        for script in "${item}"*; do
          [[ -f "$script" ]] || continue
          local script_name
          script_name="$(basename "$script")"
          [[ "$script_name" == ".gitkeep" ]] && continue
          link_config "$script" "${user_home}/.local/bin/${script_name}"
        done
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
