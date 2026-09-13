# Verification

## The criterion is the contract

Written **before** the code, and specific enough that someone who reads
nothing else can tell whether the work succeeded.

Weak: "confirm the positions are correct"
Strong: "`mobcheck.ts` reports drift under 0.05 tiles for mobs on a boundary row"

The criterion carries the defence, not the test: a test can assert nothing,
assert a mock, or be written from finished code so that it agrees with the
bug, and none of that shows in a green result.

## A criterion must fail on the unchanged tree

A bug's fails — the thing is still broken. A feature's fails — the
behaviour is absent. A rename's fails — the count is N, not 0. One that is
already green describes the world rather than the change.

| Looks like a criterion | Why it is not |
|---|---|
| "behaviour is unchanged", "every command still does what it did" | a no-op passes it |
| "the module is cleaner", "the API is more consistent" | nothing runs, so nothing can fail |
| a rename count taken over the wrong scope | already 0 before the work |
| the typecheck is clean, the build passes, the lint gate passes | wiring; green before the work. `workbench start` refuses such a step when `git config workbench.guards` names the command |
| "verified by reading the function", "by inspection" | nothing ran. Reading finds a root cause; it proves nothing |
| a script written for this item, run once and deleted | nobody can run the evidence again |
| a line-count or grep-count bound chosen after the diff | discriminates only when the RED count was measured first and written in |

Something that must hold *afterwards* but already holds *now* is a
**preservation guard**: worth recording — the suite still green, a fixture
still byte-identical — under Evidence beside the criterion, never in the
criterion field. An item whose only check is a guard has no contract.

**A criterion the evidence cannot meet is missed, not amended.** Record the
miss under Evidence with the number it reached; the reviewer, then the
user, decide whether the item ships with it. A criterion "corrected before
the evidence was run" because it was never run RED is the same thing a step
earlier.

## Form

Steps and their expected results, with the RED value measured now written
beside each — `grep -c … (31 today) → 0` — and nothing else: no rationale
(that is the root cause or the Why), no design. A step that needs a
sentence of rationale to be understood is wrong. Use a command when a real
tool already covers it; a test harness created to make an item closable is
not a criterion. Whether a list is one item or several is SKILL.md,
"Sizing", before the item is written.

## Numbers, flakes, exploits, regressions

One run does not make these RED:

| Shape | RED, measured now | GREEN |
|---|---|---|
| a number — latency, memory, build time | the metric over N runs with its spread: `p50 over 10 runs (340ms ±25 today) → under 200ms` | the same command and N, the spread under the target |
| a flake | `fails k of N`, the rate raised first — loop it, stress it — until k ≥ 5 | `0 of M` with M ≥ 3·N/k: at 5 of 100, 60 runs. Fewer, and an unchanged tree passes by luck |
| a boundary crossed | a working exploit, in a controlled environment | the exploit and two or more variants of the same input class fail |

A number's Evidence runs base and branch alternately in one session, the
base from a scratch worktree: workers in other worktrees share the machine,
so a figure from another session is not a baseline. What the number costs
elsewhere — memory for time, staleness for latency — is a side effect.

A flake whose root cause names an ordering or a clock gets a test that
injects it and fails every run without the fix (RED and GREEN as "Tests"
says); the criterion stays as frozen. A bounded search that names no
mechanism: Root cause reads `none found — mitigation`, and `workbench call
<id> "ship as a mitigation, or keep looking?"`. A retry or a longer timeout
that turns the count green is that mitigation.

A regression with a known-good commit: `git bisect run` the criterion in
the item's worktree (bisect moves HEAD; `git bisect reset` before the next
commit), from a script in the scratchpad, since older commits lack what the
branch added. Root cause names the commit bisect lands on and what in its
diff does it.

## Who runs it

The agent runs everything it can. The user gets only what needs eyes —
visual, subjective, or in-world judgements.

## Evidence

The actual output, in a fenced block — `archive` refuses an Evidence
section without one. The block is committed: replace any token, key or
personal data with `<REDACTED>` before pasting. "Tests pass" is not
evidence; a table typed by hand — `RED 31 → GREEN 0`, `clean` — is a
summary whatever the fence around it. Paste the command and what it
printed, with at most one line of prose per block saying which criterion
step it settles. Test what is testable, have the user verify the rest,
record both.

## Merging and archiving are different questions

Merge asks whether everything that *can* be verified now has been; archive
asks whether the criterion is satisfied ([items.md](items.md), "What each
gate asks"). Collapsed into one, a fix that only a real third-party event
can exercise could neither ship nor be verified. So an item may merge while
still open, and nothing claims success until the criterion runs.

Split the criterion first — almost everything that feels unverifiable is
two claims:

| Claim | Verifiable now? |
|---|---|
| our code reacts correctly to the event | **yes** — synthesise the event; that is real evidence |
| the real event has the shape we assumed | no — that is the assumption itself |

Verify the first and record the output; only the second may wait. Then:
can you name when?

| Answer | State |
|---|---|
| yes — next deploy, tomorrow's cron, the monthly run | `awaiting`, merged and open |
| no — "whenever they push one" | archive as `unverified` |

## Tests

The kind follows the criterion — unit, fixture replay, integration,
end-to-end, manual — with no fixed preference. Where a test is written and
cheap to re-run, record both **RED** (the command, the failing output, why
that failure was the expected one) and **GREEN** (the command and the
passing output). A test only ever seen green proves nothing to someone who
does not read tests.

| Kind | Loop? | Why |
|---|---|---|
| unit, fixture replay, integration | yes | milliseconds to seconds |
| end-to-end against a live system | **no** | minutes, real credentials, mutates real state, not safe in parallel |
| manual | **no** | needs a person |

End-to-end and manual checks run once and their output is recorded.

Tests are not referenced from the item: they live in the code, reachable
through the commit trailer, and naming them in the item is a second place
to drift.
