---
name: feature
description: Open a workbench feature item from a one-line description and agree its criterion before any code.
argument-hint: "<what should change>"
disable-model-invocation: true
---

# New feature: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

1. **Sizing first.** Draft the criteria this needs, then the
   one-item-or-several test: could any entry go green and merge while the
   others are red? If so, several items, one per slice; if the area is not
   understood well enough to write criteria, a spike. Say which row and
   why, and stop for the user's answer. A description with more than one
   plausible shape gets `/grilling` first; the criteria are drafted after
   the design is settled.
2. `workbench new feature "<title>"` — the description in a few words.
3. Fill **Why** and **What changes** from the description, in glossary
   words — a word that conflicts with an entry, or could mean two things,
   goes to the user with step 1. **Side effects**: what works today and
   behaves differently after — a route, an export, an output — each with
   who sees it, or `none`; the user agrees it with the criterion.
4. Draft **How to confirm it works** — the list from step 1 — run it on
   the unchanged tree so it is seen failing, and bring it to the user.
   Nothing else happens until the criterion is agreed — unattended, as
   "Unattended runs" says.
5. `workbench start <id>`, then work in the worktree it prints.
