# Dotfiles

## Project Overview

Profile-driven, idempotent dotfiles manager for user-level configuration. Part of a
five-repo architecture:

1. **arch-install** — Arch Linux workstation installer (system-level only)
2. **debian-server** — Debian server installer (system-level only)
3. **dotfiles** (this repo) — User-level configuration (shell, editor, tools, desktop)
4. **gtk-widgets** — Custom GTK4 widgets (Python + PyGObject)
5. **tmux-plugins** — tmux plugins as Go binaries: tmux-warp, tmux-agent, tmux-revive; one release, pinned in `install.sh`

OS repositories are responsible only for system-level concerns: base installation,
package manager operations, services, and required packages. They must not contain
user configuration or tool-specific setup logic.

This repository is responsible only for user-level configuration. It is profile-driven
and idempotent so it can be safely re-run at any time.

## How It Works

### Profiles

| Profile       | What gets deployed                                        |
| ------------- | --------------------------------------------------------- |
| `server`      | Common only                                               |
| `workstation` | Common + workstation: adds sway, waybar, ghostty, theming |

### Deployment Method

Configs are deployed as **symlinks** from `~/.config/<tool>` → `<dotfiles>/<profile>/<tool>`.
This means:

- Changes to dotfiles are immediately reflected (no copy/sync needed)
- `git diff` inside the dotfiles repo shows all config changes
- Re-running `install.sh` is safe (idempotent — existing correct symlinks are skipped)
- Existing files are backed up with a timestamp before being replaced

**Exception — app-rewritten files.** `~/.claude/settings.json` is deep-merged by
`merge_json_config` instead of symlinked, with consequences for how edits
propagate in both directions: `common/claude-code/CLAUDE.md`.

### Config Mapping

