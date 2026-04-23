# Dotfiles

## Project Overview

Profile-driven, idempotent dotfiles manager for user-level configuration. Part of a
four-repo architecture:

1. **arch-install** — Arch Linux workstation installer (system-level only)
2. **debian-server** — Debian server installer (system-level only)
3. **dotfiles** (this repo) — User-level configuration (shell, editor, tools, desktop)
4. **gtk-widgets** — Custom GTK4 widgets (Python + PyGObject)

OS repositories are responsible only for system-level concerns: base installation,
package manager operations, services, and required packages. They must not contain
user configuration or tool-specific setup logic.

This repository is responsible only for user-level configuration. It is profile-driven
and idempotent so it can be safely re-run at any time.

## How It Works

### Profiles

| Profile       | What gets deployed                                        |
| ------------- | --------------------------------------------------------- |
| `server`      | Common + server: adds systemd timer for auto-updates      |
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
| `workstation/zsh/.zshrc-workstation`| `~/.zshrc-workstation`                    | workstation |
| `common/nvim/`                      | `~/.config/nvim/`                         | all         |
| `common/tmux/`                      | `~/.config/tmux/`                         | all         |
| `common/git/.gitconfig`             | `~/.gitconfig`                            | all         |
| `common/starship/`                  | `~/.config/starship/`                     | all         |
| `common/fontconfig/`                | `~/.config/fontconfig/`                   | all         |
| `workstation/lazygit/`              | `~/.config/lazygit/`                      | workstation |
| `common/btop/`                      | `~/.config/btop/`                         | all         |
| `common/fastfetch/`                 | `~/.config/fastfetch/`                    | all         |
| `workstation/yazi/`                 | `~/.config/yazi/`                         | workstation |
| `common/claude-code/settings.json`  | `~/.claude/settings.json`                 | all         |
| `common/claude-code/skills/`        | `~/.claude/skills/`                       | all         |
| `common/npm/packages.conf`          | global npm packages (installed via npm)   | all         |
| `influento/tmux-plugins` (release)  | `~/.local/bin/tmux-warp` (downloaded)     | all         |
| `common/scripts/*`                  | `~/.local/bin/*`                          | all         |
| `server/scripts/*`                  | `~/.local/bin/*`                          | server      |
| `server/systemd/user/`             | `~/.config/systemd/user/`                 | server      |
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
| `workstation/npm/packages.conf`     | workstation-only npm packages (via npm)   | workstation |
| `workstation/obsidian/plugins.conf` | `~/Dropbox/data-vault/.obsidian/plugins/` | workstation |
| `workstation/theming/gtk-3.0/`      | `~/.config/gtk-3.0/`                      | workstation |
| `workstation/theming/gtk-4.0/`      | `~/.config/gtk-4.0/`                      | workstation |
| `workstation/theming/qt6ct/`        | `~/.config/qt6ct/`                        | workstation |
| `workstation/theming/Kvantum/`      | `~/.config/Kvantum/`                      | workstation |
| `workstation/mpv/`                  | `~/.config/mpv/`                          | workstation |
| `workstation/yt-dlp/`               | `~/.config/yt-dlp/`                       | workstation |

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
| `workstation/lazygit/config.yml.tpl`         | `config.yml`         | `@@TOKEN@@`     |
| `workstation/mako/config.tpl`                | `config`             | `@@TOKEN@@`     |
| `workstation/swaylock/config.tpl`            | `config`             | `@@TOKEN_RAW@@` |
| `workstation/swayosd/style.css.tpl`          | `style.css`          | `@@TOKEN@@`     |
| `workstation/swaybg/wallpaper.sh.tpl`        | `wallpaper.sh`       | `@@TOKEN@@`     |
| `workstation/theming/gtk-4.0/gtk.css.tpl`    | `gtk.css`            | `@@TOKEN@@`     |
| `workstation/waybar/config.tpl`              | `config`             | `@@TOKEN@@`     |
| `workstation/waybar/style.css.tpl`           | `style.css`          | `@@TOKEN@@`     |
| `workstation/mpv/mpv.conf.tpl`               | `mpv.conf`           | `@@TOKEN@@`     |
| `workstation/mpv/script-opts/osc.conf.tpl`   | `osc.conf`           | `@@TOKEN@@`     |

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
| **btop**             | `common/btop/btop.conf`             | System monitor: theme, layout, vim keys                              |
| **fastfetch**        | `common/fastfetch/config.jsonc`     | System info display: modules, layout                                 |
| **setup-github**     | `common/scripts/setup-github`       | First-login setup: SSH key, GitHub auth, git identity, remote switch |
| **Claude Code**      | `common/claude-code/`               | Claude Code: global settings, permissions, custom skills. Bootstrapped via Anthropic's native installer on first `install.sh` run; self-updates thereafter |
| **npm packages**     | `common/npm/packages.conf`          | Global npm packages (all profiles): installed to user prefix (`~/.local`), update via auto-update |
| **tmux-warp**        | `influento/tmux-plugins` (binary)   | Flash.nvim-style jump navigation for tmux: search + char modes       |
| **scripts (common)** | `common/scripts/`                   | Shared personal scripts → `~/.local/bin/`                            |

