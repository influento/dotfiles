---
name: spike
description: Open a workbench spike from a one-line area to research and agree its questions before any prototype.
argument-hint: "<the area to research>"
disable-model-invocation: true
---

# New spike: $ARGUMENTS

The `workbench` skill's rules apply; load it if it is not in context.

1. **Sizing first.** A spike is an area not understood well enough to say
   what will be true when it is done. If this can already be described as
   what changes and how to confirm it, it is a bug or feature item, or
   several; say which "Sizing" row and why, and stop for the user's answer.
2. Formulate the questions with `/grilling`, adapted: in a spike the facts
   cannot be looked up, which is what makes it a spike. Grilling ends when
   every unknown is named and scoped, not answered; those named unknowns
   are the questions.
3. `workbench new spike "<title>"` — the area in a few words.
4. Fill **Why** and **Questions**, one line per named unknown, in glossary
   words, and bring them to the user. Nothing else happens until the
   questions are agreed.
5. `workbench start <id>`, then work in the worktree it prints; the
   spike's code goes in the folder beside its item.
