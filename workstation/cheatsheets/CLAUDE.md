# Cheatsheets

Standalone HTML/CSS cheatsheets, one directory per tool. Opened via chromium app mode (no browser chrome) and pinned on a sway workspace.

Lives at `~/dev/infra/dotfiles/workstation/cheatsheets/`. The `_cheat` zsh function opens chromium with `file://$HOME/dev/infra/dotfiles/workstation/cheatsheets/<tool>/index.html` directly — no deploy step, no symlink.

## Layout

```
workstation/cheatsheets/
├── CLAUDE.md          # this file (shared launcher / convention info)
├── ideavim/
│   ├── CLAUDE.md      # tool-specific notes
│   ├── index.html
│   └── styles.css     # canonical stylesheet (other tools symlink here)
├── nvim/
│   ├── CLAUDE.md
│   ├── index.html
│   └── styles.css     # → ../ideavim/styles.css
└── tmux/
    ├── CLAUDE.md
    ├── index.html
    └── styles.css     # → ../ideavim/styles.css
```

Each tool gets its own folder containing `index.html` + `styles.css`. Single-file `file://` open works (no build step, no server). `styles.css` is shared via symlink; edit `ideavim/styles.css` and every cheatsheet picks up the change.

## Launcher

A zsh function + per-tool aliases in `~/dev/infra/dotfiles/common/zsh/.zshrc.tpl` (search for `_cheat`).

Pattern:
```zsh
alias cheat-<tool>='_cheat <folder> "<window-title>"'
```

Behavior:
- First call: launches chromium in `--app=` mode, detached from the terminal (no chrome, just title bar + page)
- Subsequent calls: focuses the existing window via `swaymsg [title="…"] focus` instead of opening a duplicate
- Each cheatsheet uses an isolated `--user-data-dir` (`/tmp/chromium-cheat-<name>`)

## Adding a new cheatsheet

1. Create `workstation/cheatsheets/<tool>/` (in the dotfiles repo) with `index.html`
2. Symlink the stylesheet: `ln -s ../ideavim/styles.css workstation/cheatsheets/<tool>/styles.css` (unless the tool needs its own)
3. Set the `<title>` in `index.html` (this is what `swaymsg` matches)
4. Add an alias to `common/zsh/.zshrc.tpl`:
   ```zsh
   alias cheat-<tool>='_cheat <tool> "<exact title from index.html>"'
   ```
5. Run `bash install.sh --profile workstation` to render `.zshrc` (cheatsheet files are read directly from the repo — no deploy step)
6. `reload` (or `source ~/.zshrc`) in any open shell

The `<title>` must match exactly — it's the focus-or-launch key.

## Design conventions (shared)

- **Layout**: CSS multi-column (`column-width` on `main.bricks`) — sections flow as bricks, no grid row-equalization
- **Font**: JetBrains Mono only (single voice)
- **Background**: dark (`#0d1117`)
- **Family colors** (`section` classes — drive `--accent`):
  - `.vim` (or tool-core) — green `#7ee787`
  - `.ide` (or platform-specific) — steel `#79c0ff`
  - `.patterns` (highlight card) — amber `#ffb86c`
- **Density**: ~18px base font, 380px column width, ~95% information density (no decorative chrome)

Tool-specific cheatsheets can adapt the family colors to their own grouping logic — the convention is "color = group", not "green = always vim".

## Open one manually (no alias)

```bash
chromium \
  --app=file:///home/crisp/dev/infra/dotfiles/workstation/cheatsheets/<tool>/index.html \
  --user-data-dir=/tmp/chromium-cheat-<tool> \
  --no-first-run --no-default-browser-check
```
