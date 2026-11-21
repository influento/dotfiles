# Dotfiles

## Project Overview

Profile-driven, idempotent dotfiles manager for user-level configuration. Part of a
six-repo architecture:

1. **arch-install** — Arch Linux workstation installer (system-level only)
2. **debian-server** — Debian server installer (system-level only)
3. **dotfiles** (this repo) — User-level configuration (shell, editor, tools, desktop)
4. **gtk-widgets** — Custom GTK4 widgets (Python + PyGObject)
5. **tmux-plugins** — tmux plugins as Go binaries: tmux-warp, tmux-agent, tmux-revive; one release, pinned in `install.sh`
6. **workshop** (private) — agent skills and the tools a project installs (workbench, stack, the gates); cloned beside this repo and installed by its own `install.sh`

OS repositories are responsible only for system-level concerns: base installation,
package manager operations, services, and required packages. They must not contain
user configuration or tool-specific setup logic.

This repository is responsible only for user-level configuration. It is profile-driven
and idempotent so it can be safely re-run at any time.

## Commands

- Lint: run `shellcheck -x` on every tracked file whose first line is a bash shebang:
  `git ls-files -z | xargs -0 awk 'FNR==1 && /^#!.*bash/ {print FILENAME} {nextfile}' | xargs shellcheck -x`
- Check: `./check` runs the Lint command and every tracked `tests/*.sh` suite.
  Among the suites, `tests/deploy.sh` renders every template into a copy
  of the checkout, deploys it twice into a throwaway HOME, and fails if the second
  deploy changes anything
- Deploy (server): `bash install.sh --profile server`
- Deploy (workstation): `bash install.sh --profile workstation`. Run as the target
  user: `--user` only checks that it matches
- Dry run: `bash install.sh --profile server --dry-run`

## How It Works

### Profiles

| Profile | What gets deployed |
|---|---|
| `server` | Common only |
| `workstation` | Common + workstation: adds sway, waybar, ghostty, theming |

### Deployment Method

Configs are deployed as **symlinks**. A directory `<profile>/<tool>/` links to
`~/.config/<tool>/` unless the tables below name another target. This means:

- Changes to dotfiles are immediately reflected (no copy/sync needed)
- `git diff` inside the dotfiles repo shows all config changes
- Re-running `install.sh` is safe (idempotent — existing correct symlinks are skipped)
- Existing files are backed up with a timestamp before being replaced

**Exception — app-rewritten files.** `~/.claude/settings.json` is deep-merged by
`merge_json_config` instead of symlinked. How edits then propagate in both
directions: `common/claude-code/CLAUDE.md`.

## Tools

Source paths are relative to the repo. A bare directory deploys to `~/.config/<tool>/`.

### Common (all profiles)

