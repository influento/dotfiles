# Items

## States

| State | Where | Notes |
|---|---|---|
| idea | one line in `workbench/BACKLOG.md`, `workbench idea "<sentence>"` — written to the main checkout wherever it runs | no ID, no file |
| open | `workbench/items/bugs/`, `features/`, `renames/` or `research/`, committed on the default branch by `workbench new` | freely editable on main until started |
| started | the same file, on its own branch `<id>-<slug>` in `.worktrees/` — `workbench status` marks it `started` | edited on the branch only; main's copy stands as the item started, until the squash overwrites it |
| archived | `workbench/items/archive/` (flat) | locked; records the commit SHA |

An open item may already have merged. See "Statuses" below. Where the file
lives at each step, and why: [git.md](git.md), "The item file is on the
default branch from the start".

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
| `abandoned — <why>` | never | yes | the user dropped it after it was opened — started or not; the why is the record |

The trigger or the why goes in the status line rather than in prose so that
these can be found by grep — see [git.md](git.md) for what is in flight.
Those five are the whole set — `archive` refuses any other word, `done`
included. An
archived item keeps `open`; under `archive/` that reads as verified and
shipped.

A status entered with nobody to decide it carries ` (agent)` at the end —
`awaiting — the next deploy (agent)` — and a line in `DECISIONS.md` points
at it (SKILL.md, "Unattended runs"). The user confirms by deleting the
marker. `merge` and `archive` read the status the same with or without it;
only `status` and grep tell them apart.

**Merged and still `open`, with no branch, is not a state.** It is an item
that merged with its criterion unrun and did not say so. `workbench status`
lists it under its own heading; the repair is to archive it or give it the
status it needed at merge.

A research item is `open` until archived and nothing else: the other statuses
qualify a claim about code, and research makes none.

`unreproduced` and `unverified` are the only two archive bypasses for a claim
about code. Both archive a statement of what was *not* proved, which is what
keeps the archive honest — an item archived as if it were verified would spend
the one guarantee the whole system provides. `abandoned` is the third and
makes no claim at all: it records a decision.

### Abandoning

Work the user drops after it was opened is archived as `abandoned — <why>`,
whether the item was started or not; deleting the file is the one exit that
leaves nothing greppable, and `workbench find` on the paths it named is how
the next person learns it was tried. One path for both cases, `commit: none`.
A started item's branch is retired by `archive`; half-built work on it is
dropped only with `--discard`, which names each file. Shipped work is not
abandoned — with its trailer on the default branch the item merged, and
`archive` refuses the status. Research never takes it: a research item ends
by spawning or dropping its concepts. Abandoning is the user's decision;
unattended, the agent parks it with `workbench call` and does other work —
`abandoned — … (agent)` is refused at the archive like any provisional
status.

### What each gate asks

This is the one place the status rules live; the other references link here.

| Gate | Asks | Passes with |
|---|---|---|
| merge (`workbench merge`) | has everything that *can* be verified now been verified? — the pre-merge review's question; the command checks that a review passed on the branch's last commit, and that the item is `open` with a fenced block under Evidence or carries `awaiting` / `unverified` with a trigger | `open` with evidence, or `awaiting` / `unverified` chosen at pre-merge — by the user, or by the agent with ` (agent)` when nobody is there |
| archive (`workbench archive`) | has the criterion been satisfied? — the command checks that a fenced block sits under Evidence itself, that the status is one of the five, and that no heading outside the template is present; not what the evidence shows | `open` with evidence recorded; `unreproduced`, `unverified` and `abandoned` without |
| archive, research | has every concept reached a terminal state that names something real, and is the Outcome written? | `open`, no evidence block; the branch retired, `--discard` if it carried prototypes |

Research never passes the merge gate: there is nothing to ship, and what it
decided is spawned as items that pass it themselves.

An item may merge while still open: the worktree goes, the change ships, and
nothing claims success until the criterion runs. `awaiting` is then the only
in-flight state with no branch — `workbench status` reports it beside the
branches. An `unreproduced` bug's branch never merges; `workbench archive`
retires it, provided it carries nothing but the item file — as it retires an
`abandoned` item's, with `--discard` when work is on it. Entering `awaiting`
or `unverified` is the user's decision; unattended, the agent enters it
provisionally with ` (agent)` and a `DECISIONS.md` line, and never merges an
item as plain `open` with its criterion unrun (SKILL.md, "Unattended runs").

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

## Research items

A research item is a **scope**: an area of mechanics or theory not yet
understood well enough to write an item for, or not yet clear how to fit into
this project, or both. It is not a large idea — an idea is one sentence whose
meaning is obvious — and not a milestone, whose done-criterion can already be
stated. Which of the four a piece of work is: SKILL.md, "Sizing".

