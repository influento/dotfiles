# Memory

Audit the agent's stored memory for this project. Where it lives, and the
`~/.claude/projects/<slug>/memory/` fallback when the setting is missing, are
in the reference printed after these rules — read that first and decide which
store is live before auditing it. A worktree without the setting has a store
of its own, so check the main checkout's too.

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
