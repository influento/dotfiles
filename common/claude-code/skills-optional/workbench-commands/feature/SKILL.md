---
name: feature
description: Open a workbench feature item from a one-line description and agree its criterion before any code.
argument-hint: "<what should change>"
disable-model-invocation: true
---

# New feature: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

1. **Sizing first.** Draft the criteria this would need, then apply the
   one-item-or-several test: could any entry go green and merge while the
   others are red? If so this is a milestone with an item per slice; if the
   area is not understood well enough to write criteria at all, it is
   research. Say which row and why, and stop for the user's answer.
2. `workbench new feature "<title>"` — the description condensed to a few
   words; `--milestone <slug>` when it belongs to one.
3. Fill **Why** and **What changes** from the description. For **What it
   touches**, run `workbench find <paths>` once with the areas about to
   change and read an item only if its line matches.
4. Draft **How to confirm it works** — the list from step 1 — run it on the
   unchanged tree so it is seen failing, and bring it to the user. Nothing
   else happens until the criterion is agreed.
5. `workbench start <id>`, then work in the worktree it prints.
