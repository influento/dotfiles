# Configuration References

Quick reference for all configured tools — official docs and config format.
Check these when upgrading tools or debugging config issues.

## Common (all profiles)

| Tool | Docs | Notes |
|---|---|---|
| **zsh + oh-my-zsh** | [oh-my-zsh wiki](https://github.com/ohmyzsh/ohmyzsh/wiki) | Plugins: git, sudo, extract, vi-mode, zsh-autosuggestions, zsh-syntax-highlighting |
| **Starship** | [starship.rs/config](https://starship.rs/config/) | TOML format, module reference has all options |
| **Neovim** | [neovim.io/doc](https://neovim.io/doc/user/) | lazy.nvim plugin manager, lua config |
| **tmux** | [tmux man page](https://man.openbsd.org/tmux.1) | — |
| **Git** | [git-scm.com/docs/git-config](https://git-scm.com/docs/git-config) | Identity in `~/.gitconfig.local` |
| **delta** | [delta manual](https://dandavison.github.io/delta/), `delta --help` | gitconfig `[delta]` section, included by `.gitconfig`; `delta --show-config` prints what is in effect. Package is `git-delta`, binary is `delta` |
| **fontconfig** | [freedesktop fontconfig](https://www.freedesktop.org/software/fontconfig/fontconfig-user.html) | XML format |
| **btop** | [btop GitHub](https://github.com/aristocratos/btop#configurability) | Key=value format |
| **fastfetch** | [fastfetch GitHub](https://github.com/fastfetch-cli/fastfetch/wiki) | JSONC format, module list in wiki |
| **fzf** | [fzf GitHub](https://github.com/junegunn/fzf#environment-variables) | Set in `common/zsh/.zshrc.tpl`. Env vars: `FZF_DEFAULT_OPTS`, `FZF_CTRL_T_OPTS`, `FZF_ALT_C_OPTS` |
| **zoxide** | [zoxide GitHub](https://github.com/ajeetdsouza/zoxide#configuration) | Set in `common/zsh/.zshrc.tpl`. `eval "$(zoxide init zsh)"` |

## Workstation only

| Tool | Docs | Notes |
|---|---|---|
| **LazyGit** | [lazygit config docs](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md) | — |
| **Yazi** | [yazi-rs.github.io/docs](https://yazi-rs.github.io/docs/configuration/yazi) | v25+ renamed `[manager]` → `[mgr]`, shell syntax uses `%s` not `"$@"`, open rules use `url` not `name` |
| **Sway** | [swaywm.org](https://man.archlinux.org/man/sway.5) | i3-compatible syntax |
| **Waybar** | [Waybar wiki](https://github.com/Alexays/Waybar/wiki) | JSON config + CSS styling. `ignore-workspaces` regexes must match the whole name (`std::regex_match`): `^~.*`, not `^~` |
| **Ghostty** | [ghostty.org/docs](https://ghostty.org/docs/config) | Key=value format |
| **swaylock** | [swaylock man](https://man.archlinux.org/man/swaylock.1) | — |
| **swayidle** | [swayidle man](https://man.archlinux.org/man/swayidle.1) | — |
| **mako** | [mako man](https://man.archlinux.org/man/mako.5) | — |
| **swaybg** | [swaybg man](https://man.archlinux.org/man/swaybg.1) | — |
| **wlsunset** | [wlsunset man](https://man.archlinux.org/man/wlsunset.1) | — |
| **SwayOSD** | [SwayOSD GitHub](https://github.com/ErikReider/SwayOSD) | CSS styling |
| **cliphist** | [cliphist GitHub](https://github.com/sentriz/cliphist) | `launcher --dmenu` picker script |
| **GTK 3/4** | [GTK settings](https://docs.gtk.org/gtk3/class.Settings.html) | `settings.ini` + `gtk.css` |
| **Qt6ct** | [qt6ct GitHub](https://github.com/trialuser02/qt6ct) | Qt icon theme + fonts (Fusion style); requires `QT_QPA_PLATFORMTHEME=qt6ct` env var |
| **XDG portal** | [xdg-desktop-portal](https://flatpak.github.io/xdg-desktop-portal/) | Routes portals to wlr backend |
| **xdg-desktop-portal-wlr** | [xdpw GitHub](https://github.com/emersion/xdg-desktop-portal-wlr), `man 5 xdg-desktop-portal-wlr` | INI; `[screencast] chooser_type`/`chooser_cmd` pick the share source; read only at startup |
| **mpv** | [mpv.io/manual](https://mpv.io/manual/stable/) | Themed OSD/OSC, `input.conf` for keybindings, `script-opts/` for script config |
| **yt-dlp** | [yt-dlp GitHub](https://github.com/yt-dlp/yt-dlp#configuration) | One option per line, same syntax as CLI flags |
