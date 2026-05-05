# Neovim Cheatsheet

Standalone HTML cheatsheet for Neovim. Shared launcher / layout conventions live in `../CLAUDE.md`.

## Files

- `index.html` — content (sections, key→description pairs)
- `styles.css` — symlink to `../ideavim/styles.css` (single source of truth for all cheatsheets)

## Open

```bash
cheat-nvim
```

Defined in `~/dev/infra/dotfiles/common/zsh/.zshrc.tpl`. First call launches chromium in app mode; subsequent calls focus the existing window.

## Source of truth

The Neovim config this cheatsheet documents lives in the dotfiles repo:

- **Config root**: `~/dev/infra/dotfiles/common/nvim/`
  - `init.lua`, `lua/options.lua`, `lua/keymaps.lua`, `lua/autocmds.lua`
  - `lua/plugins/*.lua` — one file per plugin, leader bindings live here
- **Symlinked to**: `~/.config/nvim/`

When updating this cheatsheet:

1. Read all of `lua/keymaps.lua`, `lua/autocmds.lua`, and every `lua/plugins/*.lua`
2. Mirror only what's mapped — don't invent bindings
3. Built-in vim core stays the same as ideavim (modes, motions, edit, text objects, ex)
4. Plugin sections (LSP, fzf-lua, neo-tree, flash, gitsigns, dap, easy-dotnet, mini.surround) come from each plugin's `keys = { ... }` table
5. If a binding is added/removed/renamed, update the matching `<dl>` row

## Layout & color system

CSS multi-column layout — same as ideavim. Family colors:

| Class       | Color | Use for                                                |
| ----------- | ----- | ------------------------------------------------------ |
| `.vim`      | green | Vim core — motion, edit, text objects, registers, ex   |
| `.ide`      | steel | Plugin / leader chords — fzf-lua, LSP, dap, neo-tree   |
| `.patterns` | amber | Killer-patterns highlight card                          |

## Adding a new section

```html
<section class="vim">  <!-- or .ide / .patterns -->
  <h2>Section title <span class="hint">optional plugin name</span></h2>
  <dl>
    <dt>key</dt><dd>description</dd>
    ...
  </dl>
</section>
```
