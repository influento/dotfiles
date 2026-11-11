# Claude Code (source tree)

What each tree here is, how it deploys and which tree a new skill belongs in:
the root CLAUDE.md, "Claude Code Skills".

Skills are drafted and tested with the claude.ai-synced
`anthropic-skills:skill-creator`. Its `quick_validate.py`, which
`package_skill.py` runs, needs PyYAML: `python-yaml` from arch-install.

## settings.json is merged, not symlinked

`~/.claude/settings.json` is deep-merged by `merge_json_config`
(`lib/helpers.sh`); its comment says why a symlink breaks and how the merge
treats each key. What that means when editing settings:

- **Deletions do not propagate.** Removing a whole key from the tracked file leaves
  it in place in `~/.claude/settings.json`. Delete it there by hand as well.
- **`/config` edits do not show up in `git diff`, and the next install undoes
  them.** A list entry they add (a permission allowed at user scope, say) is
  dropped and named in the install log. A changed key the tracked file also sets
  (`model`, `effortLevel`, `outputStyle`) goes back with no log line. The
  timestamped backup keeps both. Mirror anything worth keeping into the tracked
  file.
