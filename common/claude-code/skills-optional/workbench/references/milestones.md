# Milestones

A milestone is a big-picture goal with a done-criterion, kept in the project
rather than in a list somewhere else. It is the one level above an item, and
there is no level above it.

```bash
workbench milestone "Remote play"          # workbench/milestones/remote-play.md
workbench new feature "tick rate" --milestone remote-play
workbench milestone archive remote-play   # once its items are archived and evidence is in
```

## What it holds

| Field | Means |
|---|---|
| Goal | what is true of the project once this is done |
| Done when | observable, like an item criterion, at the level of the project |
| Evidence | the actual output, when it is done |

No item list. Items name the milestone themselves with a `milestone: <slug>`
line, and `workbench status` derives progress from that — `2 archived, 1 open`
— so there is nothing to keep in step by hand.

## Attachment is optional

Most items name no milestone, and none has to. Work unrelated to any goal is
done as an item and nothing more; the agent may suggest a milestone when the
fit is obvious and never asks for one. This is deliberate: a milestone exists
to hold the big picture, not to sort every piece of work into it, and the
moment attaching becomes a step it becomes a place to stall.

For the same reason there is no design or brainstorm artifact above the
milestone. Thinking about a direction is a conversation; what it decides lands
in a milestone or an item, or nowhere.

## Archiving

`workbench milestone archive <slug>` refuses while an open item names the
milestone, and without evidence. Moves the file to
`workbench/milestones/archive/`.
