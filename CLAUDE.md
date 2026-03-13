# Dotfiles

## Project Overview

Profile-driven, idempotent dotfiles manager for user-level configuration. Part of a
three-repo architecture:

1. **arch-install** — Arch Linux workstation installer (system-level only)
2. **debian-server** — Debian server installer (system-level only)
3. **dotfiles** (this repo) — User-level configuration (shell, editor, tools, desktop)

OS repositories are responsible only for system-level concerns: base installation,
package manager operations, services, and required packages. They must not contain
user configuration or tool-specific setup logic.

This repository is responsible only for user-level configuration. It is profile-driven
and idempotent so it can be safely re-run at any time.

## How It Works

### Profiles

| Profile       | What gets deployed                                        |
| ------------- | --------------------------------------------------------- |
| `server`      | Common configs only: zsh, neovim, tmux, git, starship     |
| `workstation` | Common + workstation: adds sway, waybar, ghostty, theming |

### Deployment Method

Configs are deployed as **symlinks** from `~/.config/<tool>` → `<dotfiles>/<profile>/<tool>`.
This means:

- Changes to dotfiles are immediately reflected (no copy/sync needed)
- `git diff` inside the dotfiles repo shows all config changes
- Re-running `install.sh` is safe (idempotent — existing correct symlinks are skipped)
- Existing files are backed up with a timestamp before being replaced

### Config Mapping

| Source                              | Target                                    | Profile     |
| ----------------------------------- | ----------------------------------------- | ----------- |
| `common/zsh/.zshrc.tpl`             | `~/.zshrc` (via generated `.zshrc`)       | all         |
| `common/nvim/`                      | `~/.config/nvim/`                         | all         |
| `common/tmux/`                      | `~/.config/tmux/`                         | all         |
| `common/git/.gitconfig`             | `~/.gitconfig`                            | all         |
| `common/starship/`                  | `~/.config/starship/`                     | all         |
| `common/fontconfig/`                | `~/.config/fontconfig/`                   | all         |
| `common/lazygit/`                   | `~/.config/lazygit/`                      | all         |
| `common/btop/`                      | `~/.config/btop/`                         | all         |
| `common/fastfetch/`                 | `~/.config/fastfetch/`                    | all         |
| `common/yazi/`                      | `~/.config/yazi/`                         | all         |
| `common/claude-code/settings.json`  | `~/.claude/settings.json`                 | all         |
| `common/claude-code/skills/`        | `~/.claude/skills/`                       | all         |
| `common/npm/packages.conf`          | global npm packages (installed via npm)   | all         |
| `common/scripts/*`                  | `~/.local/bin/*`                          | all         |
| `workstation/sway/`                 | `~/.config/sway/`                         | workstation |
| `workstation/swaylock/`             | `~/.config/swaylock/`                     | workstation |
| `workstation/swayidle/`             | `~/.config/swayidle/`                     | workstation |
| `workstation/mako/`                 | `~/.config/mako/`                         | workstation |
| `workstation/swaybg/`               | `~/.config/swaybg/`                       | workstation |
| `workstation/wlsunset/`             | `~/.config/wlsunset/`                     | workstation |
| `workstation/swayosd/`              | `~/.config/swayosd/`                      | workstation |
| `workstation/cliphist/`             | `~/.config/cliphist/`                     | workstation |
| `workstation/waybar/`               | `~/.config/waybar/`                       | workstation |
| `workstation/ghostty/`              | `~/.config/ghostty/`                      | workstation |
| `workstation/xdg-desktop-portal/`   | `~/.config/xdg-desktop-portal/`           | workstation |
| `workstation/scripts/*`             | `~/.local/bin/*`                          | workstation |
| `workstation/obsidian/plugins.conf` | `~/Dropbox/data-vault/.obsidian/plugins/` | workstation |
| `workstation/theming/gtk-3.0/`      | `~/.config/gtk-3.0/`                      | workstation |
| `workstation/theming/gtk-4.0/`      | `~/.config/gtk-4.0/`                      | workstation |
| `workstation/theming/qt6ct/`        | `~/.config/qt6ct/`                        | workstation |
| `workstation/theming/Kvantum/`      | `~/.config/Kvantum/`                      | workstation |

## Theming System

### How It Works

Colors are centralized in theme palette files under `themes/`. Config files that use
colors are stored as `.tpl` templates with `@@TOKEN@@` placeholders. At install time,
`lib/theme.sh` renders templates into final config files using `sed`.

### Token Syntax

