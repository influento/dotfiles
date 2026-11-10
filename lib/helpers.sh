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
      # Same file, but the link text differs (a trailing slash left by an
      # older deploy_configs): rewrite the link so it reads cleanly.
      if [[ "$(readlink "$target")" != "$src" ]]; then
        ln -sfn "$src" "$target"
        log_info "Relinked: $target → $src"
      else
        log_info "Already linked: $target"
      fi
      return 0
    fi
    # Our own link to another path in this repo (a source moved or
    # renamed): nothing to keep, and prune_dead_links would delete a backup.
    if [[ "$(readlink "$target")" == "${DOTFILES_DIR}"/* ]]; then
      ln -sfn "$src" "$target"
      log_info "Relinked: $target → $src"
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

# Deep-merge a tracked JSON config over an app-managed one, in place.
#
# Used instead of link_config for files the application rewrites itself.
# Claude Code saves settings by writing a temp file and rename()-ing it over
# the target, which replaces a symlink rather than writing through it — so a
# symlinked ~/.claude/settings.json silently degrades into a stale copy on the
# first settings change. A hard link breaks identically; a bind mount makes the
# write fail with EBUSY.
#
# Merge semantics: our tracked values win for every key we define (arrays are
# replaced wholesale, so deleting an entry upstream deletes it here, and the
# log names every live entry that goes), while keys only the app knows about
# (enabledPlugins, feature flags, onboarding state) survive untouched. The
# merge only adds and overrides — deleting a whole key from the tracked file
# does NOT remove it from the live one.
#
# Usage: merge_json_config "/path/to/tracked.json" "/path/to/live.json"
merge_json_config() {
  local src="$1"
  local target="$2"

  if [[ ! -e "$src" ]]; then
    log_warn "Source does not exist, skipping: $src"
    return 0
  fi

  ensure_dir "$(dirname "$target")"

  local merged dropped rc=0
  merged="$(mktemp)"
  dropped="$(mktemp)"

  if ! command -v python3 &>/dev/null; then
    # The tracked copy wins outright; the backup below keeps the live one.
    log_warn "python3 not found — copying $src over $target without merging"
    cp "$src" "$merged"
    if cmp -s "$src" "$target"; then
      rc=3
    fi
  else
    # A live file that is not a JSON object (corrupt, or [] or null) is
    # rebuilt from the tracked copy; the backup below keeps the original.
    if [[ -e "$target" ]] && ! python3 -c 'import json,sys; sys.exit(not isinstance(json.load(open(sys.argv[1])), dict))' "$target" 2>/dev/null; then
      log_warn "$target is not a JSON object — rebuilding it from $src"
    fi

    # stdout is the merged document; stderr lists every live list entry the
    # tracked copy replaces away, one "path: entry" per line, logged below.
    # Exit 3: the live file already holds the merged content.
    python3 - "$src" "$target" >"$merged" 2>"$dropped" <<'PY' || rc=$?
import json
import sys


def deep_merge(base, over):
    """Recursively overlay `over` onto `base`; non-dict values replace."""
    out = dict(base)
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = deep_merge(out[key], value)
        else:
            out[key] = value
    return out


def dropped_entries(base, over, path=""):
    """Yield (path, entry) for each list entry in `base` that `over` replaces away."""
    for key, value in over.items():
        here = f"{path}.{key}" if path else key
        current = base.get(key)
        if isinstance(value, dict) and isinstance(current, dict):
            yield from dropped_entries(current, value, here)
        elif isinstance(value, list) and isinstance(current, list):
            for entry in current:
                if entry not in value:
                    yield here, entry


src_path, target_path = sys.argv[1], sys.argv[2]

with open(src_path, encoding="utf-8") as handle:
    tracked = json.load(handle)

try:
    with open(target_path, encoding="utf-8") as handle:
        live = json.load(handle)
except (FileNotFoundError, json.JSONDecodeError, UnicodeDecodeError):
    live = None
base = live if isinstance(live, dict) else {}

merged = deep_merge(base, tracked)
# Compared parsed, not as text: Claude Code may lay the file out differently.
if merged == live:
    sys.exit(3)

for path, entry in dropped_entries(base, tracked):
    print(f"{path}: {json.dumps(entry, ensure_ascii=False)}", file=sys.stderr)

json.dump(merged, sys.stdout, indent=2, ensure_ascii=False)
sys.stdout.write("\n")
PY
  fi

  case "$rc" in
    0) ;;
    3)
      rm -f "$merged" "$dropped"
      log_info "Already current: $target"
      return 0
      ;;
    *)
      log_warn "Could not build merged config from $src — leaving $target untouched: $(tail -n 1 "$dropped")"
      rm -f "$merged" "$dropped"
      return 0
      ;;
  esac

  if [[ -e "$target" ]]; then
    local backup
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$backup"
    log_warn "Backing up existing: $target → $backup"
  fi

  # Arrays are replaced wholesale, so an entry only the live file had (a
  # permission allowed from inside Claude Code, say) is gone after this write.
  # Name each one; the backup above still holds it.
  local line
  while IFS= read -r line; do
    log_warn "Dropped from $target, not in $src: $line"
  done <"$dropped"

  install -m 600 "$merged" "$target"
  rm -f "$merged" "$dropped"
  log_info "Wrote: $target (from $src)"
}

# Create directory if it doesn't exist.
# Usage: ensure_dir "/path/to/dir"
ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
}

# Remove symlinks that point into this dotfiles repo but whose targets no
# longer exist (a script or config deleted or renamed in the repo). Scans one
# level of each directory deploy_configs links into: $HOME dotfiles,
# ~/.local/bin, ~/.local/share/applications, ~/.config and ~/.claude.
# Usage: prune_dead_links "/home/username"
prune_dead_links() {
  local user_home="$1"
  local dir link target

  for dir in "$user_home" "${user_home}/.local/bin" "${user_home}/.local/share/applications" \
    "${user_home}/.config" "${user_home}/.claude"; do
    [[ -d "$dir" ]] || continue
    for link in "$dir"/* "$dir"/.[!.]*; do
      [[ -L "$link" ]] || continue
      target="$(readlink "$link")"
      [[ "$target" == "${DOTFILES_DIR}"/* ]] || continue
      if [[ ! -e "$link" ]]; then
        log_warn "Pruning dead symlink: ${link} → ${target}"
        rm -f "$link"
      fi
    done
  done
}

# Debian installs bat and fd as batcat and fdfind, while the zsh aliases and
# fzf commands call bat and fd. Link the plain names in ~/.local/bin where
# only the Debian name exists; a real bat or fd elsewhere on PATH wins.
# Usage: link_debian_names "/home/username"
link_debian_names() {
  local user_home="$1"
  local pair name debian_path found

  for pair in bat:batcat fd:fdfind; do
    name="${pair%%:*}"
    debian_path="$(command -v "${pair#*:}" 2>/dev/null)" || continue
    found="$(command -v "$name" 2>/dev/null || true)"
    [[ -z "$found" || "$found" == "${user_home}/.local/bin/${name}" ]] || continue
    ensure_dir "${user_home}/.local/bin"
    link_config "$debian_path" "${user_home}/.local/bin/${name}"
  done
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

  # Download first, then run. `sh -c "$(curl ...)"` runs an empty script when
  # curl fails, so an offline install reported success with nothing installed.
  local installer
  installer="$(mktemp)"
  if ! curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$installer"; then
    rm -f "$installer"
    die "Could not download the oh-my-zsh installer (no network?)"
  fi
  if ! RUNZSH=no CHSH=no sh "$installer"; then
    rm -f "$installer"
    die "oh-my-zsh installer failed"
  fi
  rm -f "$installer"

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

    git clone --depth 1 "https://github.com/${repo}.git" "$dest"

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

      # A failed download warns and moves on; a bare curl would end the
      # whole install under set -e. manifest.json is fetched last, since
      # its presence is what marks the plugin installed on the next run.
      if ! curl -fsSL "${base_url}/main.js" -o "${plugin_dir}/main.js" \
        || ! curl -fsSL "${base_url}/manifest.json" -o "${plugin_dir}/manifest.json"; then
        rm -f "${plugin_dir}/main.js" "${plugin_dir}/manifest.json"
        rmdir "$plugin_dir" 2>/dev/null || true
        log_warn "Failed to download plugin: ${plugin_id}"
        continue
      fi
      curl -fsSL "${base_url}/styles.css" -o "${plugin_dir}/styles.css" 2>/dev/null || true

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

# True when <dir>/SHA256SUMS hashes to <sums-sha256> and lists every <file>
# in <dir> with the sha256 that file has.
# Usage: release_assets_match <dir> <sums-sha256> <file>...
release_assets_match() {
  local dir="$1" sums_sha256="$2"
  shift 2
  local sums="${dir}/SHA256SUMS" file want
  [[ "$(sha256sum "$sums" | cut -d' ' -f1)" == "$sums_sha256" ]] || return 1
  for file in "$@"; do
    want="$(awk -v f="$file" '$2 == f || $2 == "*" f { print $1 }' "$sums")"
    [[ -n "$want" && "$(sha256sum "${dir}/${file}" | cut -d' ' -f1)" == "$want" ]] || return 1
  done
}

# Install one binary from a pinned GitHub release into ~/.local/bin/. The
# release's SHA256SUMS must hash to <sums-sha256>, and each asset must match
# its line there, so one pinned hash covers the whole release. A symlink is a
# dev build (`make dev` in the binary's repo) and is left alone. A binary
# whose --version prints <tag> is current. Otherwise the asset, and [wrapper]
# when given (a release asset installed beside the binary), are downloaded to
# a temp dir, checked and moved into place. A failed download or check keeps
# what is installed.
# Usage: install_release_binary <user-home> <repo> <name> <tag> <sums-sha256> [wrapper]
install_release_binary() {
  local user_home="$1" repo="$2" name="$3" tag="$4" sums_sha256="$5" wrapper="${6:-}"
  local bin_dir="${user_home}/.local/bin"
  local target="${bin_dir}/${name}"

  if [[ -L "$target" ]]; then
    log_warn "${name}: ${target} is a symlink (a dev build), leaving it"
    return 0
  fi
  if [[ -x "$target" && "$(timeout 5 "$target" --version 2>/dev/null)" == "$tag" ]] \
    && [[ -z "$wrapper" || -f "${bin_dir}/${wrapper}" ]]; then
    log_info "${name} ${tag} already installed"
    return 0
  fi

  local arch
  case "$(uname -m)" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) log_warn "${name}: no build for $(uname -m), skipping"; return 0 ;;
  esac

  local asset="${name}-linux-${arch}"
  local -a files=("$asset")
  if [[ -n "$wrapper" ]]; then
    files+=("$wrapper")
  fi

  ensure_dir "$bin_dir"
  local tmp_dir file
  # In bin_dir, so the final mv is a rename: a hook running the old binary
  # never sees a half-written file.
  tmp_dir="$(mktemp -d "${bin_dir}/.${name}.XXXXXX")"
  log_info "Downloading ${name} ${tag} for linux/${arch}..."
  for file in SHA256SUMS "${files[@]}"; do
    if ! curl -fsSL "https://github.com/${repo}/releases/download/${tag}/${file}" -o "${tmp_dir}/${file}"; then
      log_warn "${name}: could not download ${file}, keeping the installed version"
      rm -rf "$tmp_dir"
      return 0
    fi
  done
  if ! release_assets_match "$tmp_dir" "$sums_sha256" "${files[@]}"; then
    log_warn "${name}: ${repo} ${tag} does not match the pinned SHA256SUMS, keeping the installed version"
    rm -rf "$tmp_dir"
    return 0
  fi

  chmod 755 "${tmp_dir}/${asset}"
  mv -f "${tmp_dir}/${asset}" "$target"
  if [[ -n "$wrapper" ]]; then
    chmod 755 "${tmp_dir}/${wrapper}"
    mv -f "${tmp_dir}/${wrapper}" "${bin_dir}/${wrapper}"
  fi
  rm -rf "$tmp_dir"
  log_info "${name} ${tag} installed"
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

# Children of a profile root that deploy_configs does not symlink: handled by
# a dedicated function (obsidian, npm) or read in place from the repo
# (cheatsheets, opened by the _cheat zsh function).
# Usage: is_config_dir_skipped "obsidian"
is_config_dir_skipped() {
  case "$1" in
    obsidian|npm|cheatsheets) return 0 ;;
    *) return 1 ;;
  esac
}

# Print the config names deploy_configs would deploy from a profile root,
# space-separated. The dry-run summary in install.sh uses it so that list
# cannot go stale.
# Usage: list_config_dirs "/path/to/dotfiles/common"
list_config_dirs() {
  local source_dir="$1"
  local -a names=()
  local item name
  for item in "${source_dir}"/*/; do
    [[ -d "$item" ]] || continue
    name="$(basename "$item")"
    is_config_dir_skipped "$name" && continue
    names+=("$name")
  done
  echo "${names[*]:-}"
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
    item="${item%/}"  # the glob leaves a trailing slash; keep link targets clean
    local name
    name="$(basename "$item")"
    is_config_dir_skipped "$name" && continue

    case "$name" in
      # Files that go directly in $HOME (not .config)
      zsh)
        # common/zsh: symlink .zshrc
        # workstation/zsh: symlink .zshrc-workstation
        if [[ "$config_type" == "common" ]]; then
          link_config "${item}/.zshrc" "${user_home}/.zshrc"
          # .zshenv is read by non-interactive shells too (ssh commands),
          # which is what puts ~/.local/bin on PATH for remote invocations.
          link_config "${item}/.zshenv" "${user_home}/.zshenv"
        else
          link_config "${item}/.zshrc-workstation" "${user_home}/.zshrc-workstation"
        fi
        ;;
      git)
        link_config "${item}/.gitconfig" "${user_home}/.gitconfig"
        ;;
      ideavim)
        link_config "${item}/.ideavimrc" "${user_home}/.ideavimrc"
        ;;
      # XDG MIME associations: single file directly in ~/.config/, plus the
      # desktop entry its text and source types point at (see that file's comment)
      mimeapps)
        link_config "${item}/mimeapps.list" "${user_home}/.config/mimeapps.list"
        ensure_dir "${user_home}/.local/share/applications"
        link_config "${item}/nvim-ghostty.desktop" \
          "${user_home}/.local/share/applications/nvim-ghostty.desktop"
        ;;
      # Claude Code: skills dir symlinked, settings.json merged (Claude Code
      # rewrites that file itself and would replace a symlink — see
      # merge_json_config)
      claude-code)
        ensure_dir "${user_home}/.claude"
        link_config "${item}/skills" "${user_home}/.claude/skills"
        merge_json_config "${item}/settings.json" "${user_home}/.claude/settings.json"
        # workshop/workbench/ is a whole tool, not a config: its skills, agents and
        # commands are rendered into a project by its own CLI ('workbench
        # init'), never deployed from here. Only the CLI is, because it is what
        # does the opting in — it has to be runnable before a project can ask
        # for any of the rest.
        ensure_dir "${user_home}/.local/bin"
        link_config "${item}/workshop/workbench/bin/workbench" \
          "${user_home}/.local/bin/workbench"
        # workshop/stack/ likewise: the registry of packages a project may
        # choose (workshop/<language>/packages/) stays here, 'stack add'
        # copies from it.
        link_config "${item}/workshop/stack/bin/stack" \
          "${user_home}/.local/bin/stack"
        ;;
      # Scripts are symlinked individually into ~/.local/bin/
      scripts)
        ensure_dir "${user_home}/.local/bin"
        local script
        for script in "${item}"/*; do
          [[ -f "$script" ]] || continue
          local script_name
          script_name="$(basename "$script")"
          [[ "$script_name" == *.tpl ]] && continue
          # Per-directory docs live beside the scripts; they are not executables
          [[ "$script_name" == *.md ]] && continue
          link_config "$script" "${user_home}/.local/bin/${script_name}"
        done
        ;;
      # Theming has nested subdirectories
      theming)
        local subdir
        for subdir in "${item}"/*/; do
          [[ ! -d "$subdir" ]] && continue
          subdir="${subdir%/}"
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
