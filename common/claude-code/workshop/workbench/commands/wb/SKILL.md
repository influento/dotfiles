---
name: wb
description: Show what is in flight in workbench, or pick up an item by id where it was left.
argument-hint: "[<item id>]"
disable-model-invocation: true
---

# Workbench: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

**No argument** — run `workbench status` and report it. Name what is
actionable now; omit what is not.

**An id** — pick that item up:

1. `workbench start <id>`. Unstarted, it cuts the branch and worktree;
   started with the worktree gone (removed, or its branch only fetched from
   another machine), it cuts the worktree again; already started, it refuses
   and names the worktree. Archived, it refuses — an archived item is read,
   never reopened. Enter the worktree it names.
2. Read the item file: the criterion and whatever Root cause or Evidence
   already holds.
3. State where the work stands and what you will do next, and wait for the
   user. Change nothing before that.