| Token format         | Rendered as                 | Use when                            |
| -------------------- | --------------------------- | ----------------------------------- |
| `@@COLOR_NAME@@`     | `#hexvalue` (hash-prefixed) | CSS, YAML, most configs             |
| `@@COLOR_NAME_RAW@@` | `hexvalue` (bare hex)       | swaylock and tools expecting no `#` |

### Theme Selection

Priority: `--theme` CLI flag > `theme.conf` > fallback (`catppuccin-mocha`)

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

| Template                                     | Generated file       | Token format    |
| -------------------------------------------- | -------------------- | --------------- |
| `common/zsh/.zshrc.tpl`                      | `.zshrc`             | `@@TOKEN@@`     |
| `common/starship/starship.toml.tpl`          | `starship.toml`      | `@@TOKEN@@`     |
| `common/lazygit/config.yml.tpl`              | `config.yml`         | `@@TOKEN@@`     |
| `workstation/mako/config.tpl`                | `config`             | `@@TOKEN@@`     |
| `workstation/swaylock/config.tpl`            | `config`             | `@@TOKEN_RAW@@` |
| `workstation/swayosd/style.css.tpl`          | `style.css`          | `@@TOKEN@@`     |
| `workstation/swaybg/wallpaper.sh.tpl`        | `wallpaper.sh`       | `@@TOKEN@@`     |
| `workstation/theming/gtk-4.0/gtk.css.tpl`    | `gtk.css`            | `@@TOKEN@@`     |
| `workstation/waybar/config.tpl`              | `config`             | `@@TOKEN@@`     |
| `workstation/waybar/style.css.tpl`           | `style.css`          | `@@TOKEN@@`     |
| `workstation/scripts/calendar-popup.tpl`     | `calendar-popup`     | `@@TOKEN@@`     |
| `workstation/scripts/display-popup.tpl`      | `display-popup`      | `@@TOKEN@@`     |
| `workstation/scripts/claude-usage-popup.tpl` | `claude-usage-popup` | `@@TOKEN@@`     |
| `workstation/scripts/bluetooth-popup.tpl`    | `bluetooth-popup`    | `@@TOKEN@@`     |
| `workstation/scripts/power-popup.tpl`        | `power-popup`        | `@@TOKEN@@`     |

## Custom GTK4 Widgets

Custom UI popups and widgets are built with Python + PyGObject (GTK4). This avoids
installing extra packages — `python3` and `gtk4` are already present on workstation
systems (ghostty depends on GTK4).

**How it works:**

- Widget scripts live in `workstation/scripts/` and are deployed to `~/.local/bin/`
- CSS in widgets uses `@@TOKEN@@` placeholders (`.tpl` template) for theme consistency
- `widget-toggle` is a generic toggle script using `flock` to prevent duplicate windows
- Each widget is a self-contained Python file with its own GTK4 setup, CSS, and logic

**Existing widgets:**

- `calendar-popup` — GTK4 calendar opened by clicking waybar clock
- `display-popup` — GTK4 display settings: scale, brightness (laptop), night light temperature
- `claude-usage-popup` — GTK4 usage display with progress bars for Claude subscription
- `bluetooth-popup` — GTK4 Bluetooth device manager with scan, pair, connect/disconnect
- `power-popup` — GTK4 power menu with lock, sleep, reboot, shut down actions

**Rules:**

- Each widget MUST be fully self-contained — all GTK4 boilerplate (LD_PRELOAD,
  layer-shell, backdrop, CSS provider, key handler) lives inside the widget file itself
- Never extract shared base classes or helper modules between widgets
- Always use `widget-toggle <name>` for toggling, never create per-widget toggle scripts
- Every widget container MUST have `border: 1px solid @@SURFACE1@@` and `border-radius: 8px`
  — the border must be on the outermost container so it's flush with the widget edge (no
  inner margins that create a gap between border and content)
- Disable built-in borders and backgrounds on GTK widgets inside the container — the
  container owns the border, background, and rounding

**Adding a new widget:**

1. Create `workstation/scripts/<name>.tpl` with a self-contained Python GTK4 app
2. Use `@@TOKEN@@` placeholders in the CSS string for theme colors
3. Set a unique `application_id` (e.g., `dev.dotfiles.<name>`)
4. Add the generated file to `.gitignore`
5. Wire it up in waybar config via `bash -c "$HOME/.local/bin/widget-toggle <name>"`

## What Needs Content

