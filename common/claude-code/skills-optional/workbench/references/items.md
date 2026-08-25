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

`status:` is the first field of every item. An optional `milestone: <slug>`
line may follow it — see [milestones.md](milestones.md).

| Status | Merged? | Archived? | Means |
|---|---|---|---|
| `open` | not yet | no | in flight |
| `awaiting — <trigger>` | yes | never as-is | everything verifiable was verified; the criterion needs an event you can name a time for. When it fires, re-state as `open`, record the evidence, archive |
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

### Work that only a third party can verify

The same shape, for the same reason. A fix whose criterion turns on an event you
neither control nor can schedule archives as `unverified — <trigger>`, once
everything else about it has been verified
([verification.md](verification.md)).

### Both are detectors

When a new odd bug appears, or the awaited event finally happens and something
breaks, search these archived items first. A match against an `unreproduced`
item proves the bug is real and recurring rather than a phantom — reopen it as
a normal bug with both sightings as evidence. A match against an `unverified`
item names the exact assumption that was wrong and hands you the reasoning that
produced it. Something that never recurs stays archived, which is the correct
outcome for a phantom.

## Rename items

A rename changes the project's domain vocabulary and nothing else. It exists as
its own class because the alternative — absorbing it into whichever feature or
bug exposed the problem — widens that item past its frozen criterion, which
rule 5 forbids.

### Refactors

A refactor is not its own item.

| Case | Where it goes |
|---|---|
| needed to fix a bug or land a feature | inside that item — it is implementation, and the item's criterion is untouched by it |
| stands alone, with a measurable justification | a feature item, with the measurement as the criterion |
| stands alone, with no measurement | a backlog line, until an item needs it |

The measurement must survive the **Why** field, stated to someone who does not
read code: p99 latency, build time, dependency count, binary size. "LOC −12%" or
"complexity down" does not — a number chosen because the planned diff happens to
move it is criterion-after-code wearing a number.

"The behaviour is unchanged" is never the criterion. It is a preservation guard
and belongs in Evidence ([verification.md](verification.md)) — a no-op passes it.

This does not contradict the reason `rename` is its own class. A rename changes
vocabulary across a whole area, outside the host item's scope, so absorbing it
widens that item. A refactor the item needed is inside its scope by
construction.

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

## What came before: `workbench find`

Retrieval is keyed to files, not topics. `git log` already knows which items
touched a path, through the trailer, so `workbench find <path>...` is exact
and maintains nothing. Words (`--grep`) narrow that set, or search every item
when no path is given.

The gates, so it narrows reading instead of adding to it:

| Gate | Rule |
|---|---|
| when | once, while writing **Root cause** or **What it touches** — the fields that already force a pause. Never during implementation |
| input | the paths about to change. Words are opt-in |
| output | an index, one line per item, never bodies. Newest ten; the rest as a count |
| order | `unreproduced` and `unverified` first regardless of age — an unproved claim on the file about to change is the hit that bites. They have no commit on the path, so they are matched by naming the path in their text |
| reading | only an item whose line matches the problem; at most the two most recent |
| recording | nothing. A prior item that changes the decision is cited in the root cause |

If the index routinely sends the agent into five items per bug, the cap is
what to tighten, not the habit to drop.
