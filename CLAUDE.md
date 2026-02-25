# Dotfiles

## Project Overview

Profile-driven, idempotent dotfiles manager for user-level configuration. Part of a
three-repo architecture:

1. **arch-workstation** — Arch Linux workstation installer (system-level only)
2. **debian-server** — Debian server installer (system-level only)
3. **dotfiles** (this repo) — User-level configuration (shell, editor, tools, desktop)

OS repositories are responsible only for system-level concerns: base installation,
package manager operations, services, and required packages. They must not contain
user configuration or tool-specific setup logic.

This repository is responsible only for user-level configuration. It is profile-driven
and idempotent so it can be safely re-run at any time.

## How It Works

### Invocation

Each OS installer clones this repository and executes it with the appropriate profile:

```bash
# From the OS installer (as root, targeting a specific user):
git clone <DOTFILES_REPO_URL> /home/<username>/.dotfiles
bash /home/<username>/.dotfiles/install.sh --profile server --user <username>

# Or run manually as a regular user:
bash ~/.dotfiles/install.sh --profile workstation
```

### Profiles

| Profile | What gets deployed |
|---|---|
| `server` | Common configs only: zsh, neovim, tmux, git, starship |
| `workstation` | Common + workstation: adds hyprland, waybar, ghostty, theming |

### Deployment Method

Configs are deployed as **symlinks** from `~/.config/<tool>` → `<dotfiles>/<profile>/<tool>`.
This means:
- Changes to dotfiles are immediately reflected (no copy/sync needed)
- `git diff` inside the dotfiles repo shows all config changes
- Re-running `install.sh` is safe (idempotent — existing correct symlinks are skipped)
- Existing files are backed up with a timestamp before being replaced

### Config Mapping

| Source | Target | Profile |
|---|---|---|
| `common/zsh/.zshrc` | `~/.zshrc` | all |
| `common/nvim/` | `~/.config/nvim/` | all |
| `common/tmux/` | `~/.config/tmux/` | all |
| `common/git/.gitconfig` | `~/.gitconfig` | all |
| `common/starship/` | `~/.config/starship/` | all |
| `workstation/hypr/` | `~/.config/hypr/` | workstation |
| `workstation/waybar/` | `~/.config/waybar/` | workstation |
| `workstation/ghostty/` | `~/.config/ghostty/` | workstation |
| `workstation/theming/gtk-3.0/` | `~/.config/gtk-3.0/` | workstation |
| `workstation/theming/qt6ct/` | `~/.config/qt6ct/` | workstation |

## Current Status

**Scaffold state** — directory structure and install.sh are complete. All config files
are empty scaffolds with TODOs describing what to add.

**What works:**
- `install.sh` — profile selection, oh-my-zsh installation, symlink deployment
- `lib/helpers.sh` — idempotent link_config, backup existing, deploy_configs
- `lib/log.sh` — colored logging

**What needs content:**
- All config files in `common/` and `workstation/` are scaffolds with TODOs

## What Each Tool Does

### Common (all profiles)

| Tool | Config location | Purpose |
|---|---|---|
| **zsh + oh-my-zsh** | `common/zsh/.zshrc` | Shell: plugins, aliases, environment, prompt theme |
| **Neovim** | `common/nvim/init.lua` | Editor: keymaps, plugins (lazy.nvim), options |
| **tmux** | `common/tmux/tmux.conf` | Terminal multiplexer: prefix key, panes, status bar |
| **Git** | `common/git/.gitconfig` | Version control: user identity, aliases, defaults |
| **Starship** | `common/starship/starship.toml` | Cross-shell prompt: segments, theme, icons |

### Workstation only

| Tool | Config location | Purpose |
|---|---|---|
| **Hyprland** | `workstation/hypr/hyprland.conf` | Wayland compositor: keybindings, monitors, workspaces, animations |
| **Waybar** | `workstation/waybar/config`, `style.css` | Status bar: modules (clock, workspaces, tray), CSS styling |
| **Ghostty** | `workstation/ghostty/config` | Terminal emulator: font, theme, window settings |
| **GTK theming** | `workstation/theming/gtk-3.0/settings.ini` | GTK3 apps: theme, icons, cursor, font |
| **Qt theming** | `workstation/theming/qt6ct/qt6ct.conf` | Qt6 apps: Kvantum style, icons (requires qt6ct env var from OS installer) |
| **SDDM** | `workstation/sddm/` | Display manager theme (placeholder, future) |

## Integration with OS Repos

### How OS Repos Invoke Dotfiles

Both OS repos have a `DOTFILES_REPO` variable in their `config.sh`:

