# Cheatsheets

Single multi-scope HTML cheatsheet covering nvim, ideavim, and tmux. Opened via Chrome/Chromium app mode (no browser chrome) and pinned on a sway workspace.

The `cheat` zsh alias (`_cheat` in `workstation/zsh/.zshrc-workstation`) finds the repo by resolving the `~/.zshrc-workstation` symlink, then opens `workstation/cheatsheets/tools/index.html` from it in Chrome (Chromium as fallback, via `_chrome_bin`) — no deploy step, no symlink. A second call focuses the open window.

## Scopes

The page has a four-mode top-bar switcher (keys 1/2/3/4):

| Key | Scope    | Shows                                   |
| --- | -------- | --------------------------------------- |
| 1   | Common   | Vim motions shared by nvim and ideavim  |
| 2   | Neovim   | nvim-specific deltas (plugins, extras)  |
| 3   | IdeaVim  | ideavim-specific deltas (IDE actions)   |
| 4   | Tmux     | tmux defaults + custom prefix bindings  |

Switcher state persists in `localStorage` under `tools-cheat-scope`.

## Section tagging

Sections without a `data-show` attribute are vim-family (visible in Common). Tool-specific sections use:

```html
<section class="vim" data-show="nvim">…</section>
<section class="ide" data-show="ideavim">…</section>
<section class="ide" data-show="tmux">…</section>
```

Row-level overrides inside a vim-family section use `data-show` on `<dt>`/`<dd>`/`<span>`. Mastheads use `data-family="vim"` or `data-family="tmux"` so the right one shows per scope.

## Section ordering

Vim-core sections are grouped by **what you're doing** so a glance matches a goal:

- **A · move** — Modes, Motion · line, Motion · file & screen, Jumps, Search & replace
- **B · edit** — Visual, Visual block, Text objects, Edit, Insert
- **C · augment** — Surround & comment, Folds, Registers & macros, Marks
- **Extras** — `data-show="nvim"` / `data-show="ideavim"` deltas, tail of vim-core
- **D · cmdline** — Ex ranges, Session (custom)

Each group carries a `g-*` class, whose accent overrides the family color (`styles.css`).

## Source of truth

Bindings come from:

- `common/nvim/lua/keymaps.lua`, `common/nvim/lua/plugins/*.lua`
- `common/ideavim/.ideavimrc`
- `common/tmux/tmux.conf.tpl`

When updating: read the live config, mirror only what's bound, never invent. If a binding is added/removed, update the matching `<dl>` row.

The sheet is curated — it shows bindings actually used in this workflow, not every vim default. Don't add textbook entries (e.g. `H`/`L` jumps, `Ctrl+f`/`Ctrl+b` full-page, scroll-line `Ctrl+e`/`Ctrl+y`, `R` replace mode, niche window-resize prefixes) just because they exist in vim. If a row is shadowed by a remap or a plugin, drop it or note the override.

## Design conventions

Family classes set a section's accent: `.vim` for vim core and shared rows, `.ide` for plugin, leader and IDE actions. Colors, column widths, breakpoints and the print layout are in `tools/styles.css`.
