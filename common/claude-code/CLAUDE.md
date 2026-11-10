# Claude Code (source tree)

What each tree here is and how it deploys: the root CLAUDE.md, "Claude Code
Skills", which also says which tree a new skill belongs in.

Skills are drafted and tested with the claude.ai-synced
`anthropic-skills:skill-creator`. Its eval scripts need PyYAML and a browser,
so they only fully work on the workstation.

## settings.json is merged, not symlinked

`~/.claude/settings.json` is deep-merged by `merge_json_config`
(`lib/helpers.sh`); its comment says why a symlink breaks and how the merge
treats each key. Two consequences of merging rather than replacing:

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

Opted into per project by symlink: `skills-optional/CLAUDE.md`.
