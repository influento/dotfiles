---
name: workbench
description: Run project work as tracked items — every feature and bug fix gets a written item with a verification criterion agreed before code, evidence recorded after, and a git-native link between the item and the commits that implemented it. Use when implementing a feature, fixing a bug, running a code review sweep, deciding whether something needs documentation, or preparing work for merge.
---

# Workbench

Work is tracked as **items**. An item states what will change and how anyone
will know it worked, before the code exists. The reader of these items may not
read code at all — items and command output are the only channel they have.

## The loop

```
idea (workbench/BACKLOG.md line)
  -> item      workbench/items/{bugs,features,renames}/<id>-<slug>.md
  -> branch    <id>-<slug>, in its own worktree under .worktrees/
  -> work      root cause / implementation
  -> evidence  criterion filled in with real output
  -> merge     workbench merge: squash, commit trailer "Item: <id>"
  -> archive   workbench/items/archive/, records the commit SHA
```

## Hard rules

1. **Domain work is an item.** Features and bug fixes always get one, however
   small. Housekeeping that is not domain work — configs, agent settings,
   tooling — gets none and may go straight to the main branch.

2. **The criterion is written before the code, and it is the contract.**
   Evidence is matched against the criterion, never against a test. Run it
   before writing anything: **a criterion that passes on the unchanged tree is
   not a criterion.** Detail on
   [verification.md](references/verification.md).

3. **Nothing is archived without verified evidence.** Merging is a separate
   gate and asks only whether everything verifiable was verified, so an item may
   ship while still open. Two statuses archive a statement of what was *not*
   proved instead of pretending: `unreproduced`, and `unverified` for a criterion
   only a third party can settle. See [items.md](references/items.md).

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

## Starting work

```bash
workbench new bug "frozen coords"      # allocates id, writes the file
workbench new rename "shard to region" # same, for a vocabulary change
workbench start b-038                  # branch + worktree for it
workbench merge b-038 "<subject>"      # after the pre-merge review: squash, trailer, cleanup
```

IDs are allocated from a counter shared by every worktree, so any worktree may
create an item. Never hand-pick an ID.

`workbench status` answers what is in flight: open items, items merged and still
`awaiting` a trigger, and any duplicate IDs. Run it rather than reconstructing
the answer from `git branch`, which cannot see the merged ones.

## Review sweeps

`/workbench-review <reason> ["scope"]` runs the sweep in a forked context and
returns the report path. It is user-invoked only — never start one unasked.

The fork writes exactly one file, the report. When it returns with the path,
prove that before reading the findings:

```bash
workbench review-check <report-path>
```

A failure says which of three things went wrong: the sweep edited what it was
reviewing, a `path:line` it cites does not exist, or a file in scope is never
named. Say so and do not triage until the user has seen it. A pass means "wrote
only its report, its evidence points at real places, its scope is accounted
for" — never "did the work honestly": a sweep can name a file it never opened.
How the check works and where it stops are in
[rationale.md](references/rationale.md).

## By class

| Class | Reference |
|---|---|
| feature, bug, rename — fields, states, IDs, archiving | [items.md](references/items.md) |
| domain language, renaming a term, aliases | [glossary.md](references/glossary.md) |
| criteria, evidence, test kinds, RED/GREEN | [verification.md](references/verification.md) |
| review sweeps, reports, triage | [reviews.md](references/reviews.md) |
| what to document and where | [docs.md](references/docs.md) |
| branches, squash, trailers, worktrees, IDs | [git.md](references/git.md) |
| bringing an existing project in | [adopt.md](references/adopt.md) |
| why the workflow is shaped this way, when a rule looks arbitrary | [rationale.md](references/rationale.md) |
