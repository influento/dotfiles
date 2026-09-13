# Items

## States

| State | Where | Notes |
|---|---|---|
| idea | one line in `workbench/BACKLOG.md`, `workbench idea "<sentence>"` — written to the main checkout wherever it runs | no ID, no file |
| open | `workbench/items/bugs/` or `features/`, committed on the default branch by `workbench new` | freely editable on main until started |
| started | the same file, on its own branch `<id>-<slug>` in `.worktrees/` — `workbench status` marks it `started` | edited on the branch only; main's copy stands as the item started, until the squash overwrites it |
| archived | `workbench/items/archive/` (flat) | locked; records the commit SHA |

An open item may already have merged. See [statuses.md](statuses.md). Where the file
lives at each step, and why: [git.md](git.md), "The item file is on the
default branch from the start".

Promoting an idea to an item means deleting its line from `workbench/BACKLOG.md` and
writing the item file. That act is where the thinking happens — it is the gate,
not a formality.

## IDs

Allocated by `workbench new`, never chosen by hand. Format, allocation and
collision repair are in [git.md](git.md).

## Statuses

The five statuses, abandoning, and what each gate asks:
[statuses.md](statuses.md).

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

## Renames and refactors

A rename changes the project's domain vocabulary and nothing else: a feature
item of its own, whose criterion is the occurrence count over a scope and
whose one commit moves the glossary entry and the code together. Never
absorbed into whichever feature or bug exposed the problem — that widens the
item past its criterion, frozen at `start` ("Mutability" below). Procedure,
homographs and aliases: [glossary.md](glossary.md).

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

A rename is different: it changes vocabulary across a whole area, outside the
host item's scope. A refactor the item needed is inside its scope by
construction.

## Who writes an item

Either side. The user may write one directly, or describe it in a sentence for
the agent to draft and then approve. The agent may also propose an item when it
notices something worth changing.

Size never decides whether an item is written — size is unknowable before
exploring, and a one-line fix still has a story worth recording. Class decides
the shape; size decides nothing.

## Mutability

Until `workbench start`, every field is editable, on main's copy: a bug that
turns out to be deeper than first written has its item updated to match.
`start` freezes the criterion — it is the contract the evidence is matched
against, and the reviewer and the gate hold a step reworded after the code
([verification.md](verification.md)) — and **Side effects** with it: what
works today and changes is agreed before the code, `none` included. What
changes on the branch after that is root cause, evidence and status; a miss
is recorded as a miss, and a side effect the work uncovers is a
`workbench call`, answered by the user editing the section. `merge` holds
the branch to it: `workbench effects <id>` shows what it will refuse.

The single ordering rule behind this: the criterion is written before the
code, the evidence after. Never the reverse — a criterion written afterwards
is just a test chosen because the code already passes it.

Archived items are locked.

## What came before: `workbench find`

When to run it and how much of the index to read: SKILL.md, "What came
before". `--grep <word>` is repeatable. Two classes the index shows:

| Class | Means |
|---|---|
| `unreproduced`, `unverified`, `abandoned` | no commit on the path — matched by naming it in their text. The first two sort first regardless of age: an unproved claim on the file about to change is the hit that bites. `abandoned` was tried and dropped, and says why; it sorts with the rest |
| `on-branch` | an open item on a sibling worktree's branch that names the path — work about to collide with this. A text match, not a trailer, so it can be wrong; shown as its own class for that reason |
