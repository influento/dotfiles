---
name: bugfix
description: Fix a reported defect by reproducing it first, then proving the fix against the same reproduction. TRIGGER when the user reports something broken, failing, wrong, slow, leaking, flaky, or exploitable, or asks to fix, debug, optimize, or speed up. SKIP for new features and refactors with no defect to reproduce.
---

# Bugfix

Red before edit. Same command green after. Anything else is a guess.

## Steps

1. **Classify.** Pick A, B, or C from the table. Note modifiers. Unclassifiable → pre-state, stop at step 2.
2. **Repro (red).** Build a runnable artifact that fails now: a test, a script, a measurement command. Prose steps are not a repro. Run it. Record the command and the observed output. Red not achieved → deliver the pre-state report, no edits.
3. **Cause.** One line: `X because Y`. The repro must exercise Y, not the surface symptom. Cannot name Y → back to step 2, narrow further.
4. **Fix.** One issue, one change. Nothing unrelated in the diff.
5. **Prove (green).** Rerun the identical command from step 2. Record the output. Not green → back to step 3.
6. **Guard.** Leave the repro in the suite as a test, benchmark, or threshold. It prevents the same bug twice.
7. **Report.** Every section filled, or the fix is not done:

   ```
   Issue:  <what was reported>
   Class:  A | B | C  + modifiers
   Repro:  <command> → <observed red>
   Cause:  X because Y
   Fix:    <one line>
   Proof:  <same command> → <observed green>
   Guard:  <test / benchmark / threshold path>
   ```

## Harness

When the code has nowhere to run (a tool installed into projects, a script, a config), the repro is a **scratch project**: create it under the scratchpad, install the tool into it the way a user would, run the failing command there. Red and green use the same scratch, reinstalled for green so the fix travels the real install path, not a hot-patched copy. Guard: fold the scratch steps into the tool's own tests when it has them; otherwise commit the scratch as `tests/repro-<issue>.sh` so the next person runs the same thing. The scratch stays in the scratchpad for reuse until the session ends; anything the repro left outside it (installed packages, global config, files in the real project) is removed as part of the fix.

## Classes

| Class | Shape | Red | Cause | Green | Guard |
| --- | --- | --- | --- | --- | --- |
| **A. Correctness** | expected X, got Y | failing test | `X because Y` | test passes | test in suite |
| **B. Efficiency** | works, number wrong | baseline: metric, command, N runs, spread; target stated | why the number is what it is | same command, spread no longer overlaps baseline; a trade (memory for time, staleness for latency) is named in the report | benchmark or threshold assertion |
| **C. Security** | boundary crossed | working PoC in a controlled env | the missing control, not the payload | PoC fails, plus 2+ variants of the same input class | negative tests for the class |

Symptom fixes are not fixes: `try/catch` around a crash (A), a faster benchmark instead of a faster workload (B: warm-up before timing, dropped outliers, narrowed input), blocking the one payload (C).

## Modifiers

- **Intermittent.** Red is `fails k of N`. Green is `0 of N`, same N. Start as A and hunt the deterministic cause: race, ordering, shared state, unseeded random, clock, external dependency. Cause found → make the repro deterministic (inject the ordering or clock). Bounded search finds nothing → downgrade to B explicitly: KPI is failure rate, fix is labelled *mitigation*, never *fixed*. Retry or timeout on an A-classified flake is a symptom fix.
- **Regression.** Known-good commit exists → `git bisect` with the repro is the tool. Cause must explain the offending diff.
- **Degradation over time.** Class B where the metric is a slope across iterations, not a point.

## Pre-states (no fix allowed)

- **Cannot reproduce.** Deliverable is instrumentation, logging, narrowed conditions, or a report of what was tried. Exit only into A, B, or C.
- **Subjective** ("looks off", "unclear"). Write an acceptance check first; that turns it into A. No check, no fix.
