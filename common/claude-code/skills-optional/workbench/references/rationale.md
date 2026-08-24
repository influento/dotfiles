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