- `common/nvim/init.lua` — needs lazy.nvim, LSP, treesitter
- `common/tmux/tmux.conf` — needs prefix, status bar, plugins
- `common/git/.gitconfig` — needs aliases, defaults (identity via `~/.gitconfig.local`)
- `workstation/theming/gtk-3.0/settings.ini` — needs theme, icons, font
- `workstation/theming/qt6ct/qt6ct.conf` — needs Kvantum style, icons

## What Each Tool Does

### Common (all profiles)

| Tool                 | Config location                     | Purpose                                                              |
| -------------------- | ----------------------------------- | -------------------------------------------------------------------- |
| **zsh + oh-my-zsh**  | `common/zsh/.zshrc.tpl`             | Shell: plugins, aliases, environment, prompt theme (themed)          |
| **Neovim**           | `common/nvim/init.lua`              | Editor: keymaps, plugins (lazy.nvim), options                        |
| **tmux**             | `common/tmux/tmux.conf`             | Terminal multiplexer: prefix key, panes, status bar                  |
| **Git**              | `common/git/.gitconfig`             | Version control: user identity, aliases, defaults                    |
| **Starship**         | `common/starship/starship.toml.tpl` | Cross-shell prompt: segments, theme, icons (themed)                  |
| **fontconfig**       | `common/fontconfig/fonts.conf`      | Font rendering: hinting, antialiasing, default families              |
| **LazyGit**          | `common/lazygit/config.yml.tpl`     | Terminal git UI: theme, pager, editor (themed)                       |
| **btop**             | `common/btop/btop.conf`             | System monitor: theme, layout, vim keys                              |
| **fastfetch**        | `common/fastfetch/config.jsonc`     | System info display: modules, layout                                 |
| **yazi**             | `common/yazi/yazi.toml`             | File manager: keymaps, appearance overrides                          |
| **setup-github**     | `common/scripts/setup-github`       | First-login setup: SSH key, GitHub auth, git identity, remote switch |
| **Claude Code**      | `common/claude-code/`               | Claude Code: global settings, permissions, custom skills             |
| **npm packages**     | `common/npm/packages.conf`          | Global npm packages: install on deploy, update via auto-update       |
| **scripts (common)** | `common/scripts/`                   | Shared personal scripts → `~/.local/bin/`                            |

### Workstation only

| Tool                      | Config location                                               | Purpose                                                                                              |
| ------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Sway**                  | `workstation/sway/config`                                     | Wayland compositor: keybindings, monitors, workspaces, window rules                                  |
| **Waybar**                | `workstation/waybar/config.tpl`, `style.css.tpl`              | Status bar: modules (clock, workspaces, tray), CSS styling (themed)                                  |
| **Ghostty**               | `workstation/ghostty/config`                                  | Terminal emulator: font, theme, window settings                                                      |
| **swaylock**              | `workstation/swaylock/config.tpl`                             | Screen locker: colors, indicator, behavior (themed)                                                  |
| **swayidle**              | `workstation/swayidle/config`                                 | Idle manager: lock, screen off, suspend timers                                                       |
| **mako**                  | `workstation/mako/config.tpl`                                 | Notification daemon: appearance, urgency, timeouts (themed)                                          |
| **swaybg**                | `workstation/swaybg/wallpaper.sh.tpl`, `wallpapers/`          | Wallpaper: launcher script, image storage (themed)                                                   |
| **wlsunset**              | `workstation/wlsunset/wlsunset.sh`                            | Night light: temperature, location-based schedule                                                    |
| **SwayOSD**               | `workstation/swayosd/style.css.tpl`                           | On-screen display: volume/brightness popup styling (themed)                                          |
| **bluetooth-widget**      | `workstation/scripts/bluetooth-widget`, `bluetooth-popup.tpl` | Bluetooth: waybar module + GTK4 popup for device management (themed)                                 |
| **cliphist**              | `workstation/cliphist/cliphist-pick.sh`                       | Clipboard history: picker script (wofi)                                                              |
| **Obsidian plugins**      | `workstation/obsidian/plugins.conf`                           | Plugin installer: downloads from GitHub releases into vault                                          |
| **GTK theming**           | `workstation/theming/gtk-3.0/settings.ini`                    | GTK3 apps: theme, icons, cursor, font                                                                |
| **Qt theming**            | `workstation/theming/qt6ct/qt6ct.conf`                        | Qt6 apps: Kvantum style, icons (requires qt6ct env var from OS installer)                            |
| **Kvantum**               | `workstation/theming/Kvantum/kvantum.kvconfig`                | Qt theme engine: renders Qt widgets to match GTK theme                                               |
| **XDG desktop portal**    | `workstation/xdg-desktop-portal/portals.conf`                 | Portal backend: routes desktop portals to wlr for Sway                                               |
| **power-popup**           | `workstation/scripts/power-popup.tpl`                         | Power menu: GTK4 popup with lock, sleep, reboot, shut down (themed)                                  |
| **auto-update**           | `workstation/scripts/auto-update`                             | Background system update on sway start: yay -Syu (repos + AUR) with 12h cooldown, mako notifications |
| **drawdesk**              | cloned to `~/.local/src/drawdesk`                             | Desktop Excalidraw editor: Tauri v2 app, built from GitHub on install                                |
| **scripts (workstation)** | `workstation/scripts/`                                        | Desktop-specific scripts → `~/.local/bin/`                                                           |