```bash
# In the OS repo's config.sh:
DOTFILES_REPO="https://github.com/<user>/dotfiles.git"
DOTFILES_DEST="/home/${USERNAME}/.dotfiles"
```

The OS installer's `profiles/base.sh` clones and runs:

```bash
if [[ -n "$DOTFILES_REPO" ]]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DEST"
  bash "${DOTFILES_DEST}/install.sh" --profile "$PROFILE" --user "$USERNAME"
fi
```

### What Stays in OS Repos (NOT here)

- Package installation (`pacman`/`apt-get`)
- User creation and shell assignment (`useradd -s /usr/bin/zsh`)
- Service enablement (`systemctl enable`)
- System-wide env vars (`/etc/environment`)
- Hardware config (GPU drivers, bootloader, initramfs)
- Firewall rules, SSH server config
- Docker installation and group membership

### What Lives Here (NOT in OS repos)

- Everything in `~/.config/`
- `~/.zshrc`, `~/.gitconfig`
- oh-my-zsh installation
- Tool-specific configuration and customization

## Code Conventions

- All scripts use `#!/usr/bin/env bash` shebang
- Every script starts with `set -euo pipefail`
- Use `shellcheck`-clean bash
- Use `shellcheck -x` to follow source directives
- Indent with 2 spaces, no tabs
- Functions use `snake_case`
- Quote all variable expansions

## File Organization

```
dotfiles/
├── install.sh                   # Entry point: --profile server|workstation
├── lib/
│   ├── log.sh                   # Colored logging
│   └── helpers.sh               # Symlink helpers, oh-my-zsh installer
├── common/                      # Shared configs (all profiles)
│   ├── zsh/.zshrc
│   ├── nvim/init.lua
│   ├── tmux/tmux.conf
│   ├── git/.gitconfig
│   └── starship/starship.toml
├── workstation/                 # Workstation-only configs
│   ├── hypr/hyprland.conf
│   ├── waybar/config, style.css
│   ├── ghostty/config
│   ├── theming/gtk-3.0/, qt6ct/
│   └── sddm/
└── docs/
    └── TODO.md
```

## Commands

- Lint: `shellcheck -x install.sh lib/*.sh`
- Deploy (server): `bash install.sh --profile server --user myuser`
- Deploy (workstation): `bash install.sh --profile workstation --user myuser`
- Dry run: `bash install.sh --profile server --dry-run`

## Adding New Configs

1. Create a directory under `common/` (all profiles) or `workstation/` (desktop only)
2. Add config files inside it
3. If the target path follows `~/.config/<name>/`, it works automatically via `deploy_configs`
4. If the target path is special (like `~/.zshrc`), add a case to `deploy_configs` in `lib/helpers.sh`
5. Update the mapping table in this CLAUDE.md
6. Run `shellcheck -x install.sh lib/*.sh` to verify

## Changes Required in OS Repos

When this dotfiles repo is moved to its own repository and pushed to GitHub, the following
changes are needed in the OS installer repos:

### arch-install (already done)
- `config.sh`: `DOTFILES_REPO` and `DOTFILES_DEST` variables added
- `profiles/base.sh`: `setup_zsh()` removed, `deploy_dotfiles()` added
- `CLAUDE.md`: dotfiles integration documented
- Set `DOTFILES_REPO="https://github.com/<user>/dotfiles.git"` in config.sh or test configs

### debian-server (needs manual update)
Apply the same pattern:

1. **`config.sh`** — add these variables:
   ```bash
   DOTFILES_REPO="${DOTFILES_REPO:-}"
   DOTFILES_DEST="${DOTFILES_DEST:-}"
   ```

2. **`profiles/base.sh`** — replace `setup_zsh()` with `deploy_dotfiles()`:
   ```bash
   run_base_profile() {
     log_section "Base Profile Setup"
     deploy_dotfiles
     log_info "Base profile setup complete."
   }

   deploy_dotfiles() {
     if [[ -z "${DOTFILES_REPO:-}" ]]; then
       log_warn "DOTFILES_REPO not set — skipping dotfiles deployment."
       return 0
     fi
     local dest="${DOTFILES_DEST:-/home/${USERNAME}/.dotfiles}"
     if [[ -d "$dest" ]]; then
       sudo -u "$USERNAME" git -C "$dest" pull --ff-only || log_warn "Pull failed."
     else
       sudo -u "$USERNAME" git clone "$DOTFILES_REPO" "$dest"
     fi
     bash "${dest}/install.sh" --profile server --user "$USERNAME"
   }
   ```

3. **`CLAUDE.md`** — add dotfiles integration section (same as arch-install's)

4. **`tests/vm-server.conf`** — add `DOTFILES_REPO` once available
