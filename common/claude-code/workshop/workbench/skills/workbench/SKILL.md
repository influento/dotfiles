---
name: workbench
description: Run project work as tracked items — every feature and bug fix gets a written item with a verification criterion agreed before code, evidence recorded after, and a git-native link between the item and the commits that implemented it. Use when implementing a feature, fixing a bug, deciding whether work is one item or several, running the review dialog or a docs sweep, deciding whether something needs documentation, or preparing work for merge.
---

# Workbench

Work is tracked as **items**. An item states what will change and how anyone
will know it worked, before the code exists. The reader of these items may not
read code at all — items and command output are the only channel they have.

## The loop

```
idea (workbench/BACKLOG.md line)
  -> item      workbench/items/{bugs,features}/<id>-<slug>.md,
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
   Which level a piece of work gets is "Sizing" below, the same way every
   time.

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
   [statuses.md](references/statuses.md).

4. **State the root cause before writing a fix.** The requirement exists to
   force the investigation, not to produce a sentence.

5. **A test may satisfy only what the criterion describes.** Never write a
   script whose only purpose is to satisfy a criterion, and never test config,
   wiring, or glue unless a criterion demanded it.

6. **Do not write documentation by default.** Code is the truth. Write only
   what cannot be derived by reading the code. A discovered fact becomes code
   or a comment at its call site, never a document and never an item line of
   its own. See
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
   line under Evidence. A question that is the user's goes under the item's
   own `## Decisions` through `workbench call`, one line, and the reasoning
   stays in the item; the answer goes into the field it changes and the line
   is deleted, so the section holds open questions only. The fields hold
   what the reader needs to judge the claim — a root cause, a criterion, its
   output — and not the reasoning that produced the code; that is in the
   code, or in the commit.

9. **Some decisions are the user's, and an absent user does not transfer
   them.** "Unattended runs" below says what to do at each instead of
   deciding.

10. **The project has no scratch folder.** A file that exists only for this
    session — a probe, a capture, a diagram, a rendered page, a call stack —
    goes to the scratchpad directory the environment names, outside the tree.
    A review sweep's probes go under `workbench/scratch/<report>/` and leave
    with the report. Nothing else is scratch: a fact worth keeping is a line
    in the item's Evidence or a backlog entry, never a file of its own.

## Setting up

`workbench init` and `workbench adopt` end with a checklist headed
`setup — decide these with the user`. That output is the list; take each line
to the user, in conversation, before any item is created — none is yours to
settle alone. Two rules the list does not carry:

- permissions: propose the allow-list entries and write them only with the
  user's OK
- glossary: seed it with the user's words, never yours

## Unattended runs

A session may run for hours with nobody answering. The loop does not change;
what changes is what happens at a gate that is the user's:

| Gate | Unattended, do this |
|---|---|
| sizing needs confirming | take the item row when it fits; for anything else, `workbench call - "<question>"` and move to work that is describable |
| criterion agreed | run it RED, write it, `workbench call <id> "criterion: …"` in one line, and proceed — the reviewer reads it again |
| merged, criterion cannot run yet | set `status: awaiting — <trigger> (agent)` or `unverified — <trigger> (agent)` yourself, and `workbench call <id>` naming the trigger. Never leave a merged item `open`; `status` lists that as a fault |
| a parked call would unblock work | it stays parked. Do other work; do not "resolve" it by doing more work under a new item, and do not reverse it because two later items made it look moot |
| the work looks not worth finishing | `workbench call <id> "abandon? …"` and move on. Never enter `abandoned` yourself, and never delete the item |
| a question only the user can answer | `workbench call <id> "<the question, with options>"`, then move to work that is describable |
| a permission not on the allow-list | a non-interactive session is refused it by Claude Code, and the refusal is what you see; park it with `workbench call`, never work around it |
| review | the dialog, yourself — "The review loop" below — then triage as "Review sweeps" says; the gate only when the user asked for one |

`(agent)` is what the user greps for when they return: every provisional
decision, in the file that holds it, and `workbench status` lists every
open `## Decisions` line beside it. The user confirms by deleting the
marker, or overrules by editing the item. A question tied to no item
(`workbench call -`) is the one thing `workbench/DECISIONS.md` still holds.
Nothing else records that a decision was provisional — not the backlog,
not a memory entry.

## Commands

`/bug`, `/feature`, `/idea` and `/wb` are thin instructions —
the sizing check, the command to run, the fields to draft — so the rules
stay here. Skills, agents and settings are copies, committed with the
project, so every worktree and clone has them. `workbench status` says when
a copy is behind its source; `workbench init` refreshes it, and never edit
the copy itself.

## Starting work