| Source                                                           | Target                                                                                                      | Profile     |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ----------- |
| `common/zsh/.zshrc.tpl`                                          | `~/.zshrc` (via generated `.zshrc`)                                                                         | all         |
| `common/zsh/.zshenv`                                             | `~/.zshenv` (PATH for non-interactive shells, e.g. `ssh host <cmd>`)                                        | all         |
| `workstation/zsh/.zshrc-workstation`                             | `~/.zshrc-workstation`                                                                                      | workstation |
| `common/nvim/`                                                   | `~/.config/nvim/`                                                                                           | all         |
| `common/ideavim/.ideavimrc`                                      | `~/.ideavimrc`                                                                                              | all         |
| `common/tmux/`                                                   | `~/.config/tmux/`                                                                                           | all         |
| `common/git/.gitconfig`                                          | `~/.gitconfig`                                                                                              | all         |
| `common/delta/`                                                  | `~/.config/delta/` (included by `~/.gitconfig`)                                                             | all         |
| `common/starship/`                                               | `~/.config/starship/`                                                                                       | all         |
| `common/fontconfig/`                                             | `~/.config/fontconfig/`                                                                                     | all         |
| `workstation/lazygit/`                                           | `~/.config/lazygit/`                                                                                        | workstation |
| `common/btop/`                                                   | `~/.config/btop/`                                                                                           | all         |
| `common/fastfetch/`                                              | `~/.config/fastfetch/`                                                                                      | all         |
| `workstation/yazi/`                                              | `~/.config/yazi/`                                                                                           | workstation |
| `common/claude-code/settings.json`                               | `~/.claude/settings.json` (**merged**, not symlinked)                                                       | all         |
| `common/claude-code/skills/`                                     | `~/.claude/skills/`                                                                                         | all         |
| `common/claude-code/skills-optional/`                            | _not deployed_ — symlinked per project into `<project>/.claude/skills/`                                     | all         |
| `common/npm/packages.conf`                                       | global npm packages (installed via npm)                                                                     | all         |
| `influento/tmux-plugins` release pinned in `install.sh` (`TMUX_PLUGINS_VERSION`, checked against its SHA256SUMS) | `~/.local/bin/tmux-warp`, `tmux-warp.sh` (downloaded) | all |
| the same release | `~/.local/bin/tmux-agent`, `~/.local/bin/tmux-revive` (downloaded) | workstation |
| `common/scripts/*`                                               | `~/.local/bin/*`                                                                                            | all         |
| `common/claude-code/workshop/workbench/bin/workbench`                     | `~/.local/bin/workbench` (with `stack`, the only files deployed out of `workshop/`, because they are what opts a project in) | all         |
| `common/claude-code/workshop/stack/bin/stack`                     | `~/.local/bin/stack` (the package registry under `workshop/<ecosystem>/packages/` is read from here at `stack add` time) | all         |
| `workstation/sway/`                                              | `~/.config/sway/`                                                                                           | workstation |
| `workstation/swaylock/`                                          | `~/.config/swaylock/`                                                                                       | workstation |
| `workstation/swayidle/`                                          | `~/.config/swayidle/`                                                                                       | workstation |
| `workstation/mako/`                                              | `~/.config/mako/`                                                                                           | workstation |
| `workstation/swaybg/`                                            | `~/.config/swaybg/`                                                                                         | workstation |
| `workstation/wlsunset/`                                          | `~/.config/wlsunset/`                                                                                       | workstation |
| `workstation/swayosd/`                                           | `~/.config/swayosd/`                                                                                        | workstation |
| `workstation/cliphist/`                                          | `~/.config/cliphist/`                                                                                       | workstation |
| `workstation/waybar/`                                            | `~/.config/waybar/`                                                                                         | workstation |
| `workstation/ghostty/`                                           | `~/.config/ghostty/`                                                                                        | workstation |
| `workstation/xdg-desktop-portal/`                                | `~/.config/xdg-desktop-portal/`                                                                             | workstation |
| `workstation/scripts/*`                                          | `~/.local/bin/*`                                                                                            | workstation |
| `workstation/npm/packages.conf`                                  | workstation-only npm packages (via npm)                                                                     | workstation |
| `workstation/obsidian/plugins.conf`                              | `~/Dropbox/data-vault/.obsidian/plugins/`                                                                   | workstation |
| `workstation/theming/gtk-3.0/`                                   | `~/.config/gtk-3.0/`                                                                                        | workstation |
| `workstation/theming/gtk-4.0/`                                   | `~/.config/gtk-4.0/`                                                                                        | workstation |
| `workstation/theming/qt6ct/`                                     | `~/.config/qt6ct/`                                                                                          | workstation |
| `workstation/mpv/`                                               | `~/.config/mpv/`                                                                                            | workstation |
| `workstation/yt-dlp/`                                            | `~/.config/yt-dlp/`                                                                                         | workstation |
| `workstation/mimeapps/mimeapps.list`                             | `~/.config/mimeapps.list`                                                                                   | workstation |

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
| `@@MIX_COLOR_PCT@@`  | `#hexvalue`, PCT% of COLOR over `BASE` | tints on the theme background (delta's line backgrounds) |
| `@@SYNTAX_THEME@@`   | `THEME_META` name of the matching bat/delta syntax theme | delta |

### Theme Selection

Priority: `--theme` CLI flag > `theme.conf` > fallback (`catppuccin-mocha`)

### Adding a New Theme

1. Copy `themes/catppuccin-mocha.sh` to `themes/<name>.sh`
2. Update `THEME_META` (NAME, DISPLAY_NAME, SYNTAX_THEME from `delta --list-syntax-themes`) and all `THEME_COLORS` values
3. Set `THEME=<name>` in `theme.conf` or pass `--theme <name>`
4. Run `bash install.sh --profile workstation` to regenerate configs

### Adding Colors to a Config

1. Rename the config file to `<name>.tpl` (e.g., `config` → `config.tpl`)
2. Replace hardcoded hex colors with `@@TOKEN@@` or `@@TOKEN_RAW@@` tokens
3. Add the generated file path to `.gitignore`
4. The generated file will be created alongside the template at install time

### Template Files

| Template                                       | Generated file   | Token format                 |
| ---------------------------------------------- | ---------------- | ---------------------------- |
| `common/zsh/.zshrc.tpl`                        | `.zshrc`         | `@@TOKEN@@`                  |
| `common/starship/starship.toml.tpl`            | `starship.toml`  | `@@TOKEN@@`                  |
| `common/delta/delta.gitconfig.tpl`             | `delta.gitconfig` | `@@TOKEN@@`, `@@MIX_COLOR_PCT@@` |
| `common/tmux/tmux.conf.tpl`                    | `tmux.conf`      | `@@TOKEN@@`                  |
| `common/btop/themes/dotfiles.theme.tpl`        | `dotfiles.theme` | `@@TOKEN@@`                  |
| `workstation/lazygit/config.yml.tpl`           | `config.yml`     | `@@TOKEN@@`                  |
| `workstation/mako/config.tpl`                  | `config`         | `@@TOKEN@@`                  |
| `workstation/swaylock/config.tpl`              | `config`         | `@@TOKEN_RAW@@`              |
| `workstation/swayosd/style.css.tpl`            | `style.css`      | `@@TOKEN@@`                  |
| `workstation/swaybg/wallpaper.sh.tpl`          | `wallpaper.sh`   | `@@TOKEN@@`                  |
| `workstation/theming/gtk-4.0/gtk.css.tpl`      | `gtk.css`        | `@@TOKEN@@`                  |
| `workstation/sway/config.tpl`                  | `config`         | `@@TOKEN@@`                  |
| `workstation/waybar/config.tpl`                | `config`         | `@@TOKEN@@`                  |
| `workstation/waybar/style.css.tpl`             | `style.css`      | `@@TOKEN@@`                  |
| `workstation/mpv/mpv.conf.tpl`                 | `mpv.conf`       | `@@TOKEN@@`                  |
| `workstation/mpv/script-opts/osc.conf.tpl`     | `osc.conf`       | `@@TOKEN@@`                  |
| `workstation/ghostty/themes/dotfiles.conf.tpl` | `dotfiles.conf`  | `@@TOKEN@@`, `@@TOKEN_RAW@@` |
| `workstation/yazi/theme.toml.tpl`              | `theme.toml`     | `@@TOKEN@@`                  |

## What Each Tool Does

### Common (all profiles)

| Tool                 | Config location                     | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **zsh + oh-my-zsh**  | `common/zsh/.zshrc.tpl`             | Shell: plugins, aliases, environment, prompt theme (themed)                                                                                                                                                                                                                                                                                                                                                                    |
| **Neovim**           | `common/nvim/init.lua`              | Editor: keymaps, plugins (lazy.nvim), options                                                                                                                                                                                                                                                                                                                                                                                  |
| **IdeaVim**          | `common/ideavim/.ideavimrc`         | JetBrains IDE Vim layer: mirrors nvim keymaps and options                                                                                                                                                                                                                                                                                                                                                                      |
| **tmux**             | `common/tmux/tmux.conf.tpl`         | Terminal multiplexer: prefix key, panes, status bar (themed), attention glyphs and counts, popups (`prefix g` lazygit, `prefix t` scratch shell, `prefix e` scrollback in nvim with `]]`/`[[` between prompts — `common/nvim/lua/scrollback.lua`), ssh windows named `host(ssh)` from the destination as typed (zsh preexec → pane option `@ssh_host` → `automatic-rename-format`)                                                                                                                                                                                                                                             |
| **Git**              | `common/git/.gitconfig`             | Version control: user identity, aliases, defaults                                                                                                                                                                                                                                                                                                                                                                              |
| **delta**            | `common/delta/delta.gitconfig.tpl`  | Diff viewer for lazygit and git's pager (themed): line tints, new-file line numbers, clickable file names (`lazygit-edit://` in lazygit opens nvim at the line). Git's pager falls back to less where delta is not installed (servers) |
| **Starship**         | `common/starship/starship.toml.tpl` | Cross-shell prompt: segments, theme, icons (themed)                                                                                                                                                                                                                                                                                                                                                                            |
| **fontconfig**       | `common/fontconfig/fonts.conf`      | Font rendering: hinting, antialiasing, default families                                                                                                                                                                                                                                                                                                                                                                        |
| **btop**             | `common/btop/btop.conf`             | System monitor: theme, layout, vim keys                                                                                                                                                                                                                                                                                                                                                                                        |
| **fastfetch**        | `common/fastfetch/config.jsonc`     | System info display: modules, layout                                                                                                                                                                                                                                                                                                                                                                                           |
| **setup-github**     | `common/scripts/setup-github`       | First-login setup: SSH key, GitHub auth, git identity, private git root (`private.root` in `~/.gitconfig.local`), remote switch                                                                                                                                                                                                                                                                                                                                                           |
| **git-private**      | `common/scripts/git-private`        | `git private`: create `<private.root>/<name>.git` over SSH, add it as `origin` (or `mirror` beside a GitHub origin), push. Driven by the `private-remote` skill |
| **tmux-overlay**     | `common/scripts/tmux-overlay`       | `prefix v`: an nvim popup per tmux session, kept alive in a hidden session; same key inside hides it, state survives. See `common/scripts/CLAUDE.md` |
| **Claude Code**      | `common/claude-code/`               | Claude Code: global settings, permissions, custom skills, and the workbench and stack CLIs (see `common/claude-code/CLAUDE.md` and "Claude Code Skills" below; skills are drafted and tested with the claude.ai-synced `anthropic-skills:skill-creator` — its eval scripts need PyYAML + a browser, so they only fully work on workstation). Bootstrapped via Anthropic's native installer on first `install.sh` run; self-updates thereafter |
| **npm packages**     | `common/npm/packages.conf`          | Global npm packages (all profiles): installed to user prefix (`~/.local`), update via auto-update                                                                                                                                                                                                                                                                                                                              |
| **tmux-warp**        | `influento/tmux-plugins` (binary)   | Flash.nvim-style jump navigation for tmux: search + char modes                                                                                                                                                                                                                                                                                                                                                                 |
| **scripts (common)** | `common/scripts/`                   | Shared personal scripts → `~/.local/bin/`                                                                                                                                                                                                                                                                                                                                                                                      |

### Workstation only

| Tool                      | Config location                                              | Purpose                                                                                                                                                                                          |
| ------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **LazyGit**               | `workstation/lazygit/config.yml.tpl`                         | Terminal git UI: theme, pager, editor (themed)                                                                                                                                                   |
| **yazi**                  | `workstation/yazi/yazi.toml`                                 | File manager: keymaps, appearance overrides (themed)                                                                                                                                             |
| **Sway**                  | `workstation/sway/config.tpl`                                | Wayland compositor: keybindings, monitors, workspaces, window rules (themed)                                                                                                                     |
| **Waybar**                | `workstation/waybar/config.tpl`, `style.css.tpl`             | Status bar: modules (clock, workspaces, tray), CSS styling (themed)                                                                                                                              |
| **Ghostty**               | `workstation/ghostty/config`                                 | Terminal emulator: font, theme, window settings (themed)                                                                                                                                         |
| **swaylock**              | `workstation/swaylock/config.tpl`                            | Screen locker: colors, indicator, behavior (themed)                                                                                                                                              |
| **swayidle**              | `workstation/swayidle/config`                                | Idle manager: lock, screen off, suspend timers                                                                                                                                                   |
| **mako**                  | `workstation/mako/config.tpl`                                | Notification daemon: appearance, urgency, timeouts (themed)                                                                                                                                      |
| **swaybg**                | `workstation/swaybg/wallpaper.sh.tpl`, `wallpapers/`         | Wallpaper: launcher script, image storage (themed)                                                                                                                                               |
| **wlsunset**              | `workstation/wlsunset/wlsunset.sh`                           | Night light: temperature, location-based schedule                                                                                                                                                |
| **SwayOSD**               | `workstation/swayosd/style.css.tpl`                          | On-screen display: volume/brightness popup styling (themed)                                                                                                                                      |
| **cliphist**              | `workstation/cliphist/cliphist-pick.sh`                      | Clipboard history: picker script (launcher)                                                                                                                                                      |
| **Obsidian plugins**      | `workstation/obsidian/plugins.conf`                          | Plugin installer: downloads from GitHub releases into vault                                                                                                                                      |
| **GTK theming**           | `workstation/theming/gtk-3.0/settings.ini`                   | GTK3 apps: theme, icons, cursor, font                                                                                                                                                            |
| **Qt theming**            | `workstation/theming/qt6ct/qt6ct.conf`                       | Qt6 apps: Fusion style, Papirus-Dark icons, fonts (requires qt6ct env var from OS installer)                                                                                                     |
| **XDG desktop portal**    | `workstation/xdg-desktop-portal/portals.conf`                | Portal backend: routes desktop portals to wlr for Sway                                                                                                                                           |
| **auto-update**           | `workstation/scripts/auto-update`                            | Background system update on sway start: repos + AUR + npm, with a cooldown                                                                                                                       |
| **tg**                    | `workstation/scripts/tg`                                     | Create isolated Telegram Desktop instances that appear separately in the launcher                                                                                                                |
| **nosleep**               | `workstation/scripts/nosleep`, `nosleep-status`              | Toggle sleep inhibition, lid close included (`on`/`off`/`status`/`toggle`), or `hibernate` now, even with the lid closed; waybar indicator                                                                                                                |
| **headless**              | `workstation/scripts/headless`, `headless-status`            | Backup/low-power mode: serves the live Sway session over VNC with the monitor off (`on`/`off`/`status`/`toggle`, `$mod+Shift+o`, waybar indicator); `connect` and `app` reach it from the laptop |
| **startup-reminders**     | `workstation/scripts/startup-reminders`                      | Nag about post-install manual steps on sway start, until a script marks them done (data in `reminders/*.txt`)                                                                                    |
| **npm packages**          | `workstation/npm/packages.conf`                              | Workstation-only npm packages: install on deploy, update via auto-update                                                                                                                         |
| **tmux-agent**            | `influento/tmux-plugins` (binary)                            | A pane flags what it needs (`needs-you`/`done`/`working`, ✗ for a failed run), set by Claude Code's hooks (`common/claude-code/settings.json`) and by the launcher behind the `claude` shell function; glyphs in the window list and on pane borders, counts on the status right, `prefix f` picker, `prefix o` jump, desktop notification for panes out of view. Keys and colours in `common/tmux/tmux.conf.tpl` |
| **tmux-revive**           | `influento/tmux-plugins` (binary)                            | Saves every tmux session, window and pane on each change and restores them through `tmux-attach`, agents with their conversation; `prefix C-r` adds back what is missing, `prefix X` forgets a session before it kills it. Replaces resurrect and continuum |
| **tmux-attach**           | `workstation/scripts/tmux-attach`                            | Terminal entry point: a 2-line shim that runs `tmux-revive attach`, or plain `tmux new-session -A -s main` when the binary is missing |
| **scripts (workstation)** | `workstation/scripts/`                                       | Desktop-specific scripts → `~/.local/bin/`                                                                                                                                                       |
| **mpv**                   | `workstation/mpv/mpv.conf.tpl`, `input.conf`, `script-opts/` | Media player: keep-open, volume, OSD/OSC theming, yt-dlp integration (themed)                                                                                                                    |
| **yt-dlp**                | `workstation/yt-dlp/config`                                  | Video downloader: 1080p cap, mp4, metadata embedding, SponsorBlock                                                                                                                               |
| **swayimg (MIME)**        | `workstation/mimeapps/mimeapps.list`                         | Default image viewer for png/jpeg/gif/webp/bmp/tiff/svg/avif/heif, nvim in a new Ghostty window for text and source types via the bundled `nvim-ghostty.desktop` (each type listed explicitly; an unset one falls back to `nvim.desktop`, whose `Terminal=true` xdg-open runs inline in the calling terminal and hijacks lazygit's pty) + keeps existing browser/scheme handlers                                                                                       |
| **cheatsheets**           | `workstation/cheatsheets/tools/`                             | Single multi-scope HTML cheatsheet, opened by the `cheat` alias — no deploy step. See `workstation/cheatsheets/CLAUDE.md`                                                                        |

What the scripts above actually do — the headless design constraints, the
nosleep inhibitor, tg's isolated instances, auto-update's cooldown, the
reminders format:
`workstation/scripts/CLAUDE.md`.

## Claude Code Skills

Skills are split into two trees under `common/claude-code/`:

| Tree               | Deployed                                  | Contents                                                                                                                                                                                                                          |
| ------------------ | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `skills/`          | symlinked to `~/.claude/skills/` (global) | `bugfix`, `codebase-design`, `deepen`, `densify`, `docx`, `frontend-design`, `grilling`, `handoff`, `hillclimb`, `human-like-text`, `pdf`, `private-remote`, `prototype`, `resolving-merge-conflicts`, `show-me`, `ste`, `tmux-peers`, `topo`, `wat`, `workshop-setup` |
| `workshop/`         | only `workbench/bin/workbench` and `stack/bin/stack` → `~/.local/bin/` | The tools installed into a project, whole: `workbench/` (the CLI and its tests, under `text/` the rules, the reviewer and demo agents and the item templates, which `workbench init` and `workbench new` copy in, and the setup checklist that `init` prints, and under `hook/` the Stop hook that `init` copies in to run the review), `stack/` (the CLI for the libraries, toolkits and tools a project chooses one at a time with `stack add`: a rule, skills from the registry or skills.sh, a dependency, a read-only subtree under `repos/` when the source is worth reading, a CLAUDE.md line), and the registry by ecosystem, each package in a role folder (`runtime`, `clients`, `kits`, `ui`, `practices`, `toolkits`, `presets`): `typescript/` (`gate/`, the TypeScript Stop-hook gate copied in by its `install.sh`, with the `packages/` written against it), `go/packages/practices/` (`go-practices`: the five Go skills, added with `stack add`; no Go gate yet) and `general/packages/` (no ecosystem); `guard/`, which every installer calls to make the agent ask before it changes the files the tool wrote. Never linked — see `common/claude-code/workshop/CLAUDE.md` |
| `skills-optional/` | never deployed — opted into per project   | `manim`, `excalidraw`, `build-cv` (gitignored — holds real CV data and this repo is public). How to opt in: `common/claude-code/skills-optional/CLAUDE.md` |

The split is about **trigger blast radius**, not disk or token cost. Only a skill's
`name` and `description` frontmatter is loaded into context at session start — the
`SKILL.md` body and its `references/`/`scripts/` load lazily when the skill fires. The
whole global set is ~1.6k tokens of always-on metadata. What actually degrades quality
is having many descriptions compete as classifiers, so a language- or project-specific
skill misfires in an unrelated repo.

Rule of thumb: a skill is **global** if it modifies how Claude writes or responds
anywhere (registers like `human-like-text`) or handles a file
format with no natural home repo (`docx`, `pdf`). It is **optional** if it only makes
sense inside one kind of project (`manim` in animation projects,
`excalidraw` in the Obsidian vault, `build-cv` when writing a CV). A language's
practices are neither: they are a stack package of its ecosystem
(`workshop/go/packages/practices/go-practices/`), committed in the project that adds it.

## Code Conventions

- All scripts use `#!/usr/bin/env bash` shebang
- Every script starts with `set -euo pipefail`
- Use `shellcheck`-clean bash
- Use `shellcheck -x` to follow source directives
- Indent with 2 spaces, no tabs
- Functions use `snake_case`
- Quote all variable expansions
- Before every commit/push, audit the staged diff for sensitive information leaks:
  usernames, passwords, API keys, tokens, private IPs, email addresses, or any
  data that should not appear in a public repository. Flag any findings to the user
  before proceeding

## Commands

- Lint: run `shellcheck -x` on every tracked file whose first line is a bash shebang:
  `git ls-files -z | xargs -0 awk 'FNR==1 && /^#!.*bash/ {print FILENAME} {nextfile}' | xargs shellcheck -x`
- Deploy (server): `bash install.sh --profile server --user myuser`
- Deploy (workstation): `bash install.sh --profile workstation --user myuser`
- Dry run: `bash install.sh --profile server --dry-run`

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
7. Run the Lint command from [Commands](#commands) to verify

## Documentation

- **`docs/references.md`** — official doc links and config format notes for every tool.
  Consult before modifying configs, especially after package upgrades.

Detail that only matters inside one directory lives in a `CLAUDE.md` there —
under `common/claude-code/`, `workstation/scripts/`, `workstation/cheatsheets/`
— and loads only when that tree is touched.
