---
name: wb
description: Show what is in flight in workbench, pick up an item by id where it was left, or open a rename item for a domain term.
argument-hint: "[<item id> | rename <old term> to <new term>]"
disable-model-invocation: true
---

# Workbench: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

**No argument** — run `workbench status` and report it in at most five
lines: open items with their branches, research with open-concept counts,
merged items still awaiting a trigger, reports awaiting triage or left
unchecked, duplicate ids. Name what is actionable now; omit what is not.

**An id** — pick that item up:

1. `workbench start <id>`. Unstarted, it cuts the branch and worktree;
   started with the worktree gone (removed, or its branch only fetched from
   another machine), it cuts the worktree again; already started, it refuses
   and names the worktree. Enter the worktree it names. Archived, it
   refuses — an archived item is read, never reopened.
2. Read the item file. For research, **Next** is the entry point; for a bug
   or feature, the criterion and whatever Root cause or Evidence already
   holds.
3. State in two lines where the work stands and what you will do next, and
   wait for the user. Change nothing before that.

**`rename <old> to <new>`** — open a rename item (the skill's glossary
reference applies):

1. Confirm the old term is domain vocabulary — in `workbench/GLOSSARY.md`,
   or used in a narrower sense than the general one. If it is not, this is
   a refactor inside whatever item needs it, not a rename; say so and stop.
2. `workbench new rename "<old> to <new>"`.
3. Fill **The term** with the glossary entry that changes in the same
   commit, and **Scope** with the paths holding the domain sense — and any
   path where the word has a non-domain sense, to stay out of.
4. **How to confirm it is done** is the occurrence count over the scope:
   take it now, before the change, and bring scope and count to the user.
5. `workbench start <id>`, then work in the worktree it prints.