## Code Conventions

- All scripts use `#!/usr/bin/env bash` shebang
- Every script starts with `set -euo pipefail`
- Use `shellcheck`-clean bash
- Use `shellcheck -x` to follow source directives
- Indent with 2 spaces, no tabs
- Functions use `snake_case`
- Quote all variable expansions
- Never add `Co-Authored-By` trailers to git commits
- Before every commit/push, audit the staged diff for sensitive information leaks:
  usernames, passwords, API keys, tokens, private IPs, email addresses, or any
  data that should not appear in a public repository. Flag any findings to the user
  before proceeding

## Commands

- Lint: `shellcheck -x install.sh lib/*.sh themes/*.sh`
- Deploy (server): `bash install.sh --profile server --user myuser`
- Deploy (workstation): `bash install.sh --profile workstation --user myuser`
- Dry run: `bash install.sh --profile server --dry-run`

## Codebase Size (baseline: 2026-03-06)

~56,300 tokens total (~44,600 deduplicated, excluding generated files).

| Area                                     | Est. Tokens |
| ---------------------------------------- | ----------- |
| `workstation/scripts/` (widgets)         | ~27,200     |
| `common/`                                | ~12,200     |
| `workstation/` (non-scripts)             | ~6,700      |
| Root files (CLAUDE.md, install.sh, etc.) | ~5,400      |
| `lib/`                                   | ~3,200      |
| `docs/` + `themes/`                      | ~1,600      |

Widgets account for ~48% of the codebase. Binary files (wallpapers, 8.3 MB) excluded.

## Editing Configs

**IMPORTANT: Never use the Write tool for files that contain or will contain Nerd Font
icons** (U+F0000–U+F9999). The Write tool silently strips multi-byte UTF-8 icon
characters. This applies to both editing existing files AND creating new files.

- **Editing existing files with icons**: Use the Edit tool for targeted changes
- **Creating new files with icons**: Use Bash heredoc (`cat << 'EOF' > file`)
- **Common icon locations**: waybar scripts, sway config, any script that outputs
  waybar JSON (format strings with icon glyphs), widget templates with icon literals

When modifying any config, follow this workflow:

1. **Check if the config is a template** — look for a `.tpl` file. If it exists, edit
   the `.tpl`, never the generated file (it will be overwritten on next install)
2. **Use theme tokens for colors** — any hardcoded hex color that comes from the theme
   palette must use `@@TOKEN@@` (hash-prefixed) or `@@TOKEN_RAW@@` (bare hex) placeholders.
   Never hardcode theme colors in a config that could be a template
3. **If adding colors to a non-template config** — convert it to a template first
   (see "Adding Colors to a Config" above), add the generated file to `.gitignore`,
   and update the Template Files table
4. **Check `docs/references.md`** for official documentation links before making changes
   to any tool config — especially after tool upgrades that may introduce breaking changes
5. **Run `install.sh`** after template changes to regenerate files and verify rendering

### Adding New Configs

1. Create a directory under `common/` (all profiles) or `workstation/` (desktop only)
2. Add config files inside it
3. If the config uses theme colors, use a `.tpl` template (see "Adding Colors to a Config" above)
4. If the target path follows `~/.config/<name>/`, it works automatically via `deploy_configs`
5. If the target path is special (like `~/.zshrc`), add a case to `deploy_configs` in `lib/helpers.sh`
6. Update the mapping table in this CLAUDE.md
7. Run `shellcheck -x install.sh lib/*.sh themes/*.sh` to verify

## Documentation

- **`docs/references.md`** — official doc links and config format notes for every tool.
  Consult before modifying configs, especially after package upgrades.
