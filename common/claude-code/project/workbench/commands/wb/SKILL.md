---
name: wb
description: Show what is in flight in workbench, pick up an item by id where it was left, open a session's window, switch the mode, start the lead, or open a rename item for a domain term.
argument-hint: "[<item id> | open <id|lead> | mode [attended|unattended] | lead | rename <old term> to <new term>]"
disable-model-invocation: true
---

# Workbench: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

**No argument** — run `workbench status` and report it in at most five
lines: open items with their branches, research with open-concept counts,
merged items still awaiting a trigger, merged items still open — a fault
to repair first — calls waiting in `DECISIONS.md`, reports awaiting triage
or left unchecked, duplicate ids. Name what is actionable now; omit what is not.

**An id** — pick that item up:

1. `workbench start <id>`. Unstarted, it cuts the branch and worktree;
   started with the worktree gone (removed, or its branch only fetched from
   another machine), it cuts the worktree again; already started, it refuses
   and names the worktree. Archived, it refuses — an archived item is read,
   never reopened. Under a lead (`status` shows a `sessions:` line) it also
   opens the item's worker in its own window and says `opened window <id>`:
   report that and stop — the worker works it, not you. Otherwise enter the
   worktree it names.
2. Read the item file. For research, **Next** is the entry point; for a bug
   or feature, the criterion and whatever Root cause or Evidence already
   holds.
3. State in two lines where the work stands and what you will do next, and
   wait for the user. Change nothing before that.

**`open <id|lead>`** — `workbench open <id|lead>`: switches to that
session's window, reopening it resumed if it is gone. Report the line it
prints, nothing more.

**`mode [attended|unattended]`** — `workbench mode <which>`; with no word,
`workbench mode` and report it. Setting `unattended` prints one `tell
<name>: …` line per live worker: send each that line with `SendMessage`,
then say you did. Setting `attended` the same.

**`lead`** — `workbench lead`. It opens the tmux session and the lead's
window; report the line it prints.

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
