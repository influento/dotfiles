# Documentation

The default is to write nothing. Code is the truth. Every document written is
something that can later contradict the code, and a document the agent trusts
while it is wrong is worse than no document.

## Decide in this order

1. **Write nothing.** If reading the code answers the question cheaply, that is
   the answer.
2. **Is it derivable from our own code?** If yes, do not write it — it will rot.
3. **Is it a discovered fact about a system we do not control?** Then it belongs
   in the item whose work discovered it — a bug's root cause, a feature's why,
   a research concept — not in a document of its own. The archive is already
   dated, searchable and locked, and the fact is attached to the change it
   explains.
4. **Only what is left** may be a document, and only if it passes the test
   below.

There is no category for knowledge that changes no decision. If a fact never
reaches an item and never reaches a backlog line, not writing it down is the
correct outcome.

## The multi-file test

If learning something requires reading **more than one file**, a document may
hold it. If one file tells you, read the file.

| Write it | Do not |
|---|---|
| a flow that crosses several files, in order | what one function does |
| contracts — what one part guarantees another | signatures, parameters |
| ordering constraints: this before that, or state is lost | "this file contains the parser" |
| why the design is this shape when a simpler one looks possible | anything a good name already says |

## Kinds and where they live

| Kind | Where | Invalidated by |
|---|---|---|
| Rules — how work is done here | root `CLAUDE.md` | process change |
| Intent — what the project is for | root `CLAUDE.md` | decisions |
| Wiring — how parts fit together | `CLAUDE.md` in the deepest directory it covers | relevant code change |

That is the whole set. The minimum a project needs is rules; the other two are
earned. Every kind has something that invalidates it, which is what makes the
`docs` review able to act on it.

`workbench/GLOSSARY.md` sits outside this table: it is domain language rather
than documentation, it is written by default rather than earned, and every item
is written against it. See [glossary.md](glossary.md).

Wiring lives in a nested `CLAUDE.md` because the harness loads it automatically
when a file in that directory is opened with the Read tool. Keep the
prescriptive and descriptive parts in separate sections, or the file grows into
a dumping ground.

**Caveat:** that automatic load happens on Read, not on `cat`, `head`, or
`grep`. When the task is to understand an area rather than edit it, open the
area's `CLAUDE.md` deliberately.

## No findings directory, no baselines file

A discovered fact goes in the item whose work found it. A measured number goes
in the item it was evidence for, with the command that produced it. Neither gets
a file of its own.

## Repository documents or agent memory

An agent with a persistent memory store must decide which of the two holds a
fact. One question settles it:

> **Could this fact become wrong because of a commit?**

| Answer | Home |
|---|---|
| Yes — it is tied to our code | a repository document, or the item itself |
| Yes — but it describes an external system | the item whose work discovered it |
| No — it is about the user, their machine, preferences, or workflow | agent memory |
| No — it is credentials-adjacent | nowhere in the repository — memory lives in the tree here, so `CLAUDE.local.md` or the user's own `~/.claude/` |

Technical facts about the project belong in the repository, not in memory.

Memory lives in the tree: `workbench init` points `autoMemoryDirectory` at
`.claude/memory/`, tracked, one store for every worktree — and for every clone
at the same path under `~`, since the setting is a path; `workbench status`
warns in a clone laid out differently, where `.claude/settings.local.json`
overrides it. That changes where memory is, not what goes in it. Every
session writes there through the main checkout, so its edits show up as
unstaged changes on the default branch; commit them as housekeeping.
`workbench merge` tolerates them unstaged and refuses them staged.

Auditing memory for facts that have drifted, or that should have been repository
documents, is a review reason — see [reviews.md](reviews.md).

## Deleting means deleting

SKILL.md rule 7. All of these are violations:

```
~~The old retry logic used a fixed 3s delay~~
NOTE: the staleness section was removed, see git history
Previously this used the frame; that approach was abandoned.
DEPRECATED: worldToScreen(v2) — kept for reference
## Changelog
  - 2026-08-24: removed the projection notes
```

Git stores every deleted line, retrievable with `git log -p <file>`. Restating
it inside the document duplicates git in the one place that costs context on
every read, and it accumulates until a file is mostly notes about its own past.

The single exception is something the reader must act on, such as where a moved
file went. That is a pointer, not a record of a deletion.

## Scope

A changed file affects only documents on its own path. Walk up from the file:
its directory, then each parent. Root holds rules and intent, which code changes
do not invalidate, so the walk almost never produces work — in practice it is
the one nested `CLAUDE.md` covering the area, or nothing.

## Documentation ships with the work

Any document written goes in the same change as the code. The pre-merge review
checks the decision in both directions: something written that should not have
been, and a discovered fact left out of the item that found it.
