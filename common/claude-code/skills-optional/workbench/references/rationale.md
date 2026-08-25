# Rationale

The arguments behind choices that look arbitrary or look like omissions, kept
so that a later reader can see what was already considered before re-opening
one.

## Why ideas live in one file and items in many

Ideas are browsed as a list, to pick what is next. Items are looked up
individually, by ID, from a commit. Different access patterns, different shapes.

## Why the criterion carries the defence, not the test

The reader may not read test code. A test can assert nothing, assert a mock, or
be written from finished code so that it agrees with the bug. None of that is
visible in a green result. The criterion is short enough to actually read, so
that is where the defence sits.

## Why there is no findings directory

A dated record of an external fact looks like it can never rot, because the
statement stays true. It still stops being useful — the dependency is upgraded,
the behaviour changes, and a technically accurate document is read as current by
whoever finds it next.

Worse, such a file has nothing that invalidates it, so nothing ever triggers its
review and nothing ever deletes it. It is the one document class that can only
grow.

None of that is lost by removing it, because the thing worth keeping — why the
code is shaped this way — was never in the document. It is in the item, which is
dated by its commit, permanent, and reachable from any file through the trailer.

The same argument removes measured baselines. A number matters because it was
evidence for some item, and that is where it lives, together with the command
that produced it. A number in a file that nothing re-measures is an old
measurement presented as a current one.

## Why technical facts go in the repository rather than agent memory

Memory is not versioned, so it cannot be diffed against the commit that
invalidated it. It passes through no review, so it is written at the agent's
discretion and never checked. And it is keyed to a directory path, so a worktree
gets a different store and anything written there is invisible elsewhere.

## Why `rename` is a class and `refactor` is not

`rename` looks like a special case carved out of a homeless general one, since
a rename is a refactor. It is not. The classes are shapes of criterion, not
kinds of edit, and there are only two shapes:

- **fixed** — the class supplies the criterion, and the author has no choice in
  it. `rename` is the only one: an occurrence count over a scope.
- **free** — the author supplies the criterion per item. `bug` and `feature`
  are this, and every refactor that is not a rename is too.

So a standalone refactor is not homeless; a free-shape class already exists and
it is `feature`. Adding `refactor` would add no shape, and would create the one
place where work could go without an observable claim attached to it.

The deeper reason a general refactor cannot be its own class: its natural
criterion is "behaviour is unchanged", which is green before the work starts.
See the unchanged-tree rule in verification.md.

## Why the obligation lives in the project's `CLAUDE.md`

A skill description only fires when a request *looks like* a match. That is good
enough for a capability and not good enough for a rule that says all domain work
gets an item, since the requests that most need the rule are the ones that look
like small favours. So the obligation sits in `CLAUDE.md`, which is always in
context, and the detail stays here, loaded only once the rule has fired.

## Why the sweep's contract is not enforced by a hook

"Write exactly one file" reads like something a `PreToolUse` hook should hold,
rejecting any path outside `workbench/reviews/`. Skill-scoped hooks do not fire
inside a forked context, and the sweep is a fork by design, so the hook would
never run. Declaring one would be worse than declaring nothing: the contract
would read as enforced while nothing checked it.

The tool set narrows the fork instead — no `Edit`, no subagents, no web — but
`Bash` has to stay so the sweep can build, test and grep, and `Bash` can write
through a redirect. So the tool set removes the convenient path and nothing
more. `workbench review-check` is the only thing that actually proves the
contract held, which is why it is run on every returned report rather than only
on a suspicious one.

It can prove it because the baseline predates the fork's first turn: the
skill's preprocessed block records the tree — status plus content hashes, since
mid-item the tree is normally dirty and a modified file keeps the same status
line when modified again, plus `HEAD`, since on a clean tree an edit that is
then committed leaves all of those exactly as they were — and only then writes
the skeleton. The one permitted delta is the report appearing.

What it cannot prove is that the sweep did the work. The fork's reads happen in
tools whose calls never touch the tree, so there is nothing to record. Two
checks stand where the proof would: every `path:line` the report cites must
exist, because the one mistake a sweep that read nothing cannot avoid is
pointing at a place that is not there; and every file in a path scope must be
named in the report, or its directory, because coverage that is stated can be
wrong but coverage that is absent cannot even be questioned. The manifest is
written into the skeleton and recorded in the baseline, and the check runs over
the report with its comments stripped — what the sweep wrote, not what it was
handed. A sweep that names every file without opening one still passes.

The citation check reads the whole report, pasted command output included.
Real output cites places outside the tree — a host and port, a stack frame
under `/usr` — and those are skipped by their shape, never by where they sit.
Real output also cites bare basenames, which is why a slashless token
resolves against every file of that name and the sweep gets the benefit of
the doubt when several match; and why a slashless name with an extension no
tree file carries reads as a host rather than a fabrication. Both rules are
decided from the tree — `git ls-files` — never from anything the report says
about itself.
Exempting a region of the report, a fenced block say, looks like the obvious
relief the first time a watch report fails on a stack trace; it is not, because
the sweep writes every byte of the report, so any region it can mark exempt is
a region it can hide a bogus citation in. Provenance would be the real
distinction, and the check has no access to it. When a new legitimate shape
turns up, extend the skip list by shape.

## Why retrieval is keyed to files and capped

Knowledge that goes into items has to come back out, or the archive is
write-only and the agent re-derives what a past item settled. Keying retrieval
to a topic overloads the context with whatever shares a word; keying it to
the files about to change is exact, because the trailer already indexes them
through `git log`. The cap and the "read at most two" rule are the other half:
the feature pays for itself only while it narrows code reading, and the
moment it adds reading it is worse than nothing. See `find` in
[items.md](items.md).

## Why milestones are optional and there is nothing above them

A hierarchy that every item must slot into turns starting work into deciding
where it goes, and for one person that decision is where a day disappears. So
a milestone is a big-picture goal only, an item may name one or not, and the
level above — designs, epics, brainstorm records — does not exist. What a
conversation decides lands in a milestone or an item; the conversation itself
is not an artifact.

## Why a watch may investigate freely but never fix

Unattended, the worst a watcher that only observes and restarts can do is
restart something three times and wake someone up. A watcher that fixes can
do anything, and does it at the hour nobody is reading. So the line is not
drawn at what the fork may *do* — it may poke the running app, write helper
scripts, send it whatever it likes — but at what it may *change*: the
running system only as the contract lists, the repository never. The
morning's item carries the fix, through the same gates as by day, and the
shift's whole value is that the evidence for it was captured before the
restart destroyed it.
