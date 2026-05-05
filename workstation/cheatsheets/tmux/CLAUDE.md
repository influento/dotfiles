# tmux Cheatsheet

Standalone HTML cheatsheet for tmux. Shared launcher / layout conventions live in `../CLAUDE.md`.

## Files

- `index.html` — content (sections, key→description pairs)
- `styles.css` — symlink to `../ideavim/styles.css` (single source of truth for all cheatsheets)

## Open

```bash
cheat-tmux
```

Defined in `~/dev/infra/dotfiles/common/zsh/.zshrc.tpl`. First call launches chromium in app mode; subsequent calls focus the existing window.

## Source of truth

The tmux config this cheatsheet documents lives in the dotfiles repo:

- **Config**: `~/dev/infra/dotfiles/common/tmux/tmux.conf`
- **Symlinked to**: `~/.config/tmux/tmux.conf`
- **tmux-warp**: `~/.local/bin/tmux-warp` + `tmux-warp.sh` (downloaded from `influento/tmux-plugins` release)

When updating this cheatsheet:

1. Read `tmux.conf` to confirm current bindings (prefix, splits, resize, copy-mode, status)
2. The masthead grammar uses `p` as shorthand for the prefix (`Ctrl+Space`); `p X` means "press prefix, then X"
3. If a binding is added/removed/renamed, update the matching `<dl>` row
4. Plugin sections (TPM, vim-tmux-navigator, tmux-yank, tmux-resurrect, tmux-continuum) come from the `set -g @plugin` block in `tmux.conf`

## Layout & color system

CSS multi-column layout — same as ideavim/nvim. Family colors:

| Class       | Color | Use for                                               |
| ----------- | ----- | ----------------------------------------------------- |
| `.vim`      | green | tmux defaults, copy-mode (vi keys), command line, ex  |
| `.ide`      | steel | Custom prefix bindings, plugins, sessions/windows/panes |
| `.patterns` | amber | Killer-patterns highlight card                         |

The split is convention: green = "what you'd find in a generic tmux", steel = "configured/customized in this repo".

## Notation

- `p` — the prefix key (`Ctrl+Space`)
- `p X` — prefix, then X
- `Ctrl+h/j/k/l` (no prefix) — vim-tmux-navigator: traverses panes in tmux and splits in vim
- Items tagged `custom` are bindings defined in `tmux.conf` (not tmux defaults)
