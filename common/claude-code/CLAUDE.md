# Claude Code (source tree)

Four things live here, deployed four different ways:

| Path               | Deployed                                                    |
| ------------------ | ----------------------------------------------------------- |
| `settings.json`    | deep-merged into `~/.claude/settings.json`, never symlinked  |
| `skills/`          | symlinked to `~/.claude/skills/` (global)                    |
| `skills-optional/` | never deployed — opted into per project                      |
| `workbench/`       | only `bin/workbench` → `~/.local/bin/`                       |

Why the trees are split, and which tree a new skill belongs in: the root
CLAUDE.md, "Claude Code Skills".

## settings.json is merged, not symlinked

`~/.claude/settings.json` is deep-merged by
`merge_json_config` instead of symlinked. Claude Code saves settings by writing a
temp file and `rename()`-ing it over the target, which replaces the symlink rather
than writing through it, so a symlinked settings file silently degrades into a
stale copy on the first `/config` change. A hard link breaks the same way; a bind
mount makes the write fail with `EBUSY`. On merge, tracked values win for every key
we define — and arrays are replaced wholesale, so dropping one entry from an
allow-list here drops it there — while keys only Claude Code knows about
(`enabledPlugins`, feature flags, onboarding state) survive untouched.

Two consequences of merging rather than replacing:

- **Deletions do not propagate.** Removing a whole key from the tracked file leaves
  it in place in `~/.claude/settings.json`. Delete it there by hand as well.
- **`/config` edits do not show up in `git diff`.** Mirror anything worth keeping
  into the tracked file.

## workbench

Item-tracking workflow CLI, opted into per project. `workbench init` renders its
skills, commands and agents into a project as committed copies and merges the
session wiring into that project's `.claude/settings.json`; `workbench lead` runs
the item's workers as their own Claude sessions in a tmux session.

Layout, `init` mechanics, session model, extension points and its lint/test
commands: `workbench/CLAUDE.md`.

## skills-optional

Opted into per project by symlink, with a caveat about the `go/` grouping:
`skills-optional/CLAUDE.md`.
