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

Memory passes through no review: it is written at the agent's discretion,
never checked, and nothing invalidates an entry when a commit makes it wrong.
An item is dated by its commit and reachable from any file through the
trailer; a memory entry is neither. That is the whole argument, and it holds
whether or not the store is versioned.

Two more legs — memory that is machine-local, and keyed to the checkout's
path so a worktree gets a store of its own — `init` removes by putting the
store in the tree; [docs.md](docs.md), "Repository documents or agent
memory", says how. What that buys is sync and a diff, not review.

## Why the commands are thin, and the copies committed

`/bug` and the others hold no rules: a rule in two places drifts, and the
skill body is the one place. They also run no shell before the first turn,
though a preprocessed block could allocate the id: a title with a quote or a
`$` breaks a substituted command, and the sizing call belongs before an id
exists — an agent that has already allocated `f-051` argues for a feature.

The skills under `.claude/skills/` are rendered copies of the dotfiles
sources, and they are committed. A symlink would keep every project on the
latest source for free, but it is one machine's path and it exists only in
the checkout it was made in — a session opened inside a worktree, or a
fresh clone, had no commands and no hook. A committed copy
is in every checkout git makes. The price is drift, and it is paid
visibly: each copy carries a hash of its source, `status` lists the ones
that have fallen behind, `init` re-renders them, and the copy is never
edited by hand.

A copy the user edits by hand is the other half of drift: the stamp holds
the copy's own hash beside the source's, `status` names an edited copy
apart from a stale one, and `init` overwrites it only with `--force`. The
edit belongs in the source.

The session hook and allow rules go in the tracked
`.claude/settings.json` for the same reason; the setup checklist names them
so the user can strike any.

A project skill wins over a Claude Code builtin of the same name, so the
names were chosen against that list. `/bug` shadows the builtin bug-report
form, which loses nothing in a project with its own tracker.

## Why the obligation lives in the project's `CLAUDE.md`

A skill description only fires when a request *looks like* a match. That is good
enough for a capability and not good enough for a rule that says all domain work
gets an item, since the requests that most need the rule are the ones that look
like small favours. So the obligation sits in `CLAUDE.md`, which is always in
context, and the detail stays here, loaded only once the rule has fired.

## Why an absent user's decisions are marked rather than made

The statuses `awaiting` and `unverified`, a parked call — each is the user's because it is a claim about what
the project accepts as done, and the agent's incentive at that moment runs
the other way. Unattended, with only two choices — stop, or decide and say
so in prose — the agent chooses prose: "what this did not prove" as a
section, "the operator call lapsed" as a heading, a two-hundred-word line in
the backlog. Decisions made in fact and recorded nowhere a grep could find.

The ` (agent)` marker and the item's `## Decisions` are the third choice:
the decision is made in the one form the tools read — the status line — and
marked as provisional in the same place, with the open question beside it
in the item and listed by `workbench status` on return. Confirming is deleting the marker. The backlog goes back to being
ideas, and nothing that is a question is written as a paragraph.

## Why retrieval is keyed to files and capped

Knowledge that goes into items has to come back out, or the archive is
write-only and the agent re-derives what a past item settled. Keying retrieval
to a topic overloads the context with whatever shares a word; keying it to
the files about to change is exact, because the trailer already indexes them
through `git log`. The cap and the "read at most two" rule are the other half:
the feature pays for itself only while it narrows code reading, and the
moment it adds reading it is worse than nothing. See `find` in
[items.md](items.md).

## Why sizing is one question

Whether something is an idea, an item or a spike could be
argued fresh each time, and then no two calls would match, and the archive
would stop being something a later reader can rely on. So it is one question
— how well can it be described right now — with a row per answer, and the
one-item-or-several question is one test — could an entry go green and merge
while the others are red. The agent names the row; the user confirms. The
rows are in SKILL.md so they are in context whenever the rule fires.

The idea row is the one place the question does not decide alone. "Crash
on save" is one obvious sentence and also an item, and the rule says item;
a second axis — is anyone doing it now — would have to be judged fresh each
time, which is the drift the rule exists to stop. So the agent never
proposes the backlog for something item-shaped, and the user reaches it by
saying so: `/idea` is that signal, and it takes the sentence in the user's
words without argument. Deferral is an act of the user, not a level the
agent assigns.
