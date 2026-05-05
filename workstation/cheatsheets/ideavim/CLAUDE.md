# IdeaVim Cheatsheet

Standalone HTML cheatsheet for IdeaVim. Shared launcher / layout conventions live in `../CLAUDE.md`.

## Files

- `index.html` — content (sections, key→description pairs)
- `styles.css` — dark mono theme, column-pack layout, family color hierarchy

## Open

```bash
cheat-ideavim
```

Defined in `~/dev/infra/dotfiles/common/zsh/.zshrc.tpl`. First call launches chromium in app mode; subsequent calls focus the existing window.

## Source of truth

The IdeaVim config this cheatsheet documents lives in the dotfiles repo:

- **Config**: `~/dev/infra/dotfiles/common/ideavim/.ideavimrc`
- **Symlinked to**: `~/.ideavimrc`
- **Long-form reference**: `~/Dropbox/data-vault/dev-ops/cheatsheet/ideavim.md`

When updating this cheatsheet:

1. Read `~/dev/infra/dotfiles/common/ideavim/.ideavimrc` to confirm what's actually mapped
2. Mirror only what's there — don't invent bindings
3. If a binding is added/removed/renamed in `.ideavimrc`, update the matching `<dl>` row in `index.html`

## Layout & color system

CSS multi-column layout (`column-width` on `main.bricks`) — sections flow as bricks top-to-bottom in each column, no row-height equalization.

**Family colors** (`section` classes, drive `--accent`):

| Class | Color  | Use for                                                  |
| ----- | ------ | -------------------------------------------------------- |
| `.vim`      | green  | Pure vim — motion, edit, search, text objects, registers, ex |
| `.ide`      | steel  | IDE / leader chords — find, tool windows, debug, code intel  |
| `.patterns` | amber  | Killer-patterns highlight card                            |

The accent shows up as: 3px left border, section heading color, `dt` (key) column color.

## Adding a new section

```html
<section class="vim">  <!-- or .ide / .patterns -->
  <h2>Section title</h2>
  <dl>
    <dt>key</dt><dd>description</dd>
    ...
  </dl>
</section>
```

For an inline note in the heading:
```html
<h2>Title <span class="hint">after d c y v</span></h2>
```

For an inline `code` snippet inside a description, use `<code>…</code>` (renders neutral, doesn't fight with the family accent).

## Open it

```bash
xdg-open ~/dev/infra/dotfiles/workstation/cheatsheets/ideavim/index.html
```

Or `file:///home/crisp/dev/infra/dotfiles/workstation/cheatsheets/ideavim/index.html` in any browser.

## Adaptive

- Default: ~320px columns
- ≥1800px wide: 360px columns, slightly larger font
- ≥2400px wide: 400px columns
- ≤600px: single column
- Print: 3 columns, white background, monochrome
