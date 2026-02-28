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
git clone <DOTFILES_REPO_URL> /home/<username>/dev/infra/dotfiles
bash /home/<username>/dev/infra/dotfiles/install.sh --profile server --user <username>

# Or run manually as a regular user:
bash ~/dev/infra/dotfiles/install.sh --profile workstation
```

### Profiles

| Profile | What gets deployed |
|---|---|
| `server` | Common configs only: zsh, neovim, tmux, git, starship |
| `workstation` | Common + workstation: adds sway, waybar, ghostty, theming |

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
| `common/fontconfig/` | `~/.config/fontconfig/` | all |
| `common/lazygit/` | `~/.config/lazygit/` | all |
| `common/btop/` | `~/.config/btop/` | all |
| `common/fastfetch/` | `~/.config/fastfetch/` | all |
| `common/yazi/` | `~/.config/yazi/` | all |
| `common/scripts/*` | `~/.local/bin/*` | all |
| `workstation/sway/` | `~/.config/sway/` | workstation |
| `workstation/swaylock/` | `~/.config/swaylock/` | workstation |
| `workstation/swayidle/` | `~/.config/swayidle/` | workstation |
| `workstation/mako/` | `~/.config/mako/` | workstation |
| `workstation/swaybg/` | `~/.config/swaybg/` | workstation |
| `workstation/wlsunset/` | `~/.config/wlsunset/` | workstation |
| `workstation/swayosd/` | `~/.config/swayosd/` | workstation |
| `workstation/cliphist/` | `~/.config/cliphist/` | workstation |
| `workstation/waybar/` | `~/.config/waybar/` | workstation |
| `workstation/ghostty/` | `~/.config/ghostty/` | workstation |
| `workstation/xdg-desktop-portal/` | `~/.config/xdg-desktop-portal/` | workstation |
| `workstation/scripts/*` | `~/.local/bin/*` | workstation |
| `workstation/obsidian/plugins.conf` | `~/dropbox/data-vault/.obsidian/plugins/` | workstation |
| `workstation/theming/gtk-3.0/` | `~/.config/gtk-3.0/` | workstation |
| `workstation/theming/gtk-4.0/` | `~/.config/gtk-4.0/` | workstation |
| `workstation/theming/qt6ct/` | `~/.config/qt6ct/` | workstation |
| `workstation/theming/Kvantum/` | `~/.config/Kvantum/` | workstation |

## Theming System

### How It Works

Colors are centralized in theme palette files under `themes/`. Config files that use
colors are stored as `.tpl` templates with `@@TOKEN@@` placeholders. At install time,
`lib/theme.sh` renders templates into final config files using `sed`.

### Token Syntax

| Token format | Rendered as | Use when |
|---|---|---|
| `@@COLOR_NAME@@` | `#hexvalue` (hash-prefixed) | CSS, YAML, most configs |
| `@@COLOR_NAME_RAW@@` | `hexvalue` (bare hex) | swaylock and tools expecting no `#` |

### Theme Selection

Priority: `--theme` CLI flag > `theme.conf` > fallback (`catppuccin-mocha`)

```bash
# Use default theme from theme.conf:
bash install.sh --profile workstation

# Override theme:
bash install.sh --profile workstation --theme catppuccin-mocha
```

### Adding a New Theme

1. Copy `themes/catppuccin-mocha.sh` to `themes/<name>.sh`
2. Update `THEME_META` (NAME, DISPLAY_NAME) and all `THEME_COLORS` values
3. Set `THEME=<name>` in `theme.conf` or pass `--theme <name>`
4. Run `bash install.sh --profile workstation` to regenerate configs

### Adding Colors to a Config

1. Rename the config file to `<name>.tpl` (e.g., `config` → `config.tpl`)
2. Replace hardcoded hex colors with `@@TOKEN@@` or `@@TOKEN_RAW@@` tokens
3. Add the generated file path to `.gitignore`
4. The generated file will be created alongside the template at install time

### Template Files

| Template | Generated file | Token format |
|---|---|---|
| `common/lazygit/config.yml.tpl` | `config.yml` | `@@TOKEN@@` |
| `workstation/mako/config.tpl` | `config` | `@@TOKEN@@` |
| `workstation/swaylock/config.tpl` | `config` | `@@TOKEN_RAW@@` |
| `workstation/swayosd/style.css.tpl` | `style.css` | `@@TOKEN@@` |
| `workstation/swaybg/wallpaper.sh.tpl` | `wallpaper.sh` | `@@TOKEN@@` |
| `workstation/theming/gtk-4.0/gtk.css.tpl` | `gtk.css` | `@@TOKEN@@` |

## Current Status

**What works:**
- `install.sh` — profile selection, oh-my-zsh installation, theme rendering, symlink deployment
- `lib/helpers.sh` — idempotent link_config, backup existing, deploy_configs, obsidian plugin installer
- `lib/log.sh` — colored logging
- `lib/theme.sh` — template rendering engine with `@@TOKEN@@` replacement
- `themes/catppuccin-mocha.sh` — full Catppuccin Mocha palette (31 colors)
- 5 themed config files (lazygit, mako, swaylock, swayosd, swaybg)
- Real configs: lazygit, mako, swaylock, swayosd, swaybg, wlsunset, cliphist,
  btop, fastfetch, fontconfig, swayidle, sway, waybar, ghostty, xdg-desktop-portal

**What needs content (scaffolds with TODOs):**
- `common/zsh/.zshrc` — needs plugins, aliases, environment
- `common/nvim/init.lua` — needs lazy.nvim, LSP, treesitter
- `common/tmux/tmux.conf` — needs prefix, status bar, plugins
- `common/git/.gitconfig` — needs aliases, defaults (identity via `~/.gitconfig.local`)
- `common/starship/starship.toml` — needs prompt segments
- `workstation/theming/gtk-3.0/settings.ini` — needs theme, icons, font
- `workstation/theming/qt6ct/qt6ct.conf` — needs Kvantum style, icons

## What Each Tool Does

### Common (all profiles)

| Tool | Config location | Purpose |
|---|---|---|
| **zsh + oh-my-zsh** | `common/zsh/.zshrc` | Shell: plugins, aliases, environment, prompt theme |
| **Neovim** | `common/nvim/init.lua` | Editor: keymaps, plugins (lazy.nvim), options |
| **tmux** | `common/tmux/tmux.conf` | Terminal multiplexer: prefix key, panes, status bar |
| **Git** | `common/git/.gitconfig` | Version control: user identity, aliases, defaults |
| **Starship** | `common/starship/starship.toml` | Cross-shell prompt: segments, theme, icons |
| **fontconfig** | `common/fontconfig/fonts.conf` | Font rendering: hinting, antialiasing, default families |
| **LazyGit** | `common/lazygit/config.yml.tpl` | Terminal git UI: theme, pager, editor (themed) |
| **btop** | `common/btop/btop.conf` | System monitor: theme, layout, vim keys |
| **fastfetch** | `common/fastfetch/config.jsonc` | System info display: modules, layout |
| **yazi** | `common/yazi/yazi.toml` | File manager: keymaps, appearance overrides |
| **setup-github** | `common/scripts/setup-github` | First-login setup: SSH key, GitHub auth, git identity, remote switch |
| **scripts (common)** | `common/scripts/` | Shared personal scripts → `~/.local/bin/` |

### Workstation only

| Tool | Config location | Purpose |
|---|---|---|
| **Sway** | `workstation/sway/config` | Wayland compositor: keybindings, monitors, workspaces, window rules |
| **Waybar** | `workstation/waybar/config`, `style.css` | Status bar: modules (clock, workspaces, tray), CSS styling |
| **Ghostty** | `workstation/ghostty/config` | Terminal emulator: font, theme, window settings |
| **swaylock** | `workstation/swaylock/config.tpl` | Screen locker: colors, indicator, behavior (themed) |
| **swayidle** | `workstation/swayidle/config` | Idle manager: lock, screen off, suspend timers |
| **mako** | `workstation/mako/config.tpl` | Notification daemon: appearance, urgency, timeouts (themed) |
| **swaybg** | `workstation/swaybg/wallpaper.sh.tpl`, `wallpapers/` | Wallpaper: launcher script, image storage (themed) |
| **wlsunset** | `workstation/wlsunset/wlsunset.sh` | Night light: temperature, location-based schedule |
| **SwayOSD** | `workstation/swayosd/style.css.tpl` | On-screen display: volume/brightness popup styling (themed) |
| **cliphist** | `workstation/cliphist/cliphist-pick.sh` | Clipboard history: picker script (wofi) |
| **Obsidian plugins** | `workstation/obsidian/plugins.conf` | Plugin installer: downloads from GitHub releases into vault |
| **GTK theming** | `workstation/theming/gtk-3.0/settings.ini` | GTK3 apps: theme, icons, cursor, font |
| **Qt theming** | `workstation/theming/qt6ct/qt6ct.conf` | Qt6 apps: Kvantum style, icons (requires qt6ct env var from OS installer) |
| **Kvantum** | `workstation/theming/Kvantum/kvantum.kvconfig` | Qt theme engine: renders Qt widgets to match GTK theme |
| **XDG desktop portal** | `workstation/xdg-desktop-portal/portals.conf` | Portal backend: routes desktop portals to wlr for Sway |
| **scripts (workstation)** | `workstation/scripts/` | Desktop-specific scripts → `~/.local/bin/` |

## Integration with OS Repos

### How OS Repos Invoke Dotfiles

Both OS repos have a `DOTFILES_REPO` variable in their `config.sh`:

```bash
# In the OS repo's config.sh:
DOTFILES_REPO="https://github.com/<user>/dotfiles.git"
DOTFILES_DEST="/home/${USERNAME}/dev/infra/dotfiles"
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
- Never add `Co-Authored-By` trailers to git commits

## File Organization

```
dotfiles/
├── install.sh                   # Entry point: --profile server|workstation [--theme]
├── theme.conf                   # Default theme selection (THEME=catppuccin-mocha)
├── themes/
│   └── catppuccin-mocha.sh      # Palette: THEME_COLORS + THEME_META
├── lib/
│   ├── log.sh                   # Colored logging
│   ├── helpers.sh               # Symlink helpers, oh-my-zsh installer
│   └── theme.sh                 # Theme engine: load, render .tpl, validate
├── common/                      # Shared configs (all profiles)
│   ├── zsh/.zshrc
│   ├── nvim/init.lua
│   ├── tmux/tmux.conf
│   ├── git/.gitconfig
│   ├── starship/starship.toml
│   ├── fontconfig/fonts.conf
│   ├── lazygit/config.yml.tpl   # Themed (generates config.yml)
│   ├── btop/btop.conf
│   ├── fastfetch/config.jsonc
│   ├── yazi/yazi.toml
│   └── scripts/                 # Shared scripts → ~/.local/bin/
├── workstation/                 # Workstation-only configs
│   ├── sway/config
│   ├── waybar/config, style.css
│   ├── ghostty/config
│   ├── mako/config.tpl          # Themed (generates config)
│   ├── swaylock/config.tpl      # Themed (generates config)
│   ├── swayosd/style.css.tpl    # Themed (generates style.css)
│   ├── swaybg/wallpaper.sh.tpl  # Themed (generates wallpaper.sh)
│   ├── obsidian/plugins.conf     # Plugin list → downloaded into vault
│   ├── xdg-desktop-portal/portals.conf
│   ├── theming/gtk-3.0/, qt6ct/, Kvantum/
│   └── scripts/                 # Desktop scripts → ~/.local/bin/
└── docs/
```

## Commands

- Lint: `shellcheck -x install.sh lib/*.sh themes/*.sh`
- Deploy (server): `bash install.sh --profile server --user myuser`
- Deploy (workstation): `bash install.sh --profile workstation --user myuser`
- Dry run: `bash install.sh --profile server --dry-run`

## Adding New Configs

1. Create a directory under `common/` (all profiles) or `workstation/` (desktop only)
2. Add config files inside it
3. If the config uses theme colors, use a `.tpl` template (see "Adding Colors to a Config" above)
4. If the target path follows `~/.config/<name>/`, it works automatically via `deploy_configs`
5. If the target path is special (like `~/.zshrc`), add a case to `deploy_configs` in `lib/helpers.sh`
6. Update the mapping table in this CLAUDE.md
7. Run `shellcheck -x install.sh lib/*.sh themes/*.sh` to verify

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
     local dest="${DOTFILES_DEST:-/home/${USERNAME}/dev/infra/dotfiles}"
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