### Server only

| Tool                      | Config location                                               | Purpose                                                              |
| ------------------------- | ------------------------------------------------------------- | -------------------------------------------------------------------- |
| **server-auto-update**    | `server/scripts/server-auto-update`                           | Unattended server maintenance: npm updates via systemd timer (12h)   |
| **systemd units**         | `server/systemd/user/`                                        | Timer-triggered services: server-auto-update.timer/.service          |
| **scripts (server)**      | `server/scripts/`                                             | Server-specific scripts → `~/.local/bin/`                            |

### Workstation only

| Tool                      | Config location                                               | Purpose                                                                                              |
| ------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **LazyGit**               | `workstation/lazygit/config.yml.tpl`                          | Terminal git UI: theme, pager, editor (themed)                                                       |
| **yazi**                  | `workstation/yazi/yazi.toml`                                  | File manager: keymaps, appearance overrides                                                          |
| **Sway**                  | `workstation/sway/config`                                     | Wayland compositor: keybindings, monitors, workspaces, window rules                                  |
| **Waybar**                | `workstation/waybar/config.tpl`, `style.css.tpl`              | Status bar: modules (clock, workspaces, tray), CSS styling (themed)                                  |
| **Ghostty**               | `workstation/ghostty/config`                                  | Terminal emulator: font, theme, window settings                                                      |
| **swaylock**              | `workstation/swaylock/config.tpl`                             | Screen locker: colors, indicator, behavior (themed)                                                  |
| **swayidle**              | `workstation/swayidle/config`                                 | Idle manager: lock, screen off, suspend timers                                                       |
| **mako**                  | `workstation/mako/config.tpl`                                 | Notification daemon: appearance, urgency, timeouts (themed)                                          |
| **swaybg**                | `workstation/swaybg/wallpaper.sh.tpl`, `wallpapers/`          | Wallpaper: launcher script, image storage (themed)                                                   |
| **wlsunset**              | `workstation/wlsunset/wlsunset.sh`                            | Night light: temperature, location-based schedule                                                    |
| **SwayOSD**               | `workstation/swayosd/style.css.tpl`                           | On-screen display: volume/brightness popup styling (themed)                                          |
| **cliphist**              | `workstation/cliphist/cliphist-pick.sh`                       | Clipboard history: picker script (wofi)                                                              |
| **Obsidian plugins**      | `workstation/obsidian/plugins.conf`                           | Plugin installer: downloads from GitHub releases into vault                                          |
| **GTK theming**           | `workstation/theming/gtk-3.0/settings.ini`                    | GTK3 apps: theme, icons, cursor, font                                                                |
| **Qt theming**            | `workstation/theming/qt6ct/qt6ct.conf`                        | Qt6 apps: Kvantum style, icons (requires qt6ct env var from OS installer)                            |
| **Kvantum**               | `workstation/theming/Kvantum/kvantum.kvconfig`                | Qt theme engine: renders Qt widgets to match GTK theme                                               |
| **XDG desktop portal**    | `workstation/xdg-desktop-portal/portals.conf`                 | Portal backend: routes desktop portals to wlr for Sway                                               |
| **auto-update**           | `workstation/scripts/auto-update`                             | Background system update on sway start: yay -Syu (repos + AUR) + npm updates, 12h cooldown, mako notifications |
| **npm packages**          | `workstation/npm/packages.conf`                               | Workstation-only npm packages: install on deploy, update via auto-update                             |
| **scripts (workstation)** | `workstation/scripts/`                                        | Desktop-specific scripts → `~/.local/bin/`                                                           |
| **mpv**                   | `workstation/mpv/mpv.conf.tpl`, `input.conf`, `script-opts/`  | Media player: keep-open, volume, OSD/OSC theming, yt-dlp integration (themed)                        |
| **yt-dlp**                | `workstation/yt-dlp/config`                                   | Video downloader: 1080p cap, mp4, metadata embedding, SponsorBlock                                   |

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

## Codebase Size (baseline: 2026-03-14)

~38,300 tokens total (~33,700 deduplicated, excluding generated files).

| Area                                     | Est. Tokens |
| ---------------------------------------- | ----------- |
| `common/`                                | ~13,200     |
| `workstation/`                           | ~8,900      |
| Root files (CLAUDE.md, install.sh, etc.) | ~6,200      |
| `lib/`                                   | ~3,900      |
| `docs/` + `themes/`                      | ~1,500      |

Binary files (wallpapers, 8.3 MB) excluded.

## Editing Configs

**IMPORTANT: Never use the Write tool for files that contain or will contain Nerd Font
icons** (U+F0000–U+F9999). The Write tool silently strips multi-byte UTF-8 icon
characters. This applies to both editing existing files AND creating new files.

- **Editing existing files with icons**: Use the Edit tool for targeted changes
- **Creating new files with icons**: Use Bash heredoc (`cat << 'EOF' > file`)
- **Common icon locations**: waybar scripts, sway config, any script that outputs
  waybar JSON (format strings with icon glyphs)

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
