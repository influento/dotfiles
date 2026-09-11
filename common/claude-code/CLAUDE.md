# Claude Code (source tree)

Four things live here, deployed four different ways:

| Path               | Deployed                                                    |
| ------------------ | ----------------------------------------------------------- |
| `settings.json`    | deep-merged into `~/.claude/settings.json`, never symlinked  |
| `skills/`          | symlinked to `~/.claude/skills/` (global)                    |
| `skills-optional/` | never deployed — opted into per project                      |
| `project/`         | only `workbench/bin/workbench` → `~/.local/bin/`             |

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

## project

The tools a project installs, as opposed to skills it links: `workbench`, the
item-tracking workflow CLI; `ts-gate`, the TypeScript Stop-hook gate; and
`stack`, the Effect-first registry of the libraries a project chooses
(`stack add effect`, or the `service` and `fullstack` presets). All are copied
into a project and committed there, never symlinked. How they fit together,
their shared backlog, and the pointers into each: `project/CLAUDE.md`.

## skills-optional

Opted into per project by symlink, with a caveat about the `go/` grouping:
`skills-optional/CLAUDE.md`.
