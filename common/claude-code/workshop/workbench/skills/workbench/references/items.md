# Items

## States

| State | Where | Notes |
|---|---|---|
| idea | one line in `workbench/BACKLOG.md`, `workbench idea "<sentence>"` — written to the main checkout wherever it runs | no ID, no file |
| open | `workbench/items/bugs/` or `features/`, committed on main by `workbench new` | editable on main until started |
| started | the same file, on its own branch `<id>-<slug>` in `.worktrees/` — `workbench status` marks it `started` | edited on the branch only |
| archived | `workbench/items/archive/` (flat) | locked; records the commit SHA |

An open item may already have merged ("Statuses"). Promoting an idea means
deleting its line from `workbench/BACKLOG.md` and writing the item file.

## Bug items

Every field is best-effort but one: **How to confirm it is fixed** is
mandatory. Root cause has one exception, the bug being unreproducible:
archive it as `unreproduced` rather than leave it open. A fix whose
criterion turns on an event you neither control nor can schedule archives
as `unverified — <trigger>` once everything else about it is verified
([verification.md](verification.md)).

Both are detectors. When a new odd bug appears, or the awaited event
happens and something breaks, search these archived items first: a match
against an `unreproduced` item proves the bug is real and recurring —
reopen it as a normal bug with both sightings as evidence; a match against
an `unverified` item names the assumption that was wrong; a match against a
Root cause of `none found — mitigation` means the mitigation stopped
holding — reopen it the same way. What never recurs stays archived.

## Renames and refactors

A rename is a feature item of its own: [glossary.md](glossary.md),
"Renaming a term".

A refactor is not its own item:

| Case | Where it goes |
|---|---|
| needed to fix a bug or land a feature | inside that item — implementation; the criterion is untouched by it |
| stands alone, with a measurable justification | a feature item, with the measurement as the criterion |
| stands alone, with no measurement | a backlog line, until an item needs it |

The measurement must survive the **Why** field, stated to someone who does
not read code: p99 latency, build time, dependency count, binary size.
"LOC −12%" or "complexity down" does not — a number chosen because the
planned diff moves it is criterion-after-code wearing a number.

## Who writes an item

Either side: the user directly, or in a sentence for the agent to draft and
the user to approve; the agent may propose one.

## Mutability

Until `workbench start`, every field is editable, on main's copy. `start`
freezes the criterion — the reviewer holds a step reworded after the code —
and **Side effects** with it, `none` included. What changes on the branch
after that is root cause, evidence and status. Archived items are locked.

## Statuses

`status:` is the first field of every item.

| Status | Merged? | Archived? | Means |
|---|---|---|---|
| `open` | not yet | no | in flight |
| `awaiting — <trigger>` | yes | never as-is | everything verifiable was verified; the criterion needs an event you can name a time for. When it fires, re-state as `open`, record the evidence, archive |
| `unreproduced` | n/a | yes | a bug that could not be reproduced |
| `unverified — <trigger>` | yes | yes | as `awaiting`, but no bound can be named for the trigger |
| `abandoned — <why>` | never | yes | the user dropped it after it was opened — started or not; the why is the record |

The trigger or the why goes in the status line, not in prose, so grep finds
it. Those five are the whole set — `archive` refuses any other word, `done`
included; an archived item keeps `open`, which under `archive/` means
verified and shipped. `unreproduced` and `unverified` are the only archive
bypasses for a claim about code, and each archives a statement of what was
*not* proved; `abandoned` makes no claim at all.

A provisional status carries ` (agent)` at the end (SKILL.md, "Unattended
runs"): `merge` reads the status the same with or without it; `archive`
refuses it.

**Merged and still `open`, with no branch, is not a state.** It is an item
that merged with its criterion unrun and did not say so. `workbench status`
lists it under its own heading; the repair is to archive it or give it the
status it needed at merge.

### Abandoning

Work the user drops after it was opened is archived as `abandoned — <why>`,
whether started or not, with `commit: none`; deleting the file is the one
exit that leaves nothing greppable, and `git log --grep='^Item: ' --
<path>` is how the next person learns it was tried. Retiring its branch:
[git.md](git.md), "Archiving". Shipped work is not abandoned — with its
trailer on main the item merged, and `archive` refuses the status.

### What each gate asks

| Gate | Asks | Passes with |
|---|---|---|
| merge (`workbench merge`) | has everything that *can* be verified now been verified? — the review dialog's question; the command checks that the item is `open` with a fenced block under Evidence or carries `awaiting` / `unverified` with a trigger | `open` with evidence, or `awaiting` / `unverified` chosen before merge — by the user, or by the agent with ` (agent)` when nobody is there |
| archive (`workbench archive`) | has the criterion been satisfied? — the command checks that a fenced block sits under Evidence, that the status is one of the five, and that no heading outside the template is present; not what the evidence shows | `open` with evidence recorded; `unreproduced`, `unverified` and `abandoned` without |
