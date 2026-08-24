# Items

## States

| State | Where | Notes |
|---|---|---|
| idea | one line in `workbench/BACKLOG.md` | no ID, no file |
| open | `workbench/items/bugs/`, `features/` or `renames/` | freely editable |
| archived | `workbench/items/archive/` (flat) | locked; records the commit SHA |

An open item may already have merged. See "Statuses" below.

Promoting an idea to an item means deleting its line from `workbench/BACKLOG.md` and
writing the item file. That act is where the thinking happens — it is the gate,
not a formality.

## IDs

Allocated by `workbench new`, never chosen by hand. Format, allocation and
collision repair are in [git.md](git.md).

## Statuses

`status:` is the first field of every item.

| Status | Merged? | Archived? | Means |
|---|---|---|---|
| `open` | not yet | no | in flight |
| `awaiting — <trigger>` | yes | **never** | everything verifiable was verified; the criterion needs an event you can name a time for |
| `unreproduced` | n/a | yes | a bug that could not be reproduced |
| `unverified — <trigger>` | yes | yes | as `awaiting`, but no bound can be named for the trigger |

The trigger goes in the status line rather than in prose so that these can be
found by grep — see [git.md](git.md) for what is in flight.

`unreproduced` and `unverified` are the only two archive bypasses. Both archive
a statement of what was *not* proved, which is what keeps the archive honest —
an item archived as if it were verified would spend the one guarantee the whole
system provides.

## Bug items

`workbench new bug` writes the fields, each carrying the guidance for filling
it. Every field but one is best-effort — **How to confirm it is fixed** is
mandatory, because without it the fix has no point: nobody can tell whether it
worked.

Root cause has one real exception, and it is not the mechanism being unclear but
the bug being unreproducible:

### Bugs that cannot be reproduced

Archive them with the status `unreproduced`. Do not leave them open forever — a
pile of permanently open items serves nobody.

Archived `unreproduced` items then act as a **recurrence detector**. When a new
odd bug appears, search them first. A match proves the bug is real and
recurring rather than a phantom: reopen it as a normal bug with both sightings
as evidence. Something that never recurs stays archived, which is the correct
outcome for a phantom.

### Work that only a third party can verify

The same shape, for the same reason. A fix whose criterion turns on an event you
neither control nor can schedule archives as `unverified — <trigger>`, once
everything else about it has been verified
([verification.md](verification.md)).

Those archived items are a detector too. When the event finally happens and
something breaks, search them first: a match names the exact assumption that was
wrong and hands you the reasoning that produced it.

## Rename items

A rename changes the project's domain vocabulary and nothing else. It exists as
its own class because the alternative — absorbing it into whichever feature or
bug exposed the problem — widens that item past its frozen criterion, which
rule 5 forbids.

The class is deliberately narrower than "refactor". General refactors have no
class, and do not get one until something actually needs it.

Full procedure, including homographs and aliases, in [glossary.md](glossary.md).

## Who writes an item

Either side. The user may write one directly, or describe it in a sentence for
the agent to draft and then approve. The agent may also propose an item when it
notices something worth changing.

Size never decides whether an item is written — size is unknowable before
exploring, and a one-line fix still has a story worth recording. Class decides
the shape; size decides nothing.

## Mutability

Open items are freely editable. A bug that turns out to be deeper than first
written should have its item updated to match. No field is frozen.

The single ordering rule: the criterion is written at creation, the evidence
after implementation. Never the reverse — a criterion written afterwards is
just a test chosen because the code already passes it.

Archived items are locked.
