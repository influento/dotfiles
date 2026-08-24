# Reviews

A review is a deliberate sweep that produces a report. It is not part of
finishing an item, and it is not tracked work — it is how work gets found.

Run one with `/workbench-review <reason> ["scope"]`, which forks so the sweep's
reading stays out of the main context. A scope is a slug seed — letters,
digits, spaces, hyphens — quoted when it has spaces. Anything else lands
unescaped in a shell command and aborts the skill with no message.

The sweep is held to its contract by `workbench review-check`, run in the
invoking context on the returned path; how, and where the check stops, is in
[rationale.md](rationale.md). The sweep's own rules per reason live with the
sweep skill, in `workbench-review/rules/`.

## Reasons

| Reason | When |
|---|---|
| `sweep` | periodically, on demand, over an area — looking for bugs, improvements, cleanup, and for `awaiting` items whose trigger never fired |
| `pre-merge` | a chunk of work is finished and about to merge |
| `docs` | audit documents against the code they describe, and the vocabulary of recent items against `workbench/GLOSSARY.md` |
| `memory` | audit the agent's stored memory for facts that belong in the repo, or are stale |
| `adopt` | bringing an existing project in — see [adopt.md](adopt.md) |

Nothing is written before a review runs except the reason.

## Reports

Live in `workbench/reviews/`. There is no required structure — it varies with what was
asked for and who is reviewing. In practice a report is findings with evidence,
often with a suggested fix. Do not impose a template.

## Triage

The user and the agent go through the report together. The decision is the
user's, informed by the agent's opinion. Findings are commonly double-checked
before being promoted.

**Never create items automatically from a report.** Only findings that survive
triage become items, using `workbench new`.

## Lifecycle

```
review runs -> report written -> review-check -> triaged jointly -> items created -> workbench review-drop
```

Reports are never archived. Once triaged, everything worth keeping is in an
item, and the report is redundant. `workbench review-drop <report>` is the one
way to remove one, at either end of its life — it also removes the tree
baseline the report was opened with, which a hand `rm` leaves behind. It
refuses an unchecked report with findings unless passed `--force` — triage
leaves no mark on a report, so the baseline is what says nobody has read it.

The report and its baseline are created before the sweep runs, so a sweep that
errors or is aborted leaves both behind. A same-day collision gets a numbered
suffix rather than an error, so orphans do not stop the next sweep.
`workbench status` lists every report in one of three states:

| State | Means |
|---|---|
| unchecked | report and baseline both present — the sweep never returned, or `review-check` failed and left the baseline for a re-run; inspect, then drop |
| awaiting triage | report only — `review-check` passed, triage is pending |
| stale marker | baseline only — the report was removed by hand; drop it |
