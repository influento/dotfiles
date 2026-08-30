---
name: bug
description: Open a workbench bug item from a one-line description and agree its criterion before any code.
argument-hint: "<what was seen>"
disable-model-invocation: true
---

# New bug: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

1. **Sizing first.** If this is not a bug — a feature, several items, a
   milestone, or research — say which "Sizing" row it is and why, and stop
   for the user's answer. A bug is something that behaves wrongly today.
2. `workbench new bug "<title>"` — the description condensed to a few words.
3. Fill **What was seen** from the description and **How to reproduce** as
   far as it is known. Leave **Root cause** for the investigation.
4. Draft **How to confirm it is fixed**, run it on the unchanged tree so it
   is seen failing, and bring it to the user. Nothing else happens until the
   criterion is agreed — unattended, `workbench call <id>` it in one line and
   proceed; the pre-merge review reads it again.
5. `workbench start <id>`, then work in the worktree it prints.
