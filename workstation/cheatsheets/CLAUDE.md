# Cheatsheets

One HTML cheatsheet for nvim, IdeaVim and tmux, `tools/index.html`. It is not
deployed: the `cheat` alias (`_cheat` in `workstation/zsh/.zshrc-workstation`)
opens it from the repo in a browser app window.

## Scopes and tagging

Keys 1–4 switch the scope: Common (vim motions shared by nvim and IdeaVim),
Neovim, IdeaVim, Tmux. A section without `data-show` shows in Common;
`data-show="nvim|ideavim|tmux"` limits a section, or a `<dt>`/`<dd>` row inside
a Common section, to that scope. The class (`vim`, `ide`, `patterns`, and a
`g-*` group) sets only the accent color (`tools/styles.css`).

The Common sections are grouped by what you're doing (move, edit, augment,
extras, cmdline), each group under a banner comment in the HTML.

## Source of truth

Bindings come from:

- `common/nvim/lua/keymaps.lua`, `common/nvim/lua/plugins/*.lua`
- `common/ideavim/.ideavimrc`
- `common/tmux/tmux.conf.tpl`

When updating: read the live config, mirror only what's bound, never invent. If a binding is added/removed, update the matching `<dl>` row.

The sheet is curated — it shows bindings actually used in this workflow, not every vim default. Don't add textbook entries (e.g. `H`/`L` jumps, `Ctrl+f`/`Ctrl+b` full-page, scroll-line `Ctrl+e`/`Ctrl+y`, `R` replace mode, niche window-resize prefixes) just because they exist in vim. If a row is shadowed by a remap or a plugin, drop it or note the override.
