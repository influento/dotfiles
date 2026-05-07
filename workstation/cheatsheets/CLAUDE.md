# Cheatsheets

Single multi-scope HTML cheatsheet covering nvim, ideavim, and tmux. Opened via chromium app mode (no browser chrome) and pinned on a sway workspace.

Lives at `~/dev/infra/dotfiles/workstation/cheatsheets/`. The `cheat` zsh alias opens chromium with `file://$HOME/dev/infra/dotfiles/workstation/cheatsheets/tools/index.html` directly — no deploy step, no symlink.

## Layout

```
workstation/cheatsheets/
├── CLAUDE.md     # this file
└── tools/
    ├── index.html
    └── styles.css
```

## Scopes

The page has a tri/quad-mode top-bar switcher (keys 1/2/3/4):

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

## Launcher

`cheat` zsh alias in `common/zsh/.zshrc.tpl`:

- First call launches chromium in `--app=` mode, detached (no browser chrome, just title bar + page)
- Subsequent calls focus the existing window via `swaymsg [title="Tools cheatsheet"] focus`
- Isolated `--user-data-dir` (`/tmp/chromium-cheat-tools`)

## Source of truth

Bindings come from:

- `common/nvim/lua/keymaps.lua`, `common/nvim/lua/plugins/*.lua`
- `common/ideavim/.ideavimrc`
- `common/tmux/tmux.conf`

When updating: read the live config, mirror only what's bound, never invent. If a binding is added/removed, update the matching `<dl>` row.

## Design conventions

- **Layout**: CSS multi-column (`column-width` on `main.bricks`) — sections flow as bricks, no row-equalization
- **Font**: JetBrains Mono only
- **Background**: dark (`#0d1117`)
- **Family colors** drive `--accent`:
  - `.vim` (vim core / shared) — green `#7ee787`
  - `.ide` (plugin / leader / IDE actions) — steel `#79c0ff`
  - `.patterns` (highlight card) — amber `#ffb86c`
  - `[data-scope="tmux"]` masthead/button accent — violet `#c4a7e7`
- **Density**: ~18px base, 380px column width

## Adaptive

- Default: ~380px columns
- ≥1800px: 360px columns, 16px font
- ≥2400px: 400px columns, 17px font
- ≤600px: single column
- Print: 3 columns, white background, monochrome