| Tool | Source → target | Purpose |
|---|---|---|
| **zsh + oh-my-zsh** | `common/zsh/.zshrc` (from `.zshrc.tpl`) → `~/.zshrc`; `.zshenv` → `~/.zshenv` | Shell: plugins, aliases, environment, prompt theme. `.zshenv` sets PATH for non-interactive shells (`ssh host <cmd>`) |
| **Neovim** | `common/nvim/` | Editor: keymaps, plugins (lazy.nvim), options |
| **IdeaVim** | `common/ideavim/.ideavimrc` → `~/.ideavimrc` | JetBrains IDE Vim layer: mirrors nvim keymaps and options |
| **tmux** | `common/tmux/` | Prefix key, panes, status bar, attention glyphs and counts, popups (`prefix g`/`v`/`t`: tmux-overlay), `prefix e` scrollback in nvim, ssh windows named `host(ssh)` |
| **Git** | `common/git/.gitconfig` → `~/.gitconfig` | User identity (in `~/.gitconfig.local`), aliases, defaults |
| **delta** | `common/delta/` (included by `~/.gitconfig`) | Diff viewer for lazygit and git's pager: line tints, line numbers, file names that open nvim at the line from lazygit. Git falls back to less where delta is missing (servers) |
| **Starship** | `common/starship/` | Prompt: segments, icons |
| **fontconfig** | `common/fontconfig/` | Font rendering: hinting, antialiasing, default families |
| **btop** | `common/btop/` | System monitor: theme, layout, vim keys |
| **fastfetch** | `common/fastfetch/` | System info display: modules, layout |
| **Claude Code** | `common/claude-code/settings.json` → `~/.claude/settings.json` (merged) | Settings, permissions, hooks: `common/claude-code/CLAUDE.md`. Installed by Anthropic's native installer on the first run; it updates itself |
| **workshop** | `influento/workshop` (private, SSH), cloned beside this repo → `~/.claude/skills/<skill>`, `~/.local/bin/workbench`, `~/.local/bin/stack` | Skills and the tools a project installs, deployed by its own `install.sh`. Skipped with a warning where the clone fails (no GitHub key yet) |
| **npm packages** | `common/npm/packages.conf` | Global npm packages, installed to `~/.local`, updated by auto-update on workstations |
| **tmux-warp** | `influento/tmux-plugins` release (`TMUX_PLUGINS_VERSION` in `install.sh`, checked against its SHA256SUMS) → `~/.local/bin/tmux-warp`, `tmux-warp.sh` | Flash.nvim-style jump navigation for tmux: search + char modes |
| **scripts** | `common/scripts/*` → `~/.local/bin/` | See [Scripts](#scripts) |

### Workstation only

| Tool | Source → target | Purpose |
|---|---|---|
| **zsh** | `workstation/zsh/.zshrc-workstation` → `~/.zshrc-workstation` | Desktop-only shell setup |
| **LazyGit** | `workstation/lazygit/` | Terminal git UI: theme, pager, editor |
| **yazi** | `workstation/yazi/` | File manager: keymaps, appearance |
| **Sway** | `workstation/sway/` | Wayland compositor: keybindings, monitors, workspaces, window rules |
| **Waybar** | `workstation/waybar/` | Status bar: modules, CSS styling |
| **Ghostty** | `workstation/ghostty/` | Terminal emulator: font, theme, window settings |
| **swaylock** | `workstation/swaylock/` | Screen locker: colors, indicator, behavior |
| **swayidle** | `workstation/swayidle/` | Idle manager: lock, screen off, suspend timers |
| **mako** | `workstation/mako/` | Notification daemon: appearance, urgency, timeouts |
| **swaybg** | `workstation/swaybg/` | Wallpaper: launcher script, images |
| **wlsunset** | `workstation/wlsunset/` | Night light: one fixed temperature, set from gtk-widgets' settings popup |
| **SwayOSD** | `workstation/swayosd/` | Volume/brightness popup styling |
| **XDG desktop portal** | `workstation/xdg-desktop-portal/` | Routes desktop portals to wlr for Sway |
| **xdg-desktop-portal-wlr** | `workstation/xdg-desktop-portal-wlr/` | Screen-share source picker: `launcher --dmenu` |
| **GTK theming** | `workstation/theming/gtk-3.0/`, `gtk-4.0/` → `~/.config/gtk-3.0/`, `gtk-4.0/` | GTK apps: theme, icons, cursor, font (gtk-3.0); libadwaita color overrides (gtk-4.0) |
| **Qt theming** | `workstation/theming/qt6ct/` → `~/.config/qt6ct/` | Qt6 apps: Fusion style, Papirus-Dark icons, fonts (needs the qt6ct env var from the OS installer) |
| **mpv** | `workstation/mpv/` | Media player: keep-open, volume, OSD/OSC theming, yt-dlp integration |
| **yt-dlp** | `workstation/yt-dlp/` | Video downloader: 1080p cap, mp4, metadata, SponsorBlock |
| **MIME defaults** | `workstation/mimeapps/mimeapps.list` → `~/.config/mimeapps.list`; `nvim-ghostty.desktop` → `~/.local/share/applications/` | Default apps: swayimg for images, Chrome for the web, nvim in a new Ghostty window for text and source types, Telegram and Claude Code for their URL schemes |
| **Obsidian plugins** | `workstation/obsidian/plugins.conf` → `~/Dropbox/data-vault/.obsidian/plugins/` | Downloaded from GitHub releases into the vault |
| **npm packages** | `workstation/npm/packages.conf` | Workstation-only global npm packages |
| **tmux-agent** | the same `influento/tmux-plugins` release → `~/.local/bin/tmux-agent` | A pane flags what it needs (`needs-you`/`done`/`working`, ✗ for a failed run), set by Claude Code's hooks and the `claude` shell function. Glyphs, counts, `prefix f` picker, `prefix o` jump, desktop notification for panes out of view |
| **tmux-revive** | the same release → `~/.local/bin/tmux-revive` | Saves every session, window and pane on each change and restores them through `tmux-attach`, agents with their conversation. `prefix C-r` adds back what is missing, `prefix X` forgets a session before killing it |
| **gtk-widgets** | `influento/gtk-widgets`, cloned beside this repo | Custom GTK4 widgets, installed by its own `install.sh` |
| **cheatsheets** | `workstation/cheatsheets/tools/`, not deployed | HTML cheatsheet opened by the `cheat` alias: `workstation/cheatsheets/CLAUDE.md` |
| **scripts** | `workstation/scripts/*` → `~/.local/bin/` | See [Scripts](#scripts) |

tmux keys and colors for tmux-agent and tmux-revive: `common/tmux/tmux.conf.tpl`.

### Scripts

| Script | Profile | Purpose |
|---|---|---|
| `setup-github` | all | First-login setup: SSH key, GitHub auth, git identity, private git root (`private.root` in `~/.gitconfig.local`), remote switch |
| `git-private` | all | `git private`: create `<private.root>/<name>.git` over SSH, add it as `origin` (or `mirror` beside a GitHub origin), push. Driven by the `private-remote` skill |
| `tmux-overlay` | all | The `prefix g`/`v`/`t` popups: `common/scripts/CLAUDE.md` |
| `auto-update` | workstation | Background system update on sway start: repos + AUR + npm, with a cooldown |
| `chrome`, `google-chrome` | workstation | Run `google-chrome-stable`, never Chromium; e.g. `chrome --headless --screenshot=out.png file:///…` |
| `tg`, `tg-run` | workstation | Isolated Telegram Desktop instances that appear separately in the launcher |
| `nosleep`, `nosleep-status` | workstation | Keep the machine running: `on` blocks sleep, lid close included; `awake [DURATION]` also skips the idle lock and display-off (calls, reading). `off`/`status`/`toggle`/`cycle`, or `hibernate` now; waybar indicator, click cycles |
| `headless`, `headless-status` | workstation | Backup/low-power mode: serves the live Sway session over VNC with the monitor off (`$mod+Shift+o`, waybar indicator); `connect` and `app` reach it from the laptop (`connect` also carries the clipboard both ways), `bind` (`$mod+Ctrl+o`) gives a workspace on another tool's headless output its own viewer on the same workspace number |
| `startup-reminders` | workstation | Nags about post-install manual steps on sway start until a script marks them done (`reminders/`) |
| `terminal` | workstation | `$mod+Return`: brings the tmux terminal (the Ghostty window titled `tmux`) to the focused workspace from wherever it is; opens Ghostty only when there is none |
| `tmux-attach` | workstation | Terminal entry point: `tmux-revive attach`, or `tmux new-session -A -s main` when the binary is missing |
| `lock` | workstation | Switches to the US layout, then locks. `--lid`: sway's lid close, locks only while nosleep keeps the machine running |
| `cliphist-pick` | workstation | Clipboard history picker on `$mod+v`, through gtk-widgets' launcher: thumbnails, preview, delete |
| `cliphist-store` | workstation | The clipboard history writer sway runs (`wl-paste --watch cliphist-store`): images and file links paste as picture or path |
| `setup-wireguard` | workstation | Imports WireGuard configs from Dropbox into NetworkManager |
| `stale-kernel` | workstation | Waybar indicator: the kernel was upgraded and a reboot is pending |
| `delta-wrap` | workstation | lazygit's diff renderer: runs delta and wraps long lines behind the line numbers |

How they work and why: `common/scripts/CLAUDE.md`, `workstation/scripts/CLAUDE.md`.

## Theming System

Colors are centralized in theme palette files under `themes/`. Config files that use
colors are stored as `.tpl` templates with `@@TOKEN@@` placeholders. At install time,
`lib/theme.sh` renders each `X.tpl` into `X` beside it, using `sed`. Every generated
file is in `.gitignore`. `git ls-files '*.tpl'` lists the templates.

### Token Syntax

| Token format | Rendered as | Use when |
|---|---|---|
| `@@COLOR_NAME@@` | `#hexvalue` (hash-prefixed) | CSS, YAML, most configs |
| `@@COLOR_NAME_RAW@@` | `hexvalue` (bare hex) | swaylock, and the Ghostty theme's non-palette keys, which expect no `#` |
| `@@MIX_COLOR_PCT@@` | `#hexvalue`, PCT% of COLOR over `BASE` | tints on the theme background (delta's line backgrounds) |
| `@@SYNTAX_THEME@@` | `THEME_META` name of the matching bat/delta syntax theme | delta |

### Theme Selection

Priority: `--theme` CLI flag > `theme.conf` > fallback (`catppuccin-mocha`).
`theme.conf` is per machine and gitignored.

### Adding a New Theme

1. Copy `themes/catppuccin-mocha.sh` to `themes/<name>.sh`
2. Update `THEME_META` (NAME, DISPLAY_NAME, SYNTAX_THEME from `delta --list-syntax-themes`) and all `THEME_COLORS` values
3. Set `THEME=<name>` in `theme.conf` or pass `--theme <name>`
4. Run `bash install.sh --profile workstation` to regenerate configs

Two parts do not follow the palette yet. Fix them when the second theme arrives:

- **Neovim**: `common/nvim/lua/plugins/catppuccin.lua` hardcodes `flavour = "mocha"`.
  catppuccin.nvim's `color_overrides` takes the `THEME_COLORS` names in lowercase, so
  the file can become a template filled from the palette
- **gtk-widgets**: keeps its own palette copy in its `themes/<name>.json` and gets only
  the theme name. Have this repo write the palette JSON at install time, and drop the copy

Then make `tests/deploy.sh` render a dummy second palette and fail when a
catppuccin-mocha color shows up in the output.

## Changing a Config

**IMPORTANT: Never use the Write tool for files that contain or will contain Nerd Font
icons** (Private Use Area: U+E000–U+F8FF, U+F0000–U+FFFFD). The Write tool silently
strips multi-byte UTF-8 icon characters. This applies to both editing existing files
AND creating new files.

- **Editing existing files with icons**: Use the Edit tool for targeted changes
- **Creating new files with icons**: Use Bash heredoc (`cat << 'EOF' > file`)
- **Finding files with icons**:
  `git grep -IlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]'`

Editing a config:

1. **Check `docs/references.md`** for the tool's official documentation, especially
   after an upgrade that may bring breaking changes
2. **Check if the config is a template** — if a `.tpl` exists, edit it, never the
   generated file (the next install overwrites it)
3. **Use theme tokens for colors** — a hex color from the palette is always a
   `@@TOKEN@@` or `@@TOKEN_RAW@@` placeholder, never hardcoded
4. **Adding colors to a non-template config** — rename it to `<name>.tpl` (e.g.
   `config` → `config.tpl`), replace the hex colors with tokens, and add the
   generated file to `.gitignore`
5. **Run `install.sh`** after a template change to regenerate files and check the
   rendering

Adding a config:

1. Create a directory under `common/` (all profiles) or `workstation/` (desktop only)
   with the config files inside; a config with theme colors is a `.tpl` (Editing step 4)
2. A `~/.config/<name>/` target works automatically via `deploy_configs`. For another
   target (like `~/.zshrc`), add a case to `deploy_configs` in `lib/helpers.sh`. A
   target in a folder no other link uses also goes into `prune_dead_links`'s list:
   `tests/deploy.sh` fails until it does
3. Add a row to the [Tools](#tools) table
4. Run `./check` ([Commands](#commands)). A new special target gets a line in
   `tests/deploy.sh`

## Claude Code Skills

Skills, the per-project optional skills and the workshop tools live in the
private `workshop` repo (`../workshop/`, its `AGENTS.md`). This repo keeps only
Claude Code's `settings.json`. `install_workshop` in `lib/helpers.sh` clones or
updates that repo and runs its installer.

## Code Conventions

- All scripts use `#!/usr/bin/env bash` shebang
- Every script starts with `set -euo pipefail` (sourced files in `lib/` and `themes/`
  do not: they inherit the caller's options)
- Bash passes the Lint command (`shellcheck -x`)
- Indent with 2 spaces, no tabs
- Functions use `snake_case`
- Quote all variable expansions
- A script is committed executable (`git add --chmod=+x`); `install.sh` never sets the bit
- Common config calls a workstation-only binary (tmux-agent, tmux-revive) only behind
  `command -v`
- Before every commit/push, audit the staged diff for sensitive information leaks:
  usernames, passwords, API keys, tokens, private IPs, email addresses, or any
  data that should not appear in a public repository. Flag any findings to the user
  before proceeding

## Documentation

- **`docs/references.md`** — official doc links and config format notes, by tool.
- Subfolders have their own `CLAUDE.md` for detail that only matters there; it loads
  when that tree is touched.
