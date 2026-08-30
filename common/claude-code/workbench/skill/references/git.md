# Git

## Branches

One branch per item, named after it. `workbench start` creates the branch off
the default branch and its worktree together, under `.worktrees/<branch>` in
the main checkout — wherever it is run from. There is no branch-only path.
A branch that exists without a worktree — removed by hand, or only fetched
from another machine — is resumed by the same command: it cuts the worktree
for the branch and moves nothing.

## The item file is on the default branch from the start

`workbench new` writes the file into the main checkout wherever it runs and
commits it there, as `new <id>: <title>` — so the main checkout must have the
default branch checked out, and `new` refuses otherwise, before spending an
id. Written in a worktree instead, it would ride that item's squash under the
wrong trailer. The criterion is filled in on main's copy; `workbench start`
commits that too, as `start <id>`, and cuts the branch from it — so the
branch carries the item as agreed, and the default branch shows every item
from the moment it exists.

From `start` on the item is edited **on its branch only**: root cause,
evidence, status. Main's copy stands as the item started and is never edited
while the branch exists: `merge` and `archive` compare it with the cut and
refuse if it moved — the squash is a three-way merge, and a main-side edit in
a hunk the branch never touched would otherwise merge in silently, a
criterion changed under evidence recorded against the old one. At merge the
branch's copy replaces main's in the same commit as the code, which is what
keeps evidence and the change together and main free of half-written items.

So the default branch tells the whole story: an item file with no branch and
no trailer is open and not started; with a branch, started — `workbench
status` marks it so; with a trailer and no branch, merged; under `archive/`,
done. Every worktree inherits main's copies, so a sibling's copy of an item is
not a second item; only the copy on the item's own branch is edited.

The one thing the default branch cannot show is an item merged as `awaiting`:
it has no branch left, so in-flight is branches **plus** that status.
`workbench status` reports both halves; do not reconstruct it. Which statuses
merge and which archive: [items.md](items.md), "What each gate asks".

An item written by hand, untracked, is landed by `start` the same way —
moved to the main checkout first if it was written in a worktree, once the
criterion check has passed. One committed on another item's branch is
refused: it would reach the default branch twice.

## Merging

```bash
workbench merge f-037 "resolve position from the client rather than the frame"
```

Squashes the branch onto the default branch as one commit, removes the
worktree, deletes the branch. The subject is the one argument; the message is
the subject and the trailer, nothing else:

```
resolve position from the client rather than the frame

Item: f-037
```

A merge that skipped the review gate carries a second trailer, `Review: skipped`, and nothing else ever does — `git log --grep="Review: skipped"` lists every one. **Nothing else goes in the message.** A body would be a second source of truth
and would tempt a reader to use it instead of opening the item, which is the
contract. The subject describes the change, not the item's title.

The command refuses, before touching anything, when the main checkout is not on
the default branch, has staged changes or an uncommitted deletion (an unstaged
edit stays out of the squash and is tolerated), the worktree has uncommitted
changes or is locked, the branch conflicts with the default branch (rebase it in
the worktree first), or the default branch already carries the trailer. It does
not push.

It reads the item file **from the branch**, and refuses when that copy is
missing, has an unclosed fence, carries a status that is not one, says
`awaiting` or `unverified` without naming a trigger, or is `open` with no fenced
block under `## Evidence`. Those are structural questions — is there evidence at
all — not whether the evidence shows what it claims, which is the pre-merge
review's question; see [items.md](items.md), "What each gate asks".

A pre-merge report lives untracked in the worktree, so it counts as
uncommitted there: `workbench review-drop` it after triage, before merging.

Needs git 2.38 or later: the conflict check is `merge-tree --write-tree`. Also
GNU coreutils, findutils and sed (`date -r`, `find -printf`, `chmod
--reference`, `sed -i`): Linux, or macOS with the GNU tools first on `PATH`.

A worktree deleted by hand (`rm -rf .worktrees/<branch>`) stays in `git
worktree list` until `git worktree prune`; `merge` and `archive` say so and
stop until it is run. Lookups skip it meanwhile.

Every item merges this way. Housekeeping goes straight to the main branch
(SKILL.md, "Domain work is an item").

## Traceability

