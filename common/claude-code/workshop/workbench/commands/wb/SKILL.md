---
name: wb
description: Show what is in flight in workbench, or pick up an item by id where it was left.
argument-hint: "[<item id>]"
disable-model-invocation: true
---

# Workbench: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

**No argument** — run `workbench status` and report what is actionable
now.

**An id** — pick that item up:

1. `workbench start <id>`: unstarted, it cuts the branch and worktree;
   started with the worktree gone, it cuts the worktree again; already
   started, it refuses and names the worktree; archived, it refuses — an
   archived item is read, never reopened. Enter the worktree it names.
2. Read the item: the criterion and whatever Root cause or Evidence holds;
   for a spike, its Questions and Findings.
3. State where the work stands in one line. A line under `## Decisions`
   waits on the user: stop there. Otherwise carry on from that point with
   the `wb-worker` steps, in this session.
