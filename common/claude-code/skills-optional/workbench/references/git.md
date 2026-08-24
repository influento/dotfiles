# Git

## Branches

One branch per item, named after it. `workbench start` creates the branch and its worktree together, under
`.worktrees/<branch>`. There is no branch-only path.

## The item file lives on the branch

It is created wherever you happen to be, edited during the work as the root
cause and evidence are filled in, and merges with its change.

A consequence: the main branch cannot show what is in flight, only what is
archived. `git branch` lists in-flight work, because branch names carry the ID
and slug. This is accepted, not a problem to solve.

The exception is an item merged as `awaiting` ([items.md](items.md)): it has no
branch left. So `git branch` is not the whole list — in-flight is branches
**plus** that status. `workbench status` reports both halves; do not
reconstruct it.

## Merging

Squash into one commit. Subject line describes the change; a trailer carries
the ID:

```
resolve position from the client rather than the frame

Item: f-037
```

**Nothing else goes in the message.** A body would be a second source of truth
and would tempt a reader to use it instead of opening the item, which is the
contract.

Every item merges this way. Housekeeping goes straight to the main branch
(SKILL.md, rule 1).

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

**What triggers it is the criterion being satisfied, not the merge.** For most
items those coincide — everything was verified before merging, so the item
archives immediately after. An item merged as `awaiting` ([items.md](items.md))
archives later, when its trigger fires and the criterion finally runs.

The recorded SHA is therefore resolved from the trailer:

```bash
git log --grep="^Item: b-038$" --format=%h -1
```

not from `HEAD`, which by then is whatever unrelated work happened since.

## IDs

Format `<letter>-<number>-<slug>`, e.g. `f-037-mob-positions`,
`b-038-frozen-coords`. The letter is `f` for feature, `b` for bug, `r` for
rename, and is kept even though the folder already says the class, because
`workbench/items/archive/` is flat.

The ID seeds everything downstream:

```
workbench/items/features/f-037-mob-positions.md
branch:  f-037-mob-positions
commit:  "resolve position from the client\n\nItem: f-037"
```

### Where the number comes from

A counter in the shared git directory, `.git/item-seq`. Every worktree resolves
to the same one, so a single sequence serves all of them and numbers can never
repeat. Increments are guarded by an atomic lock directory, so simultaneous
allocations from different worktrees cannot collide.

If the counter is missing — a fresh clone, or another machine — it is rebuilt
from the highest ID already present in the repository, including
`workbench/items/archive/`. Numbers are therefore never reused after archiving.

Allocate with `workbench new`. Never choose an ID by hand: a hand-picked
number does not advance the counter, and the next allocation will collide
with it.

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
