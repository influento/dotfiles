# Verification

## The criterion is the contract

An item's "how to confirm" field is written **before** the code and stands
alone. It must be specific enough that someone who reads nothing else can tell
whether the work succeeded.

Weak: "confirm the positions are correct"
Strong: "`mobcheck.ts` reports drift under 0.05 tiles for mobs on a boundary row"

Everything else follows from this:

- Evidence is matched against **the criterion**, never against a test.
- A test may satisfy only what the criterion describes. Nothing beyond it.
- The item carries the rationale — why these steps demonstrate it works.

It also settles what gets tested. Scope is bounded by the criterion, so config
files, deployment scripts, and wiring get no tests unless a criterion asked
for one.

## Form

A criterion is a **description** of how to verify. Use a command when a real
tool already covers it.

Never write a script whose only purpose is to satisfy a criterion. Real tooling
that does real work and happens to prove something is right; a test harness
created to make an item closable is not.

## Who runs it

The agent runs everything it can. Leave to the user only what genuinely needs
eyes — visual, subjective, or in-world judgements.

## Evidence

Record the actual output, not a summary of it. "Tests pass" is not evidence;
the command and its output are.

An item may mix automatable and manual parts. Test what is testable, have the
user verify the rest, record both.

**Nothing is archived without verified evidence.** The exceptions are named in
[items.md](items.md), and each of them records what was *not* proved rather than
pretending otherwise.

## Merging and archiving are different questions

| Gate | Asks |
|---|---|
| merge | has everything that *can* be verified now been verified? |
| archive | has the criterion been satisfied? |

Collapsing the two produces a deadlock: a fix that can only be exercised by a
real third-party event cannot be verified until it ships, and cannot ship until
it is verified. So an item may merge while still open. The worktree goes, the
change ships, and nothing claims success until the criterion actually runs.

### Split the criterion first

Almost everything that feels unverifiable is two claims, and only one of them is
genuinely blocked:

| Claim | Verifiable now? |
|---|---|
| our code reacts correctly to the event | **yes** — synthesise the event, that is real evidence |
| the real event has the shape we assumed | no — that is the assumption itself |

Verify the first and record the output. Only the second may wait: a simulation
written from your own assumption cannot prove that assumption, but it proves
your handling of it completely.

Reading the code is not verification. Running it against a synthesised event is.

### Then: can you name when?

| Answer | State |
|---|---|
| yes — next deploy, tomorrow's cron, the monthly run | `awaiting`, merged and open; it resolves shortly |
| no — "whenever they push one" | archive as `unverified` |

Both statuses are defined in [items.md](items.md). Entering either state is the user's decision at pre-merge, once the agent has
shown what it verified and what it could not. It is never the agent's own call,
which is what keeps it exceptional.

## Tests

The kind of test follows the criterion — unit, fixture replay, integration,
end-to-end, or manual. There is no fixed policy about which to prefer.

### RED before GREEN

Where a test is written and is cheap to re-run, record both:

- **RED** — the command, the failing output, and why that failure was the
  expected one
- **GREEN** — the command and the passing output

This is the only mechanism that makes a test trustworthy to someone who does
not read tests. Seeing it fail for the right reason proves it discriminates
between broken and working. A test that was only ever seen green proves
nothing.

### Where the loop does not apply

| Kind | Loop? | Why |
|---|---|---|
| unit | yes | milliseconds |
| fixture replay | yes | milliseconds |
| integration | yes | seconds |
| end-to-end against a live system | **no** | minutes, uses real credentials, mutates real state, not safe to run in parallel |
| manual | **no** | needs a person |

End-to-end and manual checks run once, and their output is recorded as
evidence. Do not loop them.

Tests are not referenced from the item. They live in the code and are reachable
through the commit trailer; naming them in the item creates a second place to
drift.
