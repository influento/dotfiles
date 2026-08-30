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

## A criterion must fail on the unchanged tree

Run it before writing anything. If it passes, it is not a criterion.

A bug's fails — the thing is still broken. A feature's fails — the behaviour is
absent. A rename's fails — the count is N, not 0. One that is already green has
described the world rather than the change, and will be green at the end whether
or not the work was done.

This is the RED/GREEN argument applied to the criterion itself, and it catches
three things that otherwise look fine:

| Looks like a criterion | Why it is not |
|---|---|
| "behaviour is unchanged", "every command still does what it did" | a no-op passes it |
| "the module is cleaner", "the API is more consistent" | nothing runs, so nothing can fail |
| a rename count taken over the wrong scope | already 0 before the work |
| `tsc` is clean, the build passes, the import check passes | wiring; green before the work, and "A test may satisfy only what the criterion describes" (SKILL.md) keeps it out unless a criterion needs it |
| "verified by reading the function", "by inspection" | nothing ran. Reading is how a root cause is found, not how a claim is proved |
| a script written for this item, run once and deleted | the same rule — and nobody can run the evidence again |
| a line-count or grep-count bound chosen after the diff | a number the diff was going to move; it discriminates only when the RED count was measured first and written in |

Something that must hold *afterwards* but already holds *now* is a
**preservation guard**, not a criterion. Guards are real and worth recording —
the suite still green, a fixture still byte-identical — but they belong in
Evidence beside the criterion, never in the criterion field. An item whose only
check is a guard has no contract.

**A criterion the evidence cannot meet is missed, not amended.** Record the
miss under Evidence with the number it reached, and let the pre-merge review
decide whether the item ships with it. Rewriting the criterion to the number
the code produced is the criterion-after-code the whole rule exists to
prevent, and a criterion "corrected before the evidence was run" because it
was never run RED is the same thing a step earlier.

## Form

A criterion is a **description** of how to verify. Use a command when a real
tool already covers it. It may be a list; whether a list is one item or a
milestone with an item per slice is decided by SKILL.md, "Sizing", before the
item is written.

The field holds the steps and their expected results, with the RED value
measured now written beside each — `grep -c … (31 today) → 0`. Nothing
else: why the steps prove it belongs in the root cause or the Why, and a
paragraph of design inside the criterion is what made items twice their
length. If a step needs a sentence of rationale to be understood, the step
is wrong.

Never write a script whose only purpose is to satisfy a criterion. Real tooling
that does real work and happens to prove something is right; a test harness
created to make an item closable is not.

## Who runs it

The agent runs everything it can. Leave to the user only what genuinely needs
eyes — visual, subjective, or in-world judgements.

## Evidence

Record the actual output, not a summary of it, in a fenced block — `archive`
refuses an Evidence section without one. "Tests pass" is not evidence; the
command and its output are. A table typed by hand — `RED 31 → GREEN 0`,
`clean`, `-> yes` — is a summary, whatever the fence around it: paste the
command and what it printed, and let the reader do the arithmetic. One line
of prose per block, at most, saying which criterion step it settles; the
interpretation of the numbers is not the reader's problem to be spared.

An item may mix automatable and manual parts. Test what is testable, have the
user verify the rest, record both.

**Nothing is archived without verified evidence.** The exceptions are named in
[items.md](items.md), and each of them records what was *not* proved rather than
pretending otherwise.

## Merging and archiving are different questions

Merge asks whether everything that *can* be verified now has been; archive
asks whether the criterion is satisfied — the table is in
[items.md](items.md), "What each gate asks". Collapsing the two produces a
deadlock: a fix that can only be exercised by a real third-party event cannot
be verified until it ships, and cannot ship until it is verified. So an item
may merge while still open. The worktree goes, the change ships, and nothing
claims success until the criterion actually runs.

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

What each status lets merge and archive do is in [items.md](items.md), "What
each gate asks". Entering either state is the user's decision at pre-merge,
once the agent has shown what it verified and what it could not. Unattended,
the agent enters it with ` (agent)` and a `DECISIONS.md` line — the
decision is still the user's, made visible for when they return — and what
it never does instead is merge the item as plain `open`, or write "what this
did not prove" as a section and call that honesty. The status is the honest
form; a section is a status nobody can grep.

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