Git has no pull request. Pull requests are a feature of a hosting service, kept
in that service's database rather than in the repository, so nothing here
depends on one. The trailer and the recorded commit SHA do the work:

```bash
git log --grep="Item: f-037"    # item -> the commits that implemented it
git log -p -- path/to/file      # file -> commits -> item IDs -> why it is like this
```

The second lookup is the valuable one: it answers "why does this file look like
this" without reading the code.

This survives adding a hosting service later, so adopting one changes nothing.

## Archiving

Move the item to `workbench/items/archive/` and record the commit SHA in it.

**What triggers it is the criterion being satisfied, not the merge.** The two
usually coincide; when they do not, the statuses in [items.md](items.md) apply.

The recorded SHA is resolved from the trailer, on the default branch:

```bash
git log main --grep="^Item: b-038$" --format=%h -1
```

Not `HEAD`, which is whatever the checkout happens to sit on, and not `--all`,
which can hit a branch commit that the squash then discards. `workbench
archive` resolves the branch as `git config workbench.main`, then
`origin/HEAD`, then `main` or `master`.

The command refuses while the item's branch still exists — archived first, the
item would record `commit: none` for good while the squash commit arrives
later. Two branches never merge, and `archive` retires those itself: the branch's
copy of the item replaces main's, the worktree and branch go. An `unreproduced`
bug's holds nothing but the item file — nothing to fix — and anything else on
it is work, which merges or is discarded by hand. A research item's may hold
prototypes, throwaway by definition, and an `abandoned` item's whatever was
built before the user dropped it; `archive --discard` drops those, naming
each, and without the flag the command refuses and says so.

The move is left uncommitted; the command prints the commit to make.

## IDs

Format `<letter>-<number>-<slug>`, e.g. `f-037-mob-positions`,
`b-038-frozen-coords`. The letter is `f` for feature, `b` for bug, `r` for
rename, `x` for research, and is kept even though the folder already says the
class, because `workbench/items/archive/` is flat.

The ID seeds everything downstream:

```
workbench/items/features/f-037-mob-positions.md
branch:  f-037-mob-positions
commit:  "resolve position from the client\n\nItem: f-037"
```

### Where the number comes from

A counter in the shared git directory, `.git/item-seq`. Every worktree resolves
to the same one, so a single sequence serves all of them and numbers can never
repeat. One sequence for every class as well: `b-001` is followed by `f-002`,
so a number names one item whatever its letter — which is what keeps the "both
are merged" repair below safe. Increments are guarded by an atomic lock
directory, so simultaneous allocations from different worktrees cannot collide.

If the counter is missing — a fresh clone, or another machine — it is rebuilt
from the highest ID already present in the repository, including
`workbench/items/archive/`. Numbers are therefore never reused after archiving.

Allocate with `workbench new`. Never choose an ID by hand: a hand-picked
number does not advance the counter, and the next allocation will collide
with it.

Adoption is a property of the repository, not of a checkout: because the counter
lives in the shared git directory, a worktree whose branch predates adoption can
still allocate.

## Duplicate IDs across machines

The counter is a cache; the repository is the source of truth. Allocation takes
whichever is higher, the counter or the highest ID already in the tree, so a
stale counter on a machine that has just pulled cannot hand out a number
history already used.

One window remains and cannot be closed without a coordinator: two machines
allocate before either pushes. Both get the same number, and because the slugs
differ the filenames differ, so **git merges them silently** — no conflict, two
items sharing an ID.

`workbench status` detects it, by ID prefix rather than by filename — two items
sharing a number have different slugs, so the filenames do not collide.

Repair depends on what has already merged:

| Situation | What to do |
|---|---|
| neither is merged | renumber the one allocated later — rename the file, rename its branch |
| one is merged | the merged one keeps the ID; renumber the other |
| both are merged | renumber the file only; do not rewrite history |

The last row looks lossy and is not, because **the SHA is the authoritative link
and the trailer is only an index**. An archived item records the commit it
merged as, so it still resolves exactly. `git log --grep="Item: b-046"` returns
two commits after such a repair; the recorded SHA in each item says which is
which. Nothing is written into either file about the renumbering — the SHA
already carries it.

Prevention is one habit: pull before allocating.
