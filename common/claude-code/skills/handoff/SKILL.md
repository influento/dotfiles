---
name: handoff
description: "Write a message that starts the next session on this work."
disable-model-invocation: true
---

Write the first prompt for a fresh session that continues this work. Put it
in the conversation as one fenced block, not in a file unless I ask for one,
and add nothing after it.

Lead with the next steps, in order, each concrete enough to act on: what to
do, where, and how to tell it is done. Everything else in the message serves
those steps:

- work that is half-done or not yet verified
- options we rejected, with the reason, so they are not proposed again
- files, commits and URLs to read first, by reference

Skip what CLAUDE.md, memory or git already tell the next session. Redact
secrets. Write for a reader who has none of this context.
