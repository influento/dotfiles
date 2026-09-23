# Git

## Branches

One branch per item, named after it. `workbench start` creates the branch
off main and its worktree together, under
`.worktrees/<branch>` in the main checkout, wherever it is run from; there
is no branch-only path. A branch without a worktree — removed by hand, or
only fetched from another machine — is resumed by the same command, which
cuts the worktree and moves nothing.

A worktree holds tracked files and nothing else. Installing dependencies is
the worker's first step there, in whatever form the project's rules name;
`start` runs nothing in the new worktree, so an install that fails cannot
block starting an item.

## The item file is on main from the start

`workbench new` writes the file into the main checkout wherever it runs and
commits it there as `new <id>: <title>` — so the main checkout must have
main checked out, and `new` refuses otherwise before spending
an id. `workbench start` commits the filled-in criterion as `start <id>`
and cuts the branch from it, so the branch carries the item as agreed and
main shows every item from the moment it exists.

From `start` on the item is edited **on its branch only**: root cause,
evidence, status. Main's copy is never edited while the branch exists —
`merge` and `archive` compare it with the cut and refuse if it moved,
because the squash is a three-way merge and a main-side edit in a hunk the
branch never touched would merge in silently. At merge the branch's copy
replaces main's in the same commit as the code.

So main tells the story: an item file with no branch and no trailer is
open and not started; with a branch, started; with a trailer and no branch,
merged; under `archive/`, done. Every worktree inherits main's copies, so a
sibling's copy is not a second item.

An item written by hand, untracked, is landed by `start` the same way —
moved to the main checkout first if it was written in a worktree. One
committed on another item's branch is refused: it would reach the default
branch twice.

## Merging

```bash
workbench merge f-037 "resolve position from the client rather than the frame"
```

Squashes the branch onto main as one commit, removes the
worktree, deletes the branch. The message is the subject and the trailer:

```
resolve position from the client rather than the frame

Item: f-037
```

The subject describes the change, not the item's title.

A spike merges only as `answered`, and only its item and its folder,
`workbench/items/spikes/<id>-<slug>/`: a change anywhere else is refused.
It runs no `premerge`: the gate leaves `workbench/` out, so it would test
nothing the spike changed.

When `premerge=` is set in the main checkout's `.claude/workshop.conf` — a
test run, a lint gate — the command runs it in the branch's worktree after
every other check and before the squash, and refuses the merge on a
non-zero exit with the command's output as the reason. Only removing the
key skips it. A branch whose worktree is gone is refused rather than merged
unchecked; `workbench start <id>` recreates one. The file is committed, so
every clone and worktree has the same gate.

The command refuses before touching anything, naming the reason. An
unstaged edit on main stays out of the squash and is tolerated. It does not
push.

It reads the item file **from the branch** ([items.md](items.md), "What each
gate asks").

Needs git 2.38 or later (`merge-tree --write-tree`) and GNU coreutils,
findutils and sed (`date -r`, `find -printf`, `chmod --reference`, `sed
-i`): Linux, or macOS with the GNU tools first on `PATH`.

## Traceability

The trailer and the recorded commit SHA do the work.

```bash
git log --grep="Item: f-037"    # item -> the commits that implemented it
git log -p -- path/to/file      # file -> commits -> item IDs -> why it is like this
git log --grep='^Item: ' -- path/to/file   # what came before on a path, newest first
```

## Archiving

Move the item to `workbench/items/archive/` and record the commit SHA in
it. **What triggers it is the criterion being satisfied, not the merge.**
`archive` resolves the SHA from the trailer on main.

The command refuses while the item's branch still exists — archived first,
the item would record `commit: none` for good. Some branches never merge,
and `archive` retires those itself: the branch's copy of the item replaces
main's, the worktree and branch go, and a tag named by the id is left at
the tip so its commits stay reachable. An `unreproduced` bug's branch holds
nothing but the item file; anything else on it is work, which merges or is
discarded by hand. An `abandoned` item's branch holds whatever was built;
`archive --discard` drops that, naming each file, and without the flag the
command refuses. An unmerged spike's branch, `answered` or `abandoned`, is
retired with everything committed on it, which stays under the tag:
`git worktree add <dir> <id>` reads it. Uncommitted work beyond the item
file is refused; commit it first. `--discard` on an abandoned spike drops
only those uncommitted changes: what is committed stays under the tag.

A merged spike has no branch left. Its archive commit moves the item and
deletes its folder, the files git tracks there and nothing else; `git show
<archive commit>^:<folder>/` reads the last version. It refuses while the
folder holds uncommitted or untracked files, or while a tracked file
outside `workbench/`, on main or on any local branch, names the folder.
With `premerge` set, work whose branch was cut before the archive must be
rebased before it merges.

The move is committed on main as `archive <id>`.

## IDs

Format `<letter>-<number>-<slug>`, e.g. `f-037-mob-positions`,
`b-038-frozen-coords`. The letter is `f` for feature, `b` for bug, `s` for
spike, kept because `workbench/items/archive/` is flat. The ID seeds the file name, the
branch and the trailer:

```
workbench/items/features/f-037-mob-positions.md
branch:  f-037-mob-positions
commit:  "resolve position from the client\n\nItem: f-037"
```

One sequence for every worktree and every class — `b-001` is followed by
`f-002`, so a number names one item whatever its letter. The counter in the
shared git directory is a cache, rebuilt from the highest ID in the tree,
`archive/` included, so numbers are never reused.

## Duplicate IDs across machines

One window remains: two machines allocate before either pushes. The slugs differ, so the filenames differ and **git merges them
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
