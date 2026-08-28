---
name: workbench
description: Run project work as tracked items — every feature and bug fix gets a written item with a verification criterion agreed before code, evidence recorded after, and a git-native link between the item and the commits that implemented it. Use when implementing a feature, fixing a bug, researching an area or concept before it can be an item, deciding whether work is one item, several, or a milestone, running a code review sweep, deciding whether something needs documentation, or preparing work for merge.
---

# Workbench

Work is tracked as **items**. An item states what will change and how anyone
will know it worked, before the code exists. The reader of these items may not
read code at all — items and command output are the only channel they have.

## The loop

```
research     workbench/items/research/<id>-<slug>.md, on its own branch —
             a scope not yet understood; ends by spawning the rows below
idea (workbench/BACKLOG.md line)
  -> item      workbench/items/{bugs,features,renames}/<id>-<slug>.md,
               committed on the default branch as it is created
  -> branch    <id>-<slug>, in its own worktree under .worktrees/; the item
               is edited there from now on, main's copy stands as agreed
  -> work      root cause / implementation
  -> evidence  criterion filled in with real output
  -> merge     workbench merge: squash, commit trailer "Item: <id>"
  -> archive   workbench/items/archive/, records the commit SHA
```

## Hard rules

1. **Domain work is an item.** Features and bug fixes always get one, however
   small, once someone opens them; until then `/idea` is the user's deferral
   ("Sizing"). Housekeeping that is not domain work — configs, agent
   settings, tooling — gets none and may go straight to the main branch.
   Work that cannot yet be described as an item — an area not understood,
   or not clear how it fits — is a research item, and it ends by spawning
   what it decided. Which level a piece of work gets is decided by "Sizing"
   below, the same way every time.

