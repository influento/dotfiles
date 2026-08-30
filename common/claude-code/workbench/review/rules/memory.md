# Memory

Audit the agent's stored memory for this project. `workbench init` points
`autoMemoryDirectory` at `.claude/memory/` **in the tree**, so that is normally
where it lives: one store shared by every worktree, tracked with the code, with
`MEMORY.md` as the index and one file per fact beside it. `workbench status`
says when the setting is missing or points somewhere else.

Without that setting Claude Code falls back to `~/.claude/projects/<slug>/memory/`,
where `<slug>` is the checkout's absolute path with every character outside
`[A-Za-z0-9]` replaced by `-`. A worktree has a different path and so a
different store, so in that case check the one for the main checkout as well as
the one you are in. `.claude/settings.local.json` can override the setting per
clone, so read it before deciding which store is live.

Whichever is in use is in the baseline: a memory file edited, added or removed
fails `review-check` like a tree file would.

A finding is a memory that:

- a commit could make wrong — a technical fact about this project, which
  belongs in the repository or in the item whose work found it
- is already wrong — names a file, flag, function or behaviour that no longer
  exists; cite the check that shows it
- duplicates a repository document

Facts about the user, their machine, preferences or workflow belong in memory
and are not findings. The rules that decide where a fact lives follow.
