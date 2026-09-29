---
name: workbench
description: Track work as items: a verification criterion agreed before code, evidence after, and links to the implementing commits. Use when implementing a feature, fixing a bug, sizing work into items, running the review dialog, deciding whether something needs documentation, or preparing a merge.
---

# Workbench

## The loop

```
idea      optional: a workbench/BACKLOG.md line
item      workbench new: the file, committed on main; its criterion agreed with the user
start     workbench start: the criterion committed, branch <id>-<slug> in .worktrees/;
          the item is edited only there from now on
work      the change, in the session the user opens in the worktree
evidence  the criterion filled in with real output
review    bug and feature: wb-reviewer dialog, workbench round until ready; report, stop
merge     the user's: squash onto main, trailer "Item: <id>"
archive   the user's: to workbench/items/archive/, records the SHA
```

## Hard rules

1. **The criterion is the contract, agreed before the code.** It holds
   commands and expected results only — no guard (a typecheck, a build,
   "still does what it did"), no "by inspection" — and fails on the
   unchanged tree: run it first. Evidence is matched against it, never
   against a test; evidence that falls short is recorded as **missed**,
   never reworded. How a criterion is written is the template's comment
   on its field. `## Side effects` is part of the contract: agreed with
   it, and frozen with it at `start`; one found later is `workbench call
   <id> "side effect: …"`, never your edit.

2. **What was not proved is a status, never a gap.** A criterion waiting
   on an event you cannot cause now: verify the rest, then the user picks
   `awaiting — <trigger>` (a time can be named) or `unverified — <trigger>`.
   A bug you cannot reproduce is `unreproduced`; work the user drops is
   `abandoned — <why>`, archived, never deleted.

3. **A test may satisfy only what the criterion describes.** No script
   whose only purpose is to satisfy a criterion; no test of config, wiring
   or glue unless a criterion demanded it.

4. **Do not write documentation by default.** Write only what cannot be
   read from the code. A discovered fact becomes code or a comment at its
   call site, never a document and never an item line of its own; what
   may be written, and where, is `.claude/rules/workbench.md`,
   "Documentation". The exception is `workbench/GLOSSARY.md`, the
   project's domain language, which binds items, commit subjects and code
   identifiers. A word it lacks, or one that could mean two things, goes
   to the user before the item is written in it; a new entry lands in the
   same commit as the item that first uses it. Its header says what an
   entry is.

5. **Deleting means deleting.** No "formerly", no "removed in favour of",
   no strikethrough, no inline changelog.

6. **An item has the template's sections and no others.** What was not
   proved is one line under Evidence. The fields hold what the reader
   needs to judge the claim — root cause, criterion, output — not the
   reasoning behind the code; that is in the code or the commit.

7. **Some decisions are the user's.** How an item is sized, the criterion,
   accepting a side effect, abandoning the work, a standing finding at the
   round cap, and the merge. Ask. A question you cannot get answered is
   `workbench call <id> "<the question, with options>"`, or
   `workbench call - "<question>"` when it belongs to no item; a parked
   call stays parked — never resolve it by doing more work under a new
   item, never reverse it because later items made it look moot. A
   permission not on the allow-list is Claude Code's refusal rather than a
   decision: park it, never work around it.

8. **The project has no scratch folder.** A file that exists only for this
   session — a probe, a capture, a rendered page — goes to the scratchpad
   directory the environment names. What it showed is Evidence when it
   settles a criterion step.

## Setting up

`workbench init` and `workbench adopt` end with a checklist headed
`setup — decide these with the user`. Take each line to the user before any
item is created; none is yours to settle. Allow-list entries are written
only with the user's OK.

## Commands

`/bug`, `/feature`, `/spike`, `/idea` and `/wb` walk the steps. Skills,
agents, rules and settings are committed copies, in every worktree and
clone, rendered by `workbench init`: never edit one. IDs come from a
counter shared by every worktree; never hand-pick one.

## Merge and archive

**Neither merge nor archive is yours to start.** Both land work the user
has not seen. With the report (Working an item, step 4), say what the merge
would be — `workbench merge <id> "<subject>"`, its subject the change
rather than the item's title — and do not run it. The same for `archive`.
Asked for either in so many words, run it: what is refused is taking the
step yourself, not the command. Being told to work the item is not being
told to merge it.

## Working an item

Work only inside the item's worktree. A spike runs no criterion and has no
review dialog: its template's comments are its steps.

1. Install the project's dependencies the way its rules say, and run the
   criterion on the unchanged tree, and paste that run under Evidence as
   each step's RED block; GREEN follows after the change. One that does
   not fail there is not a criterion: settle the rewrite with the user. A
   bug whose steps you followed and whose failure you cannot make happen:
   report `unreproduced` with what you ran, and stop.
