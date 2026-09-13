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
   others are red? If so this is several items, one per slice; if the area
   is not understood well enough to write criteria at all, it is a spike.
   Say which row and why, and stop for the user's answer. If the
   description has more than one plausible shape, offer `/grilling` first;
   the criteria are drafted after the user has settled the design.
2. `workbench new feature "<title>"` — the description condensed to a few
   words.
3. Fill **Why** and **What changes** from the description, in glossary
   words — a word that conflicts with an entry, or could mean two things,
   goes to the user with step 1. For **What it touches**, run `workbench find <paths>` once with the areas about to
   change and read an item only if its line matches. **Side effects**: what
   works today and behaves differently after — a route, an export, an
   output — each with who sees it, or `none`; the user agrees it with the
   criterion.
4. Draft **How to confirm it works** — the list from step 1 — run it on the
   unchanged tree so it is seen failing, and bring it to the user. Nothing
   else happens until the criterion is agreed — unattended, as "Unattended
   runs" says.
5. `workbench start <id>`, then work in the worktree it prints.
