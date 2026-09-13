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
memory", says how. What that buys is sync and a diff. What it does not buy
is review, which is why the `memory` sweep reason exists.

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

## Why the pre-merge review is the user's to ask for

The sweep was user-only at first, so that a review meant a person had asked
for one. That held until a session ran twenty hours with nobody there: it
merged forty-six times, and the gate that reads the item against its
evidence fired zero times, because the one thing the agent could not do was
start it. So the gate became a required step of `merge`, invocable by the
agent, with `review-check` recording the branch commit it read.

Three measured runs later it came out of the required path again: the fork
found no code defect the review dialog had not, blocked a correct item twice
on the wording of its criterion, and cost a rerun each time. What it catches
that the dialog does not — a criterion reworded after the code, a RED
asserted rather than measured — is what a person reads for when they open
an item, so the fork stays as the sweep to ask for, not the toll every merge
pays. The dialog is the required read: a reviewer that runs the code and
argues, then `round`, which records the exchange on the item.

The fork is a fresh context by construction — `context: fork` starts the
subagent with the skill's text and none of the conversation — and the
baseline is taken by the skill's preprocessed block before the fork's first
turn, so the proof that the sweep changed nothing holds whoever started it.

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

## Why the sweep's contract is not enforced by a hook

"Write exactly one file" reads like something a `PreToolUse` hook should hold,
rejecting any path outside `workbench/reviews/`. Skill-scoped hooks do not fire
inside a forked context, and the sweep is a fork by design, so the hook would
never run. Declaring one would be worse than declaring nothing: the contract
would read as enforced while nothing checked it.

The tool set narrows the fork instead — no `Edit`, no subagents, no web. It
is the `wb-gate` agent's `tools:` that does this, not the skill's
`allowed-tools`: a fork takes its agent's tool set and nothing else, while
`allowed-tools` only pre-approves what is listed and removes nothing (both
probed on Claude Code 2.1.248, not taken from the docs). `Bash` has to stay
so the sweep can build, test and grep, and `Bash` can write through a
redirect. So the tool set removes the
convenient path and nothing more. The paths the contract allows are the
other half: `init` merges `Edit(workbench/reviews/**)` and
`Edit(workbench/scratch/**)` into `permissions.allow`, because a fork takes
the permission mode of the session that opened it, and under `dontAsk` a
`Write` with no rule is refused — the sweep then falls back to a `Bash`
redirect, two turns later, and the tool set has bounded nothing. An allow
rule is honoured there, and it is the `Edit(...)` form that governs `Write`:
a `Write(...)` rule is accepted and ignored (both probed 2.1.263). So the
gate's `Write` lands whatever mode the session runs in. `workbench review-check` is the only thing
that actually proves the contract held, which is why it is run on every
returned report rather than only on a suspicious one.

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
relief the first time a report fails on a stack trace; it is not, because
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

## Why the review dialog is a subagent and the gate a fork

They answer different questions. The dialog asks whether the code is good,
which is argued: a reviewer that remembers what it said, that can be shown
evidence and yield, or hold and say why. So it is spawned with the `Agent`
tool — a fresh context that never sees the worker's reasoning — and kept by
its id across the exchange. The gate asks whether the item is what it claims,
which is checked, not argued: criterion met by pasted output, no step
reworded, template only. A fresh fork each time, that never sees the
previous report, and a worker that fixes or asks. Merging the two would make
the gate persuadable, and the record of what was once persuaded away is what
`review-check` and `rounds:` exist to keep.

Round two always runs, a clean first round included. The dialog is the only
reading of the code for defects — the gate reads the item against its
evidence and template, and the code only for what the item promised — and a
clean round is one reviewer's
opinion of a branch it saw once; the second reviewer reads the branch the
first round changed, or confirms that a clean one really was. It is also the
cheapest context in the loop: an agent restricted to `Read`, `Glob`, `Grep`
and `Bash` opens on a short definition and the diff, against a gate that
opens on the whole sweep skill and its rules and reads everything again.
Dropping it would save cents and remove the only independent second read
before the gate.

