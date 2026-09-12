---
paths: ["**/*.{ts,tsx}"]
---

# Lean code

Everything countable is gated in `ts-gate/`. This pass covers only what needs
intent to judge, over the files `bash ts-gate/scripts/gate.sh --list` prints.
Apply it as you write, and in review — where what `npm run gate:local`
reports is not a finding: the author's Stop hook blocks on it.

## Before writing

Stop at the first rung that holds:

1. Needs to exist at all? Speculative need: skip it, say so in one line.
2. Already in this codebase? Reuse the helper, type, or pattern. Look before you write.
3. Stdlib does it? Use it.
4. Effect ships it (Schedule, Cache, Duration, Stream, Schema, HTTP, RPC, CLI)? Use it; `effect.md` (from `stack add effect`) says where to check the API.
5. An installed dependency does it? Use it. A stack package does it (`stack list`)? Propose `stack add <name>`; never install ad hoc, and never add a dependency for what a few lines do.
6. One line? One line.
7. Only then: the minimum code that works.

Bug fix: a report names a symptom. Grep every caller of the function you touch
and fix the shared function once, not the one path the ticket names.

## Must be zero

| Check | Fix |
|---|---|
| Comment or JSDoc that restates the code or signature below it | Delete. A comment survives only for a why the code cannot show: constraint, gotcha, rejected alternative, spec reference. A deliberate ceiling is `// ponytail: <ceiling>, <upgrade path>` |
| Interface or type alias with one implementer and one consumer, both internal | Inline it |
| Export imported by exactly one other non-test file | Move it there, unexport |
| Function whose body only forwards its arguments | Call the target directly |
| Falsy guard on a required `string`/`number` param no caller passes empty | Delete |
| Back-compat shim, legacy alias, dual read/write path, deprecation stub | Delete unless asked. Internal code is not a contract: update every caller in the same commit |
| New file where the code fits an existing one | Merge |
| Hand-rolled version of something the stdlib ships (loop that is a `find`, manual `startsWith`, own `groupBy`) | Replace; name the method |
| Dependency whose job Node or TypeScript already does (`uuid`, `dotenv`, `node-fetch`, lodash for one function) | Replace with the native; name it |
| Flag, option, or config key nothing sets, or that only ever has its default | Delete the branch with it |
| Test whose expected value is computed the way the code computes it | Assert an independent literal |
| Test that verifies through a side channel (a database query where the interface has a getter) | Read back through the interface |
| Test that spies on an internal collaborator or asserts call counts (`vi.mock` itself is gated) | Fake only at a boundary not ours: an external service, time, randomness |

## Keep

Never simplify away: validation at trust boundaries (user input, network,
files), error handling that prevents data loss, security, accessibility,
anything explicitly requested. Two forms the same size: take the boring one
that is correct on edge cases. Non-trivial logic (a branch, loop, parser,
money or security path) that the change adds leaves one test that fails if
it breaks, within what the criterion describes; trivial one-liners get none,
and that one test is never a deletion finding.

Before adding code, check whether deleting code solves it instead.
