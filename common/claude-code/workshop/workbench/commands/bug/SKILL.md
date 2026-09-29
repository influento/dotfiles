---
name: bug
description: Open a workbench bug item from a one-line description and agree its criterion before any code.
argument-hint: "<what was seen>"
disable-model-invocation: true
---

# New bug: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

1. **Sizing first.** A bug is something that behaves wrongly today. If this
   is a feature, several items, or a spike (`/spike`), say which "Sizing"
   row and why, and stop for the user's answer.
2. `workbench new bug "<title>"` — the description in a few words.
3. Fill **What was seen** and **How to reproduce** as far as known, in
   glossary words. Leave **Root cause** for the investigation. Fill
   **Side effects**; the user agrees it with the criterion.
4. Draft **How to confirm it is fixed**, run it on the unchanged tree so it
   is seen failing, and bring it to the user. Nothing else happens until
   the criterion is agreed.
5. `workbench start <id>`, then stop: the user opens a session in the
   worktree it prints and runs `/wb <id>` there.
