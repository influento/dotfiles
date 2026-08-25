# Memory

Audit the agent's stored memory for this project. It lives under
`~/.claude/projects/<slug>/memory/`, where `<slug>` is the checkout's absolute
path with every character outside `[A-Za-z0-9]` replaced by `-`; `MEMORY.md`
there is the index, one file per fact beside it. A worktree has a different
path and so a different store — check the one for the main checkout as well
as the one you are in. Both stores are in the baseline: a memory file edited,
added or removed fails `review-check` like a tree file would.

A finding is a memory that:

- a commit could make wrong — a technical fact about this project, which
  belongs in the repository or in the item whose work found it
- is already wrong — names a file, flag, function or behaviour that no longer
  exists; cite the check that shows it
- duplicates a repository document

Facts about the user, their machine, preferences or workflow belong in memory
and are not findings. The rules that decide where a fact lives follow.
