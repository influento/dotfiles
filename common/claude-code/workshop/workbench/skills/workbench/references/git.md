# Git

## Branches

One branch per item, named after it. `workbench start` creates the branch
off the default branch and its worktree together, under
`.worktrees/<branch>` in the main checkout, wherever it is run from; there
is no branch-only path. A branch without a worktree — removed by hand, or
only fetched from another machine — is resumed by the same command, which
cuts the worktree and moves nothing.

A worktree holds tracked files and nothing else. Installing dependencies is
the worker's first step there, in whatever form the project's rules name;
`start` runs nothing in the new worktree, so an install that fails cannot
block starting an item.

## The item file is on the default branch from the start

`workbench new` writes the file into the main checkout wherever it runs and
commits it there as `new <id>: <title>` — so the main checkout must have
the default branch checked out, and `new` refuses otherwise before spending
an id. `workbench start` commits the filled-in criterion as `start <id>`
and cuts the branch from it, so the branch carries the item as agreed and
the default branch shows every item from the moment it exists.

From `start` on the item is edited **on its branch only**: root cause,
evidence, status. Main's copy is never edited while the branch exists —
`merge` and `archive` compare it with the cut and refuse if it moved,
because the squash is a three-way merge and a main-side edit in a hunk the
branch never touched would merge in silently. At merge the branch's copy
replaces main's in the same commit as the code.

So the default branch tells the story: an item file with no branch and no
trailer is open and not started; with a branch, started; with a trailer and
no branch, merged; under `archive/`, done. Every worktree inherits main's
copies, so a sibling's copy is not a second item. The one thing the default
branch cannot show is an item merged as `awaiting` — no branch left — so
in-flight is branches **plus** that status, and `workbench status` reports
both.

An item written by hand, untracked, is landed by `start` the same way —
moved to the main checkout first if it was written in a worktree. One
committed on another item's branch is refused: it would reach the default
branch twice.

## Merging

```bash
workbench merge f-037 "resolve position from the client rather than the frame"
```

Squashes the branch onto the default branch as one commit, removes the
worktree, deletes the branch. The message is the subject and the trailer:

```
resolve position from the client rather than the frame

Item: f-037
```

**Nothing else goes in the message.** A body would be a second source of
truth beside the item. The subject describes the change, not the item's
title.

When `git config workbench.premerge` is set — a test run, a lint gate —
the command runs it in the branch's worktree after every other check and
before the squash, and refuses the merge on a non-zero exit with the
command's output as the reason. Only unsetting the config skips it. A
branch whose worktree is gone is refused rather than merged unchecked;
`workbench start <id>` recreates one. Like every `workbench.*` key it is
git config, per clone: a fresh clone sets it again or merges unchecked —
`init`'s checklist shows which.

The command refuses, before touching anything, when the main checkout is
not on the default branch, has staged changes or an uncommitted deletion
(an unstaged edit stays out of the squash and is tolerated), the worktree
has uncommitted changes or is locked, the branch conflicts with the default
branch (rebase it in the worktree first), or the default branch already
carries the trailer. It does not push.

It reads the item file **from the branch**, and refuses when that copy is
missing, has an unclosed fence, carries a status that is not one, says
`awaiting` or `unverified` without a trigger, or is `open` with no fenced
block under `## Evidence` — structural questions, not whether the evidence
shows what it claims, which is the reviewer's ([items.md](items.md), "What
each gate asks").

Needs git 2.38 or later (`merge-tree --write-tree`) and GNU coreutils,
findutils and sed (`date -r`, `find -printf`, `chmod --reference`, `sed
-i`): Linux, or macOS with the GNU tools first on `PATH`.

A worktree deleted by hand stays in `git worktree list` until `git worktree
prune`; `merge` and `archive` say so and stop until it is run. Lookups skip
it meanwhile.

Every item merges this way. Housekeeping goes straight to the main branch
(SKILL.md, "Domain work is an item").

## Traceability

The trailer and the recorded commit SHA do the work; no pull request is
involved, so adopting a hosting service later changes nothing.

```bash
git log --grep="Item: f-037"    # item -> the commits that implemented it
git log -p -- path/to/file      # file -> commits -> item IDs -> why it is like this
git log --grep='^Item: ' -- path/to/file   # what came before on a path, newest first
```

## Archiving

Move the item to `workbench/items/archive/` and record the commit SHA in
it. **What triggers it is the criterion being satisfied, not the merge.**
The SHA is resolved from the trailer, on the default branch:

```bash
git log main --grep="^Item: b-038$" --format=%h -1
```

Not `HEAD`, and not `--all`, which can hit a branch commit the squash then
discards. The default branch is `git config workbench.main`, then
`origin/HEAD`, then `main` or `master`.

The command refuses while the item's branch still exists — archived first,
the item would record `commit: none` for good. Two branches never merge,
and `archive` retires those itself: the branch's copy of the item replaces
main's, the worktree and branch go, and a tag named by the id is left at
the tip so its commits stay reachable. An `unreproduced` bug's branch holds
nothing but the item file; anything else on it is work, which merges or is
discarded by hand. An `abandoned` item's branch holds whatever was built;
`archive --discard` drops that, naming each file, and without the flag the
command refuses.

The move is committed on the default branch as `archive <id>`.

## IDs

Format `<letter>-<number>-<slug>`, e.g. `f-037-mob-positions`,
`b-038-frozen-coords`. The letter is `f` for feature, `b` for bug, kept
because `workbench/items/archive/` is flat. The ID seeds the file name, the
branch and the trailer:

```
workbench/items/features/f-037-mob-positions.md
branch:  f-037-mob-positions
commit:  "resolve position from the client\n\nItem: f-037"
```

The number comes from a counter in the shared git directory,
`.git/item-seq`: one sequence for every worktree and every class — `b-001`
is followed by `f-002`, so a number names one item whatever its letter —
with an atomic lock directory guarding increments. Missing, it is rebuilt
from the highest ID in the repository, `archive/` included, so numbers are
never reused. A hand-picked number does not advance the counter and the
next allocation collides with it. Because the counter lives in the shared
git directory, a worktree whose branch predates adoption can still
allocate.

## Duplicate IDs across machines

The counter is a cache; allocation takes whichever is higher, the counter
or the highest ID in the tree, so a stale counter after a pull cannot hand
out a used number. One window remains: two machines allocate before either
pushes. The slugs differ, so the filenames differ and **git merges them
silently**. `workbench status` detects it by ID prefix.

| Situation | What to do |
|---|---|
| neither is merged | renumber the one allocated later — rename the file, rename its branch |
| one is merged | the merged one keeps the ID; renumber the other |
| both are merged | renumber the file only; do not rewrite history |

The last row loses nothing: **the SHA is the authoritative link and the
trailer only an index**. `git log --grep="Item: b-046"` returns two commits
after such a repair; the recorded SHA in each item says which is which, and
nothing is written into either file about the renumbering.

Prevention is one habit: pull before allocating.
