# TODO - Dotfiles

## Project Goal

Profile-driven, idempotent dotfiles manager for user-level configuration.
Deployed by OS installers (arch-workstation, debian-server) with the appropriate profile.

---

## Phase 0: Scaffold (current)

- [x] Directory structure (common/ + workstation/)
- [x] install.sh with profile selection and symlink deployment
- [x] lib/helpers.sh with idempotent link_config and deploy_configs
- [x] lib/log.sh with colored logging
- [x] Empty scaffold configs for all tools
- [x] CLAUDE.md with full documentation

## Phase 1: Common Configs (server + workstation)

Fill in the scaffold configs with real, working content.

- [ ] Zsh: .zshrc with oh-my-zsh plugins, aliases, environment vars
- [ ] Neovim: init.lua with lazy.nvim, LSP, treesitter, keymaps
- [ ] tmux: prefix key, mouse, truecolor, status bar, tpm plugins
- [ ] Git: .gitconfig with user template, aliases, pull strategy, difftool
- [ ] Starship: starship.toml with prompt segments and theme

## Phase 2: Workstation Configs

- [ ] Hyprland: keybindings, monitors, workspaces, animations, startup apps
- [ ] Waybar: module layout (workspaces, clock, tray, battery), CSS theme
- [ ] Ghostty: font (JetBrains Mono), theme, window settings
- [ ] GTK: Adwaita-dark / Papirus icons / Noto Sans
- [ ] Qt: Kvantum theme, Papirus icons
- [ ] SDDM: custom theme (or themed existing)

## Phase 3: Polish

- [ ] Update script (pull latest + re-run install.sh)
- [ ] Uninstall script (remove symlinks, restore backups)
- [ ] Per-machine overrides (hostname-based or local override files)
- [ ] Secret management (ssh keys, tokens — gitcrypt or separate)

## Future Ideas

- [ ] PipeWire / WirePlumber custom config
- [ ] Clipboard history (cliphist config)
- [ ] App-specific configs (lazygit, btop, yazi)
- [ ] Color scheme system (single source of truth for all tools)