2. **The criterion is written before the code, and it is the contract.**
   Evidence is matched against the criterion, never against a test. Run it
   before writing anything: **a criterion that passes on the unchanged tree is
   not a criterion.** The field holds commands and expected results and
   nothing else: no rationale, no guard ("still does what it did", "behaviour
   unchanged"), no typecheck or build step, no "by inspection". A criterion
   the evidence cannot meet is recorded as **missed**, never reworded to fit.
   Detail on [verification.md](references/verification.md).

3. **Nothing is archived without verified evidence.** Merging is a separate
   gate and asks only whether everything verifiable was verified, so an item may
   ship while still open. Two statuses archive a statement of what was *not*
   proved instead of pretending: `unreproduced`, and `unverified` for a criterion
   only a third party can settle. A third, `abandoned — <why>`, archives a
   decision: work the user dropped, never deleted. See
   [items.md](references/items.md).

4. **State the root cause before writing a fix.** The requirement exists to
   force the investigation, not to produce a sentence.

5. **A test may satisfy only what the criterion describes.** Never write a
   script whose only purpose is to satisfy a criterion, and never test config,
   wiring, or glue unless a criterion demanded it.

6. **Do not write documentation by default.** Code is the truth. Write only
   what cannot be derived by reading the code, and put a discovered fact in the
   item whose work found it rather than in a document of its own. See
   [docs.md](references/docs.md). The standing
   exception is `workbench/GLOSSARY.md`, which holds the project's domain
   language and binds every item written — see
   [glossary.md](references/glossary.md).

7. **Deleting means deleting.** When removing content, leave no trace it
   existed — no "formerly", no "removed in favour of", no inline changelog.
   Git already stores it.

8. **An item has the template's sections and no others.** No "For the
   operator", no "Decisions this took", no "What this did not prove", no
   dated appendix; `archive` refuses them. What did not get proved is one
   line under Evidence. A question that is the user's goes to
   `workbench/DECISIONS.md` through `workbench call`, one line, and the
   reasoning stays in the item. The fields hold what the reader needs to
   judge the claim — a root cause, a criterion, its output — and not the
   reasoning that produced the code; that is in the code, or in the commit.

9. **Some decisions are the user's, and an absent user does not transfer
   them.** Entering `awaiting`, `unverified` or `abandoned`, closing a research concept,
   confirming a sizing, answering a parked call: when nobody is there to
   decide, "Unattended runs" below says what to do instead of deciding.

## Setting up

`workbench init` and `workbench adopt` end with a checklist headed
`setup — decide these with the user`. That output is the list; take each line
to the user, in conversation, before any item is created — none is yours to
settle alone. Three rules the list does not carry:

- permissions: propose the allow-list entries — for a watch, derived from the
  contract's own commands — and write them only with the user's OK
- glossary: seed it with the user's words, never yours
- milestones and watch: ask, create only what the user names, and "not yet"
  is a complete answer

`workbench watch` prints its own next steps for the same reason.

## Unattended runs

A session may run for hours with nobody answering. The loop does not change;
what changes is what happens at a gate that is the user's:

| Gate | Unattended, do this |
|---|---|
| sizing needs confirming | take the item row when it fits; for anything else, `workbench call - "<question>"` and move to work that is describable |
| criterion agreed | run it RED, write it, `workbench call <id> "criterion: …"` in one line, and proceed — the pre-merge review reads it again |
| merged, criterion cannot run yet | set `status: awaiting — <trigger> (agent)` or `unverified — <trigger> (agent)` yourself, and `workbench call <id>` naming the trigger. Never leave a merged item `open`; `status` lists that as a fault |
| a parked call would unblock work | it stays parked. Do other work; do not "resolve" it by doing more work under a new item, and do not reverse it because two later items made it look moot |
| the work looks not worth finishing | `workbench call <id> "abandon? …"` and move on. Never enter `abandoned` yourself, and never delete the item |
| research concept reached a terminal state | write the state with `(agent)` appended and `workbench call <x-id>` it; spawn only what the state names |
| pre-merge review | run it yourself — `/workbench-review pre-merge <id>` — then `review-check`, then triage as "Review sweeps" says. `workbench merge` refuses without a passed review |

`(agent)` is what the user greps for when they return: every provisional
decision, in the file that holds it, plus the one-line index in
`DECISIONS.md`. The user confirms by deleting the marker, or overrules by
editing the item. Nothing else records that a decision was provisional —
not the backlog, not a milestone, not a memory entry.

## Commands

`workbench init` renders five project-scoped skills. `/bug`, `/feature` and
`/research` open an item of that class from a one-line description; `/idea`
appends a backlog line; `/wb` reports what is in flight, with an id picks
that item up where it was left, and with `rename <old> to <new>` opens a
rename item. Each is a thin instruction — the sizing check, the command to
run, the fields to draft — so the rules stay here and the agent runs
`workbench` itself; why they are shaped this way is in
[rationale.md](references/rationale.md), "Why the commands are thin". The
sizing check comes before any id is allocated.

Two settings come with them, in `.claude/settings.json`: `workbench status`
runs at session start so what is in flight is in context before the first
prompt, and `workbench statusline` keeps one line of it in the footer. The
user may strike either.

Skills and settings are copies, committed with the project, so every
worktree and clone has them. `workbench status` says when a copy is behind
its source; `workbench init` refreshes it, and never edit the copy itself.

## Starting work

```bash
workbench new bug "frozen coords"      # allocates id, writes the file, commits it on main
workbench new rename "shard to region" # same, for a vocabulary change
workbench start b-038                  # commits the criterion, then branch + worktree; refuses while the criterion is empty
workbench merge b-038 "<subject>"      # after the pre-merge review: squash, trailer, cleanup
```

IDs are allocated from a counter shared by every worktree, so any worktree may
create an item; the file lands in the main checkout wherever `new` runs.
Never hand-pick an ID. `new` commits on the default branch, so the main
checkout must have it checked out. Between `new` and `start` the item is
edited on main; after `start`, only in its worktree — `merge` and `archive`
refuse if main's copy of a started item moved.

## What came before

```bash
workbench find src/world/pos.go        # items that touched these files, newest first
workbench find src/world --grep resize # narrowed by word; --grep alone searches all items
```

Run it **once**, at the point the item already makes you stop — writing the
root cause of a bug, or what a feature touches — with the paths about to
change. It prints an index, one line per item, capped at ten, unproved items
(`unreproduced`, `unverified`) first. Read an item only when its line matches
the problem in hand, at most the two most recent that do. Nothing is recorded
about having looked; a prior item that changes the decision is cited in the
root cause, where it belongs. Detail in [items.md](references/items.md).

## Sizing — the same call every time

Which level a piece of work gets is settled by one question: **how well can
it be described right now?** Name the row and let the user confirm. The row
decides — not the size of the work, and not tidiness — because past
decisions are relied on.

| It can be described as | It is | Lives as |
|---|---|---|
| what changes and how to confirm it | an item | `workbench new bug\|feature\|rename` |
| the done-criterion, but not yet the items that reach it | a milestone | `workbench milestone`; items attach as they become describable |
| an area — cannot yet say what will be true when it is done, or how it fits, or both | research | `workbench new research` |
| one sentence, obvious what it means, and nobody is opening it now | an idea | a `BACKLOG.md` line, `workbench idea` |

Read the rows from the item down: whatever fits the item row is an item
("Domain work is an item"). The idea row is the one the agent never proposes
for something item-shaped — "crash on save" is a bug. It is not a level of
description but the user's decision to defer, reached only by the user
saying so: `/idea`, or "backlog it". Nothing else in the rule defers.

Research is a scope, not a large idea: many concepts, each ending at a row
above, as another research item when an area turns out to be two, or dropped. A milestone is not a large feature: its done-criterion is at the
level of the project.

**One item or several.** Draft the whole criteria list first, then ask of
each entry: *could this go green and merge while the others are still red?*

| Answer | Shape |
|---|---|
| no entry could | one item, however long the list — one behaviour checked from several angles |
| one or more could | a milestone, one item per slice, each with its own short list |

An item that could ship in halves costs a long-lived branch, one giant squash
and a pre-merge review that must hold everything at once; two items that only
make sense together cannot each satisfy a criterion. One rule applied to N
files — every driver reports itself, every table moves under `src/` — is one
item with one criterion over the set, not N items proving one sentence each,
and not one item now and its twin twenty minutes later. Backlog lines are raw
material: any number may fold into one item and one may split, and nothing
records which lines fed which.

## Milestones

A milestone is a big-picture goal — `workbench milestone "<title>"` — with a
done-criterion at the level of the project. An item may name one with a
`milestone:` line (`workbench new … --milestone <slug>`); most will not, and
no item owes one. Suggest one when the fit is obvious; never ask for one.
[milestones.md](references/milestones.md).

`workbench status` answers what is in flight: open items, items merged and still
`awaiting` a trigger, items merged and still `open` — a fault, see
"Unattended runs" — calls waiting in `DECISIONS.md`, and any duplicate IDs.
Run it rather than reconstructing the answer from `git branch`, which cannot
see the merged ones.

## Research

```bash
workbench new research "rollback netcode"   # x-041
workbench start x-041                        # branch + worktree; prototypes live there
workbench archive x-041 [--discard]          # once every concept is terminal
```

Agree **Scope** with the user before reading anything. Each session rewrites
**Concepts** and **Next** to the current understanding — there is no log, git
holds the history. A concept ends when the user confirms its state:
`-> <id>`, `-> milestone <slug>`, `-> backlog`, or `dropped — <why>`; the
"Sizing" rows decide which, and a spawned item's **Why** cites the research
id. Research never merges. `archive` retires the branch, and refuses while a
concept is open, the Outcome is empty, a state names something that does not
exist, or the branch carries prototypes not yet dropped with `--discard`.
[items.md](references/items.md), "Research items".

## Review sweeps

`/workbench-review <reason> ["scope"]` runs the sweep in a forked context —
a fresh one, with none of this conversation in it — and returns the report
path. Three gates invoke it, whoever is driving:

| Gate | Invoke |
|---|---|
| an item is about to merge | `/workbench-review pre-merge <id>` — `workbench merge` refuses without a passed one on the branch's last commit |
| a milestone's items are all archived | `/workbench-review sweep "<the paths it moved>"` before `milestone archive` |
| `.claude/memory/` changed this session | `/workbench-review memory` before the session ends |

Any other sweep is the user's to ask for — `sweep`, `docs`, `adopt`,
`watch` — never started because the code looks like it needs one.

The fork writes the report, and scratch under `workbench/scratch/` that git
never sees — nothing tracked. When it returns with the path, prove that before
reading the findings:

```bash
workbench review-check <report-path>
```

A failure names what went wrong; say so and do not triage until the user has
seen it. A pass proves the contract held, never that the work was done — what
it checks and where it stops are in [rationale.md](references/rationale.md).

**Triage.** With the user when there is one. Without one, each finding gets
exactly one of: fixed inside the item before merge, when it is within the
item's criterion; `workbench new bug` when it is outside it; a `BACKLOG.md`
line when it is an idea; or a one-line reason in the item's Evidence why it
stands. No finding is dropped silently, and a finding that says the criterion
is not met stops the merge. Then `workbench review-drop`.

## Composing — one session dispatches, workers work

A session that dispatches items to workers never edits code. It runs
`status`, sizes with the user, `new`, agrees the criterion, `start`, and hands
the item off with the line `start` prints; when a worker reports ready it
reads the item — not the diff — decides `awaiting`/`unverified` if the item
needs one, and runs `merge` and `archive`. One merge at a time: two squashes
into one index collide. Workers are the `wb-worker` agent under
`.claude/agents/`, rendered by `init`: one item, in its worktree, never
`merge`. Under agent teams, the composer is the lead and each started item is
a task a teammate claims; workers that touch one path talk to each other,
and `find`'s `on-branch` line says who that is.

**The review loop.** A worker finishes, then:

```
/workbench-review pre-merge <id>      a fresh reviewer, every time
workbench review-check <report>       merge → recorded; hold → counted
  hold:  fix on the branch, review-drop, review again
  merge: review-drop, report ready
```

The reviewer never sees the worker's context or the last round's report, so
each round catches what the previous one did not. Three holds and the worker
stops: `workbench call <id>` with the standing finding, and the merge is the
user's — `merge --no-review` is their override. What the reviewer holds on is
in the sweep skill's `rules/pre-merge.md`; a worker does not argue with a
hold in the item, it fixes or it asks.

Resources a worker may hold — a live client, an account — are named in the
dispatch line, and a worker without one does not take one. Items that need
the same resource run one at a time.

## Watching a running app

A watch is a sweep with a clock. `workbench watch "<title>"` writes the
contract — what healthy is, the only recovery actions allowed, when to
escalate — and the shift runs as

```
/loop 15m /workbench-review watch <slug>
```

Each tick is a fresh fork that appends to one report; the shift ends when
you `review-check` and `review-drop` it, and the timeline's captures become
the bug items' evidence at triage. The watcher observes freely and recovers
only as the contract says. It never fixes. [reviews.md](references/reviews.md).

## By class

| Class | Reference |
|---|---|
| feature, bug, rename — fields, states, IDs, archiving, `find` | [items.md](references/items.md) |
| research — scope, concepts and their states, iterations, closing | [items.md](references/items.md), "Research items" |
| milestones — big-picture goals, optional attachment | [milestones.md](references/milestones.md) |
| domain language, renaming a term, aliases | [glossary.md](references/glossary.md) |
| criteria, evidence, test kinds, RED/GREEN | [verification.md](references/verification.md) |
| review sweeps, reports, triage, watch shifts | [reviews.md](references/reviews.md) |
| what to document and where | [docs.md](references/docs.md) |
| branches, squash, trailers, worktrees, IDs | [git.md](references/git.md) |
| bringing an existing project in | [adopt.md](references/adopt.md) |
| why the workflow is shaped this way, when a rule looks arbitrary | [rationale.md](references/rationale.md) |
