---
name: workbench
description: Run project work as tracked items — every feature and bug fix gets a written item with a verification criterion agreed before code, evidence recorded after, and a git-native link between the item and the commits that implemented it. Use when implementing a feature, fixing a bug, deciding whether work is one item or several, running the review dialog, deciding whether something needs documentation, or preparing work for merge.
---

# Workbench

Work is tracked as **items**: what will change and how anyone will know it
worked, written before the code exists. The reader may not read code at all
— items and command output are their only channel.

**Main** is the default branch: `main=` in `.claude/workshop.conf`, then
`origin/HEAD`, then `main` or `master`. The commands resolve the real name.

## The loop

```
idea (workbench/BACKLOG.md line)
  -> item      workbench/items/{bugs,features,spikes}/<id>-<slug>.md,
               committed on main as it is created
  -> branch    <id>-<slug>, in its own worktree under .worktrees/; the item
               is edited there from now on
  -> work      root cause / implementation
  -> evidence  criterion filled in with real output
  -> merge     workbench merge: squash, commit trailer "Item: <id>"
  -> archive   workbench/items/archive/, records the commit SHA
```

## Hard rules

1. **Domain work is an item.** Every feature and bug fix, however small,
   once someone opens it; until then `/idea` is the user's deferral
   ("Sizing"). Housekeeping — configs, agent settings, tooling — gets none
   and may go straight to main.

2. **The criterion is written before the code, and it is the contract.**
   Evidence is matched against it, never against a test. A criterion that
   passes on the unchanged tree is not a criterion: run it first. The field
   holds commands and expected results only — no rationale, no guard
   ("still does what it did"), no typecheck or build, no "by inspection". A
   criterion the evidence cannot meet is recorded as **missed**, never
   reworded ([verification.md](references/verification.md)).
   `## Side effects` is agreed with it: every route, export, output or
   stored format that behaves differently once the item lands, and who sees
   it, or `none`. `start` refuses it empty. One found after `start` is
   `workbench call <id> "side effect: …"`, never your edit of the
   section: whether the change is acceptable is the user's, and so is the
   edit. A spike has neither: its `## Questions` stand in their place
   ([verification.md](references/verification.md), "Spikes").

3. **Nothing is archived without verified evidence.** Merge asks only
   whether everything verifiable was verified, so an item may ship while
   still open. `unreproduced` and `unverified — <trigger>` archive a
   statement of what was not proved; `abandoned — <why>` archives a
   decision: work the user dropped, never deleted
   ([items.md](references/items.md)). A spike archives as `answered`: its
   Findings are the record.

4. **State the root cause before writing a fix.**

5. **A test may satisfy only what the criterion describes.** No script
   whose only purpose is to satisfy a criterion; no test of config, wiring
   or glue unless a criterion demanded it. A spike has no criterion: what it
   builds, a test included, stays in its folder, which no gate runs; its
   output is Findings, not assertions.

6. **Do not write documentation by default.** Write only what cannot be
   read from the code. A discovered fact becomes code or a comment at its
   call site, never a document and never an item line of its own
   ([docs.md](references/docs.md)). The standing exception is
   `workbench/GLOSSARY.md`, the project's domain language, which binds
   every item ([glossary.md](references/glossary.md)). The other is a
   spike's `## Findings`: what a spike discovers is its output.

7. **Deleting means deleting.** No "formerly", no "removed in favour of",
   no strikethrough, no inline changelog. The one exception is a pointer the
   reader must act on, such as where a moved file went.

8. **An item has the template's sections and no others.** `archive`
   refuses any other heading. What was not proved is one line under
   Evidence — a spike's, under Findings. A question that is the user's is one line under the item's
   `## Decisions`, written by `workbench call`; the answer goes into the
   field it changes and the line is deleted. The fields hold what the
   reader needs to judge the claim — root cause, criterion, output — not
   the reasoning behind the code; that is in the code or the commit.

9. **Some decisions are the user's.** How an item is sized, the criterion,
   accepting a side effect, abandoning the work, a standing finding at the
   round cap, and the merge. Ask. A question you cannot get answered is
   `workbench call <id> "<the question, with options>"`, or `workbench call
   - "<question>"` when it belongs to no item, which parks it where
   `workbench status` lists it; a parked call stays parked — never resolve
   it by doing more work under a new item, never reverse it because later
   items made it look moot. A permission not on the allow-list is Claude
   Code's refusal rather than a decision: park it, never work around it.

10. **The project has no scratch folder.** A file that exists only for this
    session — a probe, a capture, a rendered page — goes to the scratchpad
    directory the environment names. What it showed is Evidence when it
    settles a criterion step; any other fact follows rule 6. A spike's
    prototypes and captures are its output, not scratch: they go in its
    folder.

## Setting up

`workbench init` and `workbench adopt` end with a checklist headed
`setup — decide these with the user`. Take each line to the user before any
item is created; none is yours to settle. Two more: allow-list entries are
written only with the user's OK, and the glossary is seeded with the user's
words, never yours.

## Commands

`/bug`, `/feature`, `/spike`, `/idea` and `/wb` are thin — the sizing
check, the command, the fields — so the rules stay here. Skills, agents and settings
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
the item with its last round and stop — say what the merge would be, do
not run it. The same for `archive`. Asked for either in so many words, run
it: what is refused is taking the step yourself, not the command. Being
told to work the item is not being told to merge it.

IDs come from a counter shared by every worktree; never hand-pick one.
The file lands in the main checkout wherever `new` runs. Between `new` and
`start` the item is edited on main; after `start`, only in its worktree.

## Sizing — the same call every time

One question: **how well can it be described right now?** Name the row; the
user confirms. Not the size of the work, not tidiness.

| It can be described as | It is | Lives as |
|---|---|---|
| what changes and how to confirm it | an item | `workbench new bug\|feature` |
| an area — cannot yet say what will be true when it is done, or how it fits, or both | a spike | `workbench new spike`: the questions in scope, each answered under Findings or given a blocker — "could not determine" is a result; its code in its own folder beside the item, self-contained. Merged, it stays on main as a reference for later features until archive removes the folder; unmerged, archive retires its branch under a tag. Which spikes merge is the user's call |
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
vocabulary rename, which stays one commit
([glossary.md](references/glossary.md)). Backlog lines are raw material:
any number may fold into one item, one may split, and nothing records
which fed which.

## What is in flight

`workbench status`: open items, merged and still `awaiting`, merged and
still `open` (a fault), merged spikes kept as references, decisions
waiting in items and in `DECISIONS.md`, documents over their line cap,
duplicate IDs. `git branch` cannot see the merged ones.

## The review dialog

Every bug and feature item — the work is done, then (a spike has none; the
user reads its Findings):

```
review dialog                         a wb-reviewer spawned with the Agent tool, never forked
  findings → answered by number → each ends fixed / stands / withdrawn
  workbench round <id> <fixed> <stands>   again → a new reviewer · ready → report it, the merge is the user's · call → park it
```

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

## By class

| Class | Reference |
|---|---|
| feature, bug, spike — fields, states, statuses, archiving, what merge and archive ask | [items.md](references/items.md) |
| spike — why the criterion rules do not apply, when it is done | [verification.md](references/verification.md), "Spikes" |
| domain language, renaming a term, aliases | [glossary.md](references/glossary.md) |
| criteria, evidence, test kinds, RED/GREEN | [verification.md](references/verification.md) |
| what to document and where | [docs.md](references/docs.md) |
| branches, squash, trailers, worktrees, IDs | [git.md](references/git.md) |
