# Claude Code (source tree)

Four things live here, deployed four different ways:

| Path               | Deployed                                                    |
| ------------------ | ----------------------------------------------------------- |
| `settings.json`    | deep-merged into `~/.claude/settings.json`, never symlinked  |
| `skills/`          | symlinked to `~/.claude/skills/` (global)                    |
| `skills-optional/` | never deployed — opted into per project                      |
| `workshop/`        | never linked as a tree — see `workshop/CLAUDE.md`            |

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
allow-list here drops it there, and the install log names every live entry that
goes — while keys only Claude Code knows about (`enabledPlugins`, feature flags,
onboarding state) survive untouched.

Two consequences of merging rather than replacing:

- **Deletions do not propagate.** Removing a whole key from the tracked file leaves
  it in place in `~/.claude/settings.json`. Delete it there by hand as well.
- **`/config` edits do not show up in `git diff`**, and a list entry they add (a
  permission allowed at user scope, say) is dropped by the next install, named in
  its log and kept in the timestamped backup. Mirror anything worth keeping into
  the tracked file.

## workshop

The tools a project installs, as opposed to skills it links. What they are,
what leaves the tree at deploy, and how each reaches a project:
`workshop/CLAUDE.md`.

## skills-optional

Opted into per project by symlink, with a caveat about the `go/` grouping:
`skills-optional/CLAUDE.md`.
