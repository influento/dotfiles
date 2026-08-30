---
name: research
description: Open a workbench research item for an area not yet understood well enough to be an item, agree its scope, and start the first iteration.
argument-hint: "<the area>"
disable-model-invocation: true
---

# Research: $ARGUMENTS

The `workbench` skill's rules apply — "Sizing", "Research", and
`references/items.md` "Research items"; load it if it is not in context.

1. **Sizing first.** Research is an area not understood yet, or not clear
   how it fits, or both. If this can already be described as an item or a
   milestone, say which row and why, and stop for the user's answer.
2. `workbench new research "<title>"`, then `workbench start <id>` and work
   in the worktree it prints — prototypes and pasted sources live there.
3. Draft **Scope** — the area, what is in and out, the project need behind
   it — and the first **Concepts** as `state: open`, each in the project's
   own words. Bring both to the user before reading anything.
4. Work the iteration. Rewrite Concepts to the current understanding, never
   as a log. Propose a terminal state for any concept that reached one —
   `-> <id>`, `-> milestone <slug>`, `-> backlog`, `dropped — <why>` — and
   let the user confirm; spawn what they confirm right then, its **Why**
   citing this id. Unattended, write the state with ` (agent)` appended
   and `workbench call <id>` it; spawn only what the state names. End by writing **Next**: where the following session
   picks up.
