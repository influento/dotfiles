---
name: idea
description: Add one line to the workbench backlog in the user's words — an idea that can be stated in one obvious sentence.
argument-hint: "<one sentence>"
disable-model-invocation: true
---

# Idea: $ARGUMENTS

The `workbench` skill's "Sizing" row for an idea: one sentence, obvious what
it means, and nobody is opening it now. Invoking this command is the user's
decision not to open it — a sentence that could be a bug or feature item is
still a backlog line here, and is not argued with.

1. If it is not one obvious sentence — its meaning needs a criterion to be
   clear, or it is an area rather than a thing — say which "Sizing" row it
   is instead, and stop for the user's answer.
2. `workbench idea "<sentence>"` — the user's words, no id, no elaboration.
   It appends to the main checkout's `workbench/BACKLOG.md` wherever it
   runs, so from a worktree the line does not ride that item's squash.
   Backlog edits are housekeeping; do not commit unless asked.
3. Reply with the line as written. Nothing else.