2. Do the work. Run everything you can; the user gets only what needs
   eyes — visual, subjective, in-world. Commit on the branch as you go;
   the item file commits with the code.
   - A number: base and branch run alternately in one session, the base
     from a scratch worktree — sessions in other worktrees share the
     machine, so a figure from another session is no baseline. What the
     number costs elsewhere, memory for time, is a side effect.
   - A flake is GREEN at `0 of M` with M ≥ 3·N/k; fewer, and an unchanged
     tree passes by luck. An exploit is GREEN when it and two or more
     variants of its input class fail.
   - A test you write and can re-run cheaply: its kind follows the
     criterion. Record RED — the command, the failing output, why that
     failure was the expected one — and GREEN; one only ever seen green
     proves nothing. Never name it in the item: the commit trailer reaches
     it.
   - A step that turns on an event you cannot cause: synthesise the event
     and record our code's reaction; the rest waits as a status (rule 2).

   A finding that argues with the frozen criterion is `workbench call <id>
   "<what the criterion should say>"`, never an edit of the item. Before
   the review dialog, hold every function the diff changes against its
   callers for a difference `## Side effects` does not name (rule 1).
3. The review dialog, below.
4. Unless the report is `blocked`, delete every template comment still in
   the item, the Decisions one too when nothing is parked under it; the
   session that resumes a blocked item needs them. Then report to the
   user: `ready` with the last round, `blocked — <one question, with the
   options>`, or `unreproduced — <what you ran>`. Then stop.

## Sizing — the same call every time

One question: **how well can it be described right now?** Name the row; the
user confirms. Not the size of the work, not tidiness.

| It can be described as | It is | Lives as |
|---|---|---|
| what changes and how to confirm it | an item | `workbench new bug\|feature` |
| an area — cannot yet say what will be true when it is done, or how it fits, or both | a spike | `workbench new spike`: questions instead of a criterion, findings as the result |
| one sentence, obvious what it means, and nobody is opening it now | an idea | a `BACKLOG.md` line, `workbench idea` |

Whatever fits the item row is an item. The idea row is never the agent's
proposal for something item-shaped — "crash on save" is a bug; it is the
user's deferral, reached only by `/idea` or "backlog it".

Slow is a bug when it breaks an expectation that exists: slower than a
known commit, over a stated budget, or failing because of it. Faster than
today with no such line is a feature, its criterion the number.

**One item or several.** Draft the whole criteria list, then ask of each
entry: *could this go green and merge while the others are still red?*

| Answer | Shape |
|---|---|
| no entry could | one item, however long the list — one behaviour checked from several angles |
| one or more could | several items, one per slice, each with its own short list |

One rule applied to N files — every driver reports itself — is one item
with one criterion over the set, not N items and not one item now and its
twin later. The exception is a mechanical change that cannot land green on
one branch: an expand item (the new form beside the old), one migrate item
per batch, and a contract item that deletes the old form. Backlog lines are
raw material: any number may fold into one item, one may split, and
nothing records which fed which.

**Renames and refactors.** A rename is a feature of its own: the glossary
entry and every occurrence change in one commit, the criterion the
occurrence count going to 0 — scoped to the paths holding the domain sense
when the word has another sense in this codebase. It is never absorbed into
the item that exposed it: that item keeps the old word, and the rename goes
to the user, as its own feature or a backlog line. A refactor a bug or
feature needs is inside that item. One standing alone is a feature only
with a measurement that means something to someone who does not read code
— p99 latency, build time, dependency count, not "LOC −12%" — and that
measurement is the criterion; without one it is a backlog line.

## What is in flight

`workbench status`. `git branch` cannot see the merged items still open or
awaiting.

## The review dialog

Every bug and feature item, once the work is done. Spawn a `wb-reviewer`
with the Agent tool, never forked, naming the branch and the item file, and
answer its findings by number through `SendMessage` to the id the spawn
returned; each ends fixed, stands or withdrawn. After
@@REVIEW_EXCHANGE_CAP@@ exchanges on one finding without agreement, ask the
user. When every finding has its state, `workbench round <id> <fixed>
<stands>` and do what it prints. A reviewer that returns partial, its turn
cap reached, ends the dialog: `workbench call <id> "<the standing
finding>"`, never spawn it again to finish.

Rerun each finding's demonstration; one you cannot reproduce is withdrawn.
A finding that stands gets one line under Evidence saying why. A finding
outside the item's criterion and the mechanism it changed is `workbench new
bug`, or a `BACKLOG.md` line when it is an idea, never a fix on this
branch; a shared function is fixed once, not per caller. No finding is
dropped silently.
