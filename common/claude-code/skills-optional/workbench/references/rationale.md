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
path so a worktree gets a store of its own — `init` removes by pointing
`autoMemoryDirectory` at `.claude/memory/` in the tree: one store, committed,
shared by every worktree and every clone at the same path. What that buys is
sync and a diff. What it does not buy is review, which is why the `memory` sweep
reason exists.

## Why `rename` is a class and `refactor` is not

`rename` looks like a special case carved out of a homeless general one, since
a rename is a refactor. It is not. The classes are shapes of criterion, not
kinds of edit, and there are only two shapes:

- **fixed** — the class supplies the criterion, and the author has no choice in
  it. `rename` is one: an occurrence count over a scope. `research` is the
  other: every concept terminal and pointing at something real, and an outcome
  written.
- **free** — the author supplies the criterion per item. `bug` and `feature`
  are this, and every refactor that is not a rename is too.

So a standalone refactor is not homeless; a free-shape class already exists and
it is `feature`. Adding `refactor` would add no shape, and would create the one
place where work could go without an observable claim attached to it.

The deeper reason a general refactor cannot be its own class: its natural
criterion is "behaviour is unchanged", which is green before the work starts.
See the unchanged-tree rule in verification.md.

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
fresh clone, had no commands, no hook and no status line. A committed copy
is in every checkout git makes. The price is drift, and it is paid
visibly: each copy carries a hash of its source, `status` lists the ones
that have fallen behind, `init` re-renders them, and the copy is never
edited by hand. Files ending in `.tpl` are rendered on the way, which is
where per-project content goes if a project ever needs any.

A copy the user edits by hand is the other half of drift: the stamp holds
the copy's own hash beside the source's, `status` names an edited copy
apart from a stale one, and `init` overwrites it only with `--force`. The
edit belongs in the source.

The session hook, status line and `Bash(workbench:*)` go in the tracked
`.claude/settings.json` for the same reason; the setup checklist names all
three so the user can strike any.

A project skill wins over a Claude Code builtin of the same name, so the
names were chosen against that list. `/bug` shadows the builtin bug-report
form, which loses nothing in a project with its own tracker. `/rename`
would have shadowed renaming the conversation in every adopted project, for
the rarest item class, so a rename is `/wb rename <old> to <new>` instead.

## Why the obligation lives in the project's `CLAUDE.md`

A skill description only fires when a request *looks like* a match. That is good
enough for a capability and not good enough for a rule that says all domain work
gets an item, since the requests that most need the rule are the ones that look
like small favours. So the obligation sits in `CLAUDE.md`, which is always in
context, and the detail stays here, loaded only once the rule has fired.

## Why the agent invokes the pre-merge review itself

The sweep was user-only at first, so that a review meant a person had asked
for one. That held until a session ran twenty hours with nobody there: it
merged forty-six times, and the gate that reads the item against its
evidence fired zero times, because the one thing the agent could not do was
start it. Every defect that gate exists to catch — a guard in the criterion
field, a criterion reworded to the number the code produced, a vocabulary
drift — was in the archive by morning.

The fork is a fresh context by construction — `context: fork` starts the
subagent with the skill's text and none of the conversation — so the
reviewer has never seen the reasoning behind the code it reads, whoever
started it. The baseline is taken by the skill's preprocessed block before
the fork's first turn, and that block runs on a model invocation as on a
slash command. So the proof that the sweep changed nothing holds either
way; what the user-only rule bought was timing, and timing is now the
gates in SKILL.md "Review sweeps". A clean pre-merge records the branch
commit it read, and `merge` asks for that record: the review cannot be
skipped, and cannot be stale.

What stays the user's is every other reason. A sweep the agent starts
because the code "looks like it needs one" is a cost nobody chose, and the
findings would wait for triage anyway.

## Why an absent user's decisions are marked rather than made

The statuses `awaiting` and `unverified`, a research concept's terminal
state, a parked call — each is the user's because it is a claim about what
the project accepts as done, and the agent's incentive at that moment runs
the other way. Unattended, the agent used to have two choices: stop, or
decide and say so in prose. It chose prose — "what this did not prove" as a
section, "the operator call lapsed" as a heading, a two-hundred-word line in
the backlog — and the result was decisions that were made in fact and
recorded nowhere a grep could find.

The ` (agent)` marker and `DECISIONS.md` are the third choice: the decision
is made in the one form the tools read — the status line, the state line —
and marked as provisional in the same place, with a one-line index the user
reads first on return. Confirming is deleting the marker. The backlog goes
back to being ideas, milestones go back to being goals, and nothing that is
a question is written as a paragraph.

## Why the sweep's contract is not enforced by a hook

"Write exactly one file" reads like something a `PreToolUse` hook should hold,
rejecting any path outside `workbench/reviews/`. Skill-scoped hooks do not fire
inside a forked context, and the sweep is a fork by design, so the hook would
never run. Declaring one would be worse than declaring nothing: the contract
would read as enforced while nothing checked it.

The tool set narrows the fork instead — no `Edit`, no subagents, no web. It
is the `wb-reviewer` agent's `tools:` that does this, not the skill's
`allowed-tools`: a fork takes its agent's tool set and nothing else, while
`allowed-tools` only pre-approves what is listed and removes nothing (both
probed on Claude Code 2.1.248; the docs say the second, and were once read to
say the opposite). `Bash` has to stay so the sweep can build, test and grep,
and `Bash` can write through a redirect. So the tool set removes the
convenient path and nothing more. `workbench review-check` is the only thing
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

Research is not that level. It sits *before* an item or milestone can be
written, not above them, and it holds no work — only a scope that ends by
decomposing into the levels that do.

## Why `research` is a class and a brainstorm record is not

A brainstorm record is the findings directory argued against above with a
different name: no end, nothing that invalidates it, and it can only grow.
Research has an end, the end is checked, and what survives it is a set of
decisions each pointing at an item, a milestone, a backlog line, or a stated
reason for dropping — every one reachable from the thing it spawned. The
prose that produced those decisions is rewritten each iteration rather than
kept, which is what keeps the file from becoming the record it replaces.

It never merges for the same reason a refactor is not a class: a prototype
that should ship is, by then, describable — so it is an item, with a
criterion, under its own trailer. Letting research merge would be the one
path by which code lands with no observable claim attached.

## Why sizing is one question

Whether something is an idea, an item, a milestone or research could be
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
