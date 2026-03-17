# Configuration References

Quick reference for all configured tools — official docs and config format.
Check these when upgrading tools or debugging config issues.

## Common (all profiles)

| Tool | Config file(s) | Docs | Notes |
|---|---|---|---|
| **zsh + oh-my-zsh** | `common/zsh/.zshrc` | [oh-my-zsh wiki](https://github.com/ohmyzsh/ohmyzsh/wiki) | Plugins: git, sudo, extract, zsh-autosuggestions, zsh-syntax-highlighting |
| **Starship** | `common/starship/starship.toml` | [starship.rs/config](https://starship.rs/config/) | TOML format, module reference has all options |
| **Neovim** | `common/nvim/init.lua`, `lua/` | [neovim.io/doc](https://neovim.io/doc/user/) | lazy.nvim plugin manager, lua config |
| **tmux** | `common/tmux/tmux.conf` | [tmux man page](https://man.openbsd.org/tmux.1) | — |
| **Git** | `common/git/.gitconfig` | [git-scm.com/docs/git-config](https://git-scm.com/docs/git-config) | Identity in `~/.gitconfig.local` |
| **fontconfig** | `common/fontconfig/fonts.conf` | [freedesktop fontconfig](https://www.freedesktop.org/software/fontconfig/fontconfig-user.html) | XML format |
| **btop** | `common/btop/btop.conf` | [btop GitHub](https://github.com/aristocratos/btop#configurability) | Key=value format |
| **fastfetch** | `common/fastfetch/config.jsonc` | [fastfetch GitHub](https://github.com/fastfetch-cli/fastfetch/wiki) | JSONC format, module list in wiki |
| **fzf** | Configured in `.zshrc` | [fzf GitHub](https://github.com/junegunn/fzf#environment-variables) | Env vars: `FZF_DEFAULT_OPTS`, `FZF_CTRL_T_OPTS`, `FZF_ALT_C_OPTS` |
| **zoxide** | Configured in `.zshrc` | [zoxide GitHub](https://github.com/ajeetdsouza/zoxide#configuration) | `eval "$(zoxide init zsh)"` |

## Workstation only

| Tool | Config file(s) | Docs | Notes |
|---|---|---|---|
| **LazyGit** | `workstation/lazygit/config.yml.tpl` | [lazygit config docs](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md) | Themed template, generates `config.yml` |
| **Yazi** | `workstation/yazi/yazi.toml`, `keymap.toml`, `theme.toml` | [yazi-rs.github.io/docs](https://yazi-rs.github.io/docs/configuration/yazi) | v25+ renamed `[manager]` → `[mgr]`, shell syntax uses `%s` not `"$@"`, open rules use `url` not `name` |
| **Sway** | `workstation/sway/config` | [swaywm.org](https://man.archlinux.org/man/sway.5) | i3-compatible syntax |
| **Waybar** | `workstation/waybar/config`, `style.css` | [Waybar wiki](https://github.com/Alexays/Waybar/wiki) | JSON config + CSS styling |
| **Ghostty** | `workstation/ghostty/config` | [ghostty.org/docs](https://ghostty.org/docs/config) | Key=value format |
| **swaylock** | `workstation/swaylock/config.tpl` | [swaylock man](https://man.archlinux.org/man/swaylock.1) | Themed template |
| **swayidle** | `workstation/swayidle/config` | [swayidle man](https://man.archlinux.org/man/swayidle.1) | — |
| **mako** | `workstation/mako/config.tpl` | [mako man](https://man.archlinux.org/man/mako.5) | Themed template |
| **swaybg** | `workstation/swaybg/wallpaper.sh.tpl` | [swaybg man](https://man.archlinux.org/man/swaybg.1) | Themed template |
| **wlsunset** | `workstation/wlsunset/wlsunset.sh` | [wlsunset man](https://man.archlinux.org/man/wlsunset.1) | — |
| **SwayOSD** | `workstation/swayosd/style.css.tpl` | [SwayOSD GitHub](https://github.com/ErikReider/SwayOSD) | Themed CSS |
| **cliphist** | `workstation/cliphist/cliphist-pick.sh` | [cliphist GitHub](https://github.com/sentriz/cliphist) | wofi integration script |
| **GTK 3/4** | `workstation/theming/gtk-3.0/`, `gtk-4.0/` | [GTK settings](https://docs.gtk.org/gtk3/class.Settings.html) | `settings.ini` + `gtk.css` |
| **Qt6ct** | `workstation/theming/qt6ct/qt6ct.conf` | [qt6ct GitHub](https://github.com/trialuser02/qt6ct) | Requires `QT_QPA_PLATFORMTHEME=qt6ct` env var |
| **Kvantum** | `workstation/theming/Kvantum/kvantum.kvconfig` | [Kvantum GitHub](https://github.com/tsujan/Kvantum) | Qt theme engine |
| **XDG portal** | `workstation/xdg-desktop-portal/portals.conf` | [xdg-desktop-portal](https://flatpak.github.io/xdg-desktop-portal/) | Routes portals to wlr backend |
