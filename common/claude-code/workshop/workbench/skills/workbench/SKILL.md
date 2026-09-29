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
work      the change
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
   on its field.
   `## Side effects` is part of the contract: agreed with it, and frozen
   with it at `start`; one found later is
   `workbench call <id> "side effect: …"`, never your edit.

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
   identifiers. A
   word it lacks, or one that could mean two things, goes to the user
   before the item is written in it; a new entry lands in the same commit
   as the item that first uses it. Its header says what an entry is.

5. **Deleting means deleting.** No "formerly", no "removed in favour of",
   no strikethrough, no inline changelog.

6. **An item has the template's sections and no others.** `archive`
   refuses any other heading. What was not proved is one line under
   Evidence. A question that is the user's is one line under the item's
   `## Decisions`, written by `workbench call`; the answer goes into the
   field it changes and the line is deleted. The fields hold what the
   reader needs to judge the claim — root cause, criterion, output — not
   the reasoning behind the code; that is in the code or the commit.

7. **Some decisions are the user's.** How an item is sized, the criterion,
   accepting a side effect, abandoning the work, a standing finding at the
   round cap, and the merge. Ask. A question you cannot get answered is
   `workbench call <id> "<the question, with options>"`, or `workbench call
   - "<question>"` when it belongs to no item, which parks it where
   `workbench status` lists it; a parked call stays parked — never resolve
   it by doing more work under a new item, never reverse it because later
   items made it look moot. A permission not on the allow-list is Claude
   Code's refusal rather than a decision: park it, never work around it.

8. **The project has no scratch folder.** A file that exists only for this
   session — a probe, a capture, a rendered page — goes to the scratchpad
   directory the environment names. What it showed is Evidence when it
   settles a criterion step; any other fact follows rule 4.

## Setting up

`workbench init` and `workbench adopt` end with a checklist headed
`setup — decide these with the user`. Take each line to the user before any
item is created; none is yours to settle. Two more: allow-list entries are
written only with the user's OK, and the glossary is seeded with the user's
words, never yours.

## Commands

`/bug`, `/feature`, `/spike`, `/idea` and `/wb` walk the steps. How each
field is written is the comment on it in the item's template. Skills,
agents and settings
are committed copies, in every worktree and clone. `workbench status` says
when a copy is behind its source; `workbench init` refreshes it; never edit
the copy.

## Starting work

```bash
workbench new bug "frozen coords"      # allocates id, writes the file, commits it on main
workbench start b-038                  # commits the criterion, then branch + worktree; refuses while the criterion or Side effects is empty
workbench merge b-038 "<subject>"      # the user's command, never yours: squash, trailer, cleanup
```

**Neither merge nor archive is yours to start.** Both land work the user
has not seen. When the review dialog ends and `round` says ready, report
the item with its last round and stop — say what the merge would be, its
subject the change rather than the item's title, and do not run it. The
same for `archive`. Asked for either in so many words, run it: what is
refused is taking the step yourself, not the command. Being told to work
the item is not being told to merge it.

IDs come from a counter shared by every worktree; never hand-pick one.
The file lands in the main checkout wherever `new` runs. Between `new` and
`start` the item is edited on main; after `start`, only in its worktree.

## Working an item

After `start`, in this session or in one the user opens for it with
`/wb <id>`. Work only inside the item's worktree.

1. `cd` into the worktree and install the project's dependencies the way
   its rules say. Read the item and run its criterion on the unchanged
   tree. One that does not fail there is not a criterion: settle the
   rewrite with the user. A bug whose steps you followed and whose failure
   you cannot make happen: report `unreproduced` with what you ran, and
   stop.
2. Do the work. Run everything you can; the user gets only what needs
   eyes — visual, subjective, in-world. Commit on the branch as you go;
   the item file commits with the code. Evidence is pasted output under
   `## Evidence`, one block per criterion step; a step the output does not
   meet is recorded as missed, with the number it reached, never reworded.
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
     and record our code's reaction; only the real event's shape waits,
     as `awaiting — <trigger>` when a time can be named, else
     `unverified — <trigger>` — the user picks.

   A finding that argues with the frozen criterion is `workbench call <id>
   "<what the criterion should say>"`; something that works today and now
   behaves differently which `## Side effects` does not name is `workbench
   call <id> "side effect: <what, for whom> — accept?"` — never an edit of
   the item. Before the review dialog, hold every function the diff
   changes against its callers for such a difference.
3. The review dialog, below.
4. Report, in three lines: the item id; `ready`, `blocked — <one question,
   with the options>` or `unreproduced — <what you ran>`; the last round's
   result, or `none`. Then stop.

A spike (`s-<n>`) answers questions instead of meeting a criterion. Step 1
runs nothing. Step 2 fills `## Findings`, one entry per question;
`## Questions` is the user's to edit, never yours; everything built goes
in the folder beside the item, and nothing goes on main — no `workbench
idea`, no glossary, backlog or document edit; each is a line under
`## Suggestions`. Step 3 is skipped. Step 4 reports `answered`, with
`status: answered` committed on the branch, or `blocked — <question>`.

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
per batch, and a contract item that deletes the old form — except a
vocabulary rename, which stays one commit. Backlog lines are raw material:
any number may fold into one item, one may split, and nothing records
which fed which.

**Renames and refactors.** A rename is a feature of its own: the glossary
entry and every occurrence change in one commit, the criterion the
occurrence count going to 0 — scoped to the paths holding the domain sense
when the word has another sense in this codebase. It is never absorbed into
the item that exposed it; wanting one is a backlog line until someone does
it, and a count that makes it real work sends it there. A refactor is not
its own item: one a bug or feature needs is inside that item; one standing
alone is a feature only with a measurement that means something to someone
who does not read code — p99 latency, build time, dependency count, not
"LOC −12%" — and that measurement is the criterion; without one it is a
backlog line.

## What is in flight

`workbench status`: open items, merged and still `awaiting`, merged and
still `open` (a fault), merged spikes kept as references, decisions
waiting in items and in `DECISIONS.md`, documents over their line cap,
duplicate IDs. `git branch` cannot see the merged ones.

## The review dialog

Every bug and feature item, once the work is done:

```
review dialog                         a wb-reviewer spawned with the Agent tool, never forked
  findings → answered by number → each ends fixed / stands / withdrawn
  workbench round <id> <fixed> <stands>   again → a new reviewer · ready → report it, the merge is the user's · call → park it
```

Spawn it naming the branch and the item file, and answer by number
through `SendMessage` to the id the spawn returned. After
@@REVIEW_EXCHANGE_CAP@@ exchanges on one finding without agreement, ask the
user. When every
finding has its state, `workbench round <id> <fixed> <stands>` and do what
it prints. A reviewer that returns partial, its turn cap reached, ends the
dialog: `workbench call <id> "<the standing finding>"`, never spawn it
again to finish.

The reviewer keeps its context across the exchange; a finding that stands
gets one line under Evidence saying why. A finding is shown, not read — the
reviewer ran something on the branch and the output is wrong — and one the
worker cannot reproduce from that demonstration is withdrawn, as at archive
(`unreproduced`). Round two always runs; `round` decides the rest by count,
records `rounds:` on the item, and at round @@REVIEW_ROUND_CAP@@ parks it: `workbench
call <id>` with the standing finding, and the item is reported blocked. A
finding outside the item's criterion and the mechanism it changed is
`workbench new bug`, or a `BACKLOG.md` line when it is an idea, never a fix
on this branch; a shared function is fixed once, not per caller. No finding
is dropped silently.