`workbench new research` writes the fields; `start` gives it a branch and
worktree like any item, and everything tried — prototypes, benchmarks, pasted
sources — lives there, throwaway by definition.

| Field | Holds |
|---|---|
| Scope | the area, what is in and out, the project need behind it — agreed with the user before any reading |
| Concepts | one `### ` heading per mechanic or theory piece, in the project's own words: what it is, how it would fit here, what it would touch; each ending in one `state:` line |
| Next | where to pick up — the resume point, replaced each iteration |
| Outcome | written last: what the scope became, and anything learned that no single concept holds |

### Iterations

Research takes several sessions. Each one rewrites Concepts and Next to the
current understanding; nothing is appended as a log, and git holds what the
earlier understanding was (SKILL.md, "Deleting means deleting"). A discovered fact about a system
we do not control goes into the concept that needed it, as it would go into a
bug's root cause.

### Concept states

Every concept ends in exactly one line, and archive reads them:

| State | Means |
|---|---|
| `state: open` | still being understood |
| `state: -> f-050` | became that item — its first section (a feature's **Why**) cites this research id, and archive checks that it does; `-> x-052` is allowed, an area that turned out to be two |
| `state: -> milestone <slug>` | became that milestone; its items follow, each citing this id |
| `state: -> backlog` | became one obvious sentence in `BACKLOG.md` |
| `state: dropped — <why>` | will not be pursued; the reason is the record |

Which terminal state, and whether one item or several, is the "Sizing" rule.
The agent proposes; **the user confirms every terminal state**, as with
`awaiting` — unattended, the state is written with ` (agent)` appended and
a `DECISIONS.md` line, and `archive` waits for the marker to go. `dropped`
means will not be pursued; a concept that was answered ends `-> <id>`,
`-> backlog`, or is folded into the concept its answer serves — never
`dropped`. An item or milestone is spawned the moment its concept is
describable, while the research stays open — the spawned item runs the normal
loop on its own branch. A prototype worth keeping is copied into that item's
worktree by hand; the research branch is never a base for anything.

### Closing

`workbench archive x-041` refuses while any concept is `open` or lacks a
state line, while a state names an item or milestone that does not exist,
while a named item's first section does not cite `x-041`, while the Outcome
is empty, or — since research never merges — while the
branch carries anything beyond the item file. `--discard` drops the
prototypes, naming each as it goes. The item lands in the archive with
`commit: none`.

A revisit is a new research item citing the old one; nothing reopens.
`workbench find --grep x-041` lists what it spawned, since every spawned
item's first section names it — archive refused otherwise.

## Rename items

A rename changes the project's domain vocabulary and nothing else. It exists as
its own class because the alternative — absorbing it into whichever feature or
bug exposed the problem — widens that item past its criterion, frozen at
`start` ("Mutability" below).

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

Until `workbench start`, every field is editable, on main's copy: a bug that
turns out to be deeper than first written has its item updated to match.
`start` freezes the criterion — it is the contract the evidence is matched
against, and the pre-merge review holds a step reworded after the code
([verification.md](verification.md)). What changes on the branch after that
is root cause, evidence and status; a miss is recorded as a miss. Where the
file lives at each step: [git.md](git.md).

The single ordering rule behind this: the criterion is written before the
code, the evidence after. Never the reverse — a criterion written afterwards
is just a test chosen because the code already passes it.

Archived items are locked.

## What came before: `workbench find`

Retrieval is keyed to files, not topics. `git log` already knows which items
touched a path, through the trailer, so `workbench find <path>...` is exact
and maintains nothing. Words (`--grep <word>`, repeatable) narrow that set, or search every item
when no path is given.

The gates, so it narrows reading instead of adding to it:

| Gate | Rule |
|---|---|
| when | once, while writing **Root cause** or **What it touches** — the fields that already force a pause. Never during implementation |
| input | the paths about to change. Words are opt-in |
| output | an index, one line per item, never bodies. Newest ten; the rest as a count |
| order | `unreproduced` and `unverified` first regardless of age — an unproved claim on the file about to change is the hit that bites. They have no commit on the path, so they are matched by naming the path in their text. An `abandoned` item is matched the same way — it was tried and dropped, and says why — but sorts with the rest |
| `on-branch` | an open item on a sibling worktree's branch that names the path — work about to collide with this. A text match, not a trailer, so it can be wrong; shown as its own class for that reason |
| reading | only an item whose line matches the problem; at most the two most recent |
| recording | nothing. A prior item that changes the decision is cited in the root cause |

If the index routinely sends the agent into five items per bug, the cap is
what to tighten, not the habit to drop.
