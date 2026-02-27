# TODO - Dotfiles

## Project Goal

Profile-driven, idempotent dotfiles manager for user-level configuration.
Deployed by OS installers (arch-workstation, debian-server) with the appropriate profile.

---

## Phase 0: Scaffold

- [x] Directory structure (common/ + workstation/)
- [x] install.sh with profile selection and symlink deployment
- [x] lib/helpers.sh with idempotent link_config and deploy_configs
- [x] lib/log.sh with colored logging
- [x] Empty scaffold configs for all tools
- [x] CLAUDE.md with full documentation

## Phase 1: Theming System

- [x] Central color palette (themes/catppuccin-mocha.sh)
- [x] Template rendering engine (lib/theme.sh)
- [x] --theme CLI flag and theme.conf
- [x] Convert 5 configs to .tpl templates (lazygit, mako, swaylock, swayosd, swaybg)
- [x] Generated files gitignored, only templates tracked

## Phase 2: Workstation Configs

Configs with real content:

- [ ] Sway: keybindings, monitors, workspaces, window rules, startup apps
- [x] Waybar: module layout (workspaces, clock, tray, battery), CSS theme
- [x] Ghostty: font, theme, window settings
- [x] swaylock: colors, indicator, behavior (themed)
- [x] swayidle: lock, screen off, suspend timers
- [x] mako: notification daemon, urgency overrides (themed)
- [x] swaybg: wallpaper launcher (themed)
- [x] wlsunset: night light, temperature schedule
- [x] SwayOSD: volume/brightness popup styling (themed)
- [x] cliphist: clipboard history picker script
- [x] LazyGit: theme, pager, editor (themed)
- [x] btop: theme, layout, vim keys
- [x] fastfetch: system info modules, layout
- [x] fontconfig: font rendering, hinting, default families

Configs still scaffolded (TODOs):

- [ ] GTK: settings.ini with Adwaita-dark / Papirus icons / Noto Sans
- [ ] Qt: qt6ct.conf with Kvantum theme, Papirus icons
- [ ] SDDM: custom theme (placeholder, .gitkeep only)

## Phase 3: Common Configs

- [ ] Zsh: .zshrc with oh-my-zsh plugins, aliases, environment vars, starship eval
- [ ] Neovim: init.lua with lazy.nvim, LSP, treesitter, keymaps
- [ ] tmux: prefix key, mouse, truecolor, status bar, tpm plugins
- [ ] Git: .gitconfig with user identity, aliases, pull strategy, difftool
- [ ] Starship: starship.toml with prompt segments and theme

## Phase 4: Polish

- [ ] Update script (pull latest + re-run install.sh)
- [ ] Uninstall script (remove symlinks, restore backups)
- [ ] Per-machine overrides (hostname-based or local override files)
- [ ] Secret management (ssh keys, tokens — gitcrypt or separate)

## Future Ideas

- [ ] PipeWire / WirePlumber custom config
- [ ] Additional themes (catppuccin-latte, gruvbox, etc.)
- [ ] Theme more configs (sway, waybar, ghostty, starship) as they get content
