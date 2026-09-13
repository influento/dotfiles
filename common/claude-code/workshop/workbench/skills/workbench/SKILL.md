---
name: workbench
description: Run project work as tracked items — every feature and bug fix gets a written item with a verification criterion agreed before code, evidence recorded after, and a git-native link between the item and the commits that implemented it. Use when implementing a feature, fixing a bug, deciding whether work is one item or several, running the review dialog, deciding whether something needs documentation, or preparing work for merge.
---

# Workbench

Work is tracked as **items**: what will change and how anyone will know it
worked, written before the code exists. The reader may not read code at all
— items and command output are their only channel.

**Main** is the default branch: `git config workbench.main`, then
`origin/HEAD`, then `main` or `master`. The commands resolve the real name.

## The loop

```
idea (workbench/BACKLOG.md line)
  -> item      workbench/items/{bugs,features}/<id>-<slug>.md,
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
   edit.

3. **Nothing is archived without verified evidence.** Merge asks only
   whether everything verifiable was verified, so an item may ship while
   still open. `unreproduced` and `unverified — <trigger>` archive a
   statement of what was not proved; `abandoned — <why>` archives a
   decision: work the user dropped, never deleted
   ([items.md](references/items.md)).

4. **State the root cause before writing a fix.**

5. **A test may satisfy only what the criterion describes.** No script
   whose only purpose is to satisfy a criterion; no test of config, wiring
   or glue unless a criterion demanded it.

6. **Do not write documentation by default.** Write only what cannot be
   read from the code. A discovered fact becomes code or a comment at its
   call site, never a document and never an item line of its own
   ([docs.md](references/docs.md)). The standing exception is
   `workbench/GLOSSARY.md`, the project's domain language, which binds
   every item ([glossary.md](references/glossary.md)).

7. **Deleting means deleting.** No "formerly", no "removed in favour of",
   no strikethrough, no inline changelog. The one exception is a pointer the
   reader must act on, such as where a moved file went.

8. **An item has the template's sections and no others.** `archive`
   refuses any other heading. What was not proved is one line under
   Evidence. A question that is the user's is one line under the item's
   `## Decisions`, written by `workbench call`; the answer goes into the
   field it changes and the line is deleted. The fields hold what the
   reader needs to judge the claim — root cause, criterion, output — not
   the reasoning behind the code; that is in the code or the commit.

9. **Some decisions are the user's, and an absent user does not transfer
   them.** "Unattended runs" says what to do at each.

10. **The project has no scratch folder.** A file that exists only for this
    session — a probe, a capture, a rendered page — goes to the scratchpad
    directory the environment names. What it showed is Evidence when it
    settles a criterion step; any other fact follows rule 6.

## Setting up

`workbench init` and `workbench adopt` end with a checklist headed
`setup — decide these with the user`. Take each line to the user before any
item is created; none is yours to settle. Two more: allow-list entries are
written only with the user's OK, and the glossary is seeded with the user's
words, never yours.

## Unattended runs

The loop does not change; what changes is what happens at a decision that
is the user's:

| Decision | Unattended, do this |
|---|---|
| sizing needs confirming | take the item row when it fits; anything else, `workbench call - "<question>"` and move to work that is describable |
| criterion agreed | run it RED, write it, `workbench call <id> "criterion: …"` in one line, and proceed |
| merged, criterion cannot run yet | set `status: awaiting — <trigger> (agent)` or `unverified — <trigger> (agent)` and `workbench call <id>` naming the trigger. Never leave a merged item `open`; `status` lists that as a fault |
| a parked call would unblock work | it stays parked. Do other work; never resolve it by doing more work under a new item, never reverse it because later items made it look moot |
| the work looks not worth finishing | `workbench call <id> "abandon? …"` and move on. Never enter `abandoned` yourself, never delete the item |
| a question only the user can answer | `workbench call <id> "<the question, with options>"`, then move to work that is describable |
| a permission not on the allow-list | Claude Code refuses it and the refusal is what you see; park it with `workbench call`, never work around it |

`(agent)` marks every provisional decision, in the file that holds it, and
`workbench status` lists each with its open `## Decisions` line. The user
confirms by deleting the marker, or overrules by editing the item. A
question tied to no item (`workbench call -`) goes to
`workbench/DECISIONS.md`. Nothing else records that a decision was
provisional — not the backlog, not memory.

## Commands

`/bug`, `/feature`, `/idea` and `/wb` are thin — the sizing check, the
command, the fields — so the rules stay here. Skills, agents and settings
are committed copies, in every worktree and clone. `workbench status` says
when a copy is behind its source; `workbench init` refreshes it; never edit
the copy.

## Starting work

```bash
workbench new bug "frozen coords"      # allocates id, writes the file, commits it on main
workbench start b-038                  # commits the criterion, then branch + worktree; refuses while the criterion or Side effects is empty
workbench merge b-038 "<subject>"      # after the review dialog: squash, trailer, cleanup
```

IDs come from a counter shared by every worktree; never hand-pick one.
The file lands in the main checkout wherever `new` runs. Between `new` and
`start` the item is edited on main; after `start`, only in its worktree.

## Sizing — the same call every time

One question: **how well can it be described right now?** Name the row; the
user confirms. Not the size of the work, not tidiness.

| It can be described as | It is | Lives as |
|---|---|---|
| what changes and how to confirm it | an item | `workbench new bug\|feature` |
| an area — cannot yet say what will be true when it is done, or how it fits, or both | a spike | a feature item whose criterion is the question it answers and whose evidence is the answer; what it decides becomes items or `BACKLOG.md` lines, and the spike's branch merges only what is describable by then |
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
still `open` (a fault — "Unattended runs"), decisions waiting in items and
in `DECISIONS.md`, documents over their line cap, duplicate IDs. `git
branch` cannot see the merged ones.

## The review dialog

Every item — the work is done, then:

```
review dialog                         a wb-reviewer spawned with the Agent tool, never forked
  findings → answered by number → each ends fixed / stands / withdrawn
  workbench round <id> <fixed> <stands>   again → a new reviewer · merge → workbench merge · call → park it
```

The reviewer keeps its context across the exchange; a finding that stands
gets one line under Evidence saying why. A finding is shown, not read — the
reviewer ran something on the branch and the output is wrong — and one the
worker cannot reproduce from that demonstration is withdrawn, as at archive
(`unreproduced`). Round two always runs; `round` decides the rest by count,
records `rounds:` on the item, and at the fifth round parks it: `workbench
call <id>` with the standing finding, and the merge is the user's. A
finding outside the item's criterion and the mechanism it changed is
`workbench new bug`, or a `BACKLOG.md` line when it is an idea, never a fix
on this branch; a shared function is fixed once, not per caller. No finding
is dropped silently.

## By class

| Class | Reference |
|---|---|
| feature, bug — fields, states, statuses, archiving, what merge and archive ask | [items.md](references/items.md) |
| domain language, renaming a term, aliases | [glossary.md](references/glossary.md) |
| criteria, evidence, test kinds, RED/GREEN | [verification.md](references/verification.md) |
| what to document and where | [docs.md](references/docs.md) |
| branches, squash, trailers, worktrees, IDs | [git.md](references/git.md) |
