---
name: idea
description: Add one line to the workbench backlog in the user's words — an idea that can be stated in one obvious sentence.
argument-hint: "<one sentence>"
disable-model-invocation: true
---

# Idea: $ARGUMENTS

Invoking this is the user's decision not to open it: a sentence that could
be a bug or feature item is still a backlog line here, not argued with.

1. If it is not one obvious sentence — its meaning needs a criterion, or it
   is an area rather than a thing — say which "Sizing" row of the
   `workbench` skill it is instead, and stop for the user's answer.
2. `workbench idea "<sentence>"` — the user's words, no id, no elaboration.
   It appends to the main checkout's `workbench/BACKLOG.md` wherever it
   runs. Backlog edits are housekeeping; do not commit unless asked.
3. Reply with the line as written. Nothing else.