```bash
workbench new bug "frozen coords"      # allocates id, writes the file, commits it on main
workbench start b-038                  # commits the criterion, then branch + worktree; refuses while the criterion is empty
workbench merge b-038 "<subject>"      # after the review dialog: squash, trailer, cleanup
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
| what changes and how to confirm it | an item | `workbench new bug\|feature` |
| an area — cannot yet say what will be true when it is done, or how it fits, or both | a spike | a feature item whose criterion is the question it answers and whose evidence is the answer; what it decides becomes items or `BACKLOG.md` lines, and the spike's branch merges only what is describable by then |
| one sentence, obvious what it means, and nobody is opening it now | an idea | a `BACKLOG.md` line, `workbench idea` |

Read the rows from the item down: whatever fits the item row is an item
("Domain work is an item"). The idea row is never the agent's proposal for
something item-shaped — "crash on save" is a bug; it is the user's deferral,
reached only by the user saying so: `/idea`, or "backlog it".

**One item or several.** Draft the whole criteria list first, then ask of
each entry: *could this go green and merge while the others are still red?*

| Answer | Shape |
|---|---|
| no entry could | one item, however long the list — one behaviour checked from several angles |
| one or more could | several items, one per slice, each with its own short list |

An item that could ship in halves costs a long-lived branch, one giant squash
and a review that must hold everything at once; two items that only
make sense together cannot each satisfy a criterion. One rule applied to N
files — every driver reports itself, every table moves under `src/` — is one
item with one criterion over the set, not N items proving one sentence each,
and not one item now and its twin twenty minutes later. The exception is a
mechanical change whose blast radius cannot land green on one branch: an
expand item (the new form beside the old), one migrate item per batch the
radius allows, and a contract item that deletes the old form — except a
vocabulary rename, which stays one commit
([glossary.md](references/glossary.md)). Backlog lines are raw
material: any number may fold into one item and one may split, and nothing
records which lines fed which.

## What is in flight

`workbench status` answers it: open items, items merged and still
`awaiting` a trigger, items merged and still `open` — a fault, see
"Unattended runs" — decisions waiting in items and in `DECISIONS.md`,
documents over their line cap, and any duplicate IDs. Run it rather than reconstructing the answer
from `git branch`, which cannot see the merged ones.

## Review sweeps

`/workbench-review <reason> ["scope"]` runs a sweep in a forked context —
a fresh one, with none of this conversation in it — and returns the report
path. Two reasons:

| Reason | When |
|---|---|
| `pre-merge <id>` | the gate: the item against its evidence and template, read in fresh context. The user asks for it; `workbench merge` does not require it. `review-check` counts its holds, and at three the merge is the user's call |
| `docs` | `workbench status` printed a `cap:` line — scoped to the file named; a document is past its line cap and the review says what to cut ([docs.md](references/docs.md), "Line caps") — or the user asks for an audit |

Never started because the code looks like it needs one.

The fork writes the report, and scratch under `workbench/scratch/` that git
never sees — nothing tracked. When it returns with the path, prove that before
reading the findings:

```bash
workbench review-check <report-path>
```

A failure names what went wrong; say so and do not triage until the user has
seen it. A pass proves the contract held, never that the work was done.

**Triage.** With the user when there is one. Without one, each finding gets
exactly one of: fixed inside the item before merge, when it is within the
item's criterion or is the same mechanism the item already changed — the
function's twin in the same file, the caller the fix broke — which
ts-lean-code's "fix the shared function once" already covers; `workbench
new bug` when it is outside both; a `BACKLOG.md`
line when it is an idea; or a one-line reason in the item's Evidence why it
stands. No finding is dropped silently, and a finding that says the criterion
is not met stops the merge. Then `workbench review-drop`.

## The review loop

Every item — the work is done, then:

```
review dialog                         a wb-reviewer spawned with the Agent tool, never forked
  findings → answered by number → each ends fixed / stands / withdrawn
  workbench round <id> <fixed> <stands>   again → a new reviewer · merge → workbench merge · call → park it
/workbench-review pre-merge <id>      only when the user asks for the gate: a fresh wb-gate fork
workbench review-check <report>       merge → review-drop, then merge; hold → fix on the branch, review-drop, review again
```

The dialog is where judgement is argued: the reviewer keeps its context
across the exchange, and a finding that stands gets one line under Evidence
saying why. A finding is shown, not read — the reviewer ran something on the
branch and the output is wrong — and one the worker cannot reproduce from
that demonstration is withdrawn; a bug nobody can show is nothing to fix,
here as at archive (`unreproduced`). Round two always runs; `round` decides
the rest by count and records `rounds:` on the item, which the gate reads
when it runs. The gate is not argued with: it checks the item against its
evidence and the template (`rules/pre-merge.md`), reads the code only for
vocabulary, tests and documentation, never sees the worker's context or the
last report, and holds only on what must change. Three holds and the work
stops: `workbench call <id>` with the standing finding, and the merge is the
user's.

## By class

| Class | Reference |
|---|---|
| feature, bug — fields, states, IDs, archiving, `find` | [items.md](references/items.md) |
| statuses, abandoning, what merge and archive ask | [statuses.md](references/statuses.md) |
| domain language, renaming a term, aliases | [glossary.md](references/glossary.md) |
| criteria, evidence, test kinds, RED/GREEN | [verification.md](references/verification.md) |
| review sweeps, reports, triage | [reviews.md](references/reviews.md) |
| what to document and where | [docs.md](references/docs.md) |
| branches, squash, trailers, worktrees, IDs | [git.md](references/git.md) |
| why the workflow is shaped this way, when a rule looks arbitrary | [rationale.md](references/rationale.md) |
