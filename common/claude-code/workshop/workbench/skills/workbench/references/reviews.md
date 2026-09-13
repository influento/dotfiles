# Reviews

A review is a deliberate sweep that produces a report. It is not tracked work
— it is how work gets found — and one of them, `pre-merge`, is the gate the
user may ask for before `workbench merge`.

Run one with `/workbench-review <reason> ["scope"]` — a fork with none of
the conversation in it, at the gates SKILL.md "Review sweeps" names or when
the user asks. A scope is paths or words, quoted when it has spaces; paths
get a manifest, words do not. It is substituted inside a double-quoted shell
argument, so a quote, backtick, `$` or backslash in it aborts the skill with
no message.

The sweep is held to its contract by `workbench review-check`, run in the
invoking context on the returned path. The sweep's own rules per reason live
with the sweep skill, in `workbench-review/rules/`.

## Reasons

| Reason | When |
|---|---|
| `pre-merge` | the user asks for the gate on an item about to merge. Scope is the item id; the sweep is rooted at the item's worktree wherever it is invoked from, and the files the branch changed are its manifest. `review-check` names the branch commit a `merge` verdict read and counts a `hold`; at three the merge is the user's call |
| `docs` | audit documents against the code they describe, and the vocabulary of recent items against `workbench/GLOSSARY.md`; a `cap:` line from `workbench status` names the file |

## Reports

Live in `workbench/reviews/`. There is no required structure — it varies with what was
asked for and who is reviewing. In practice a report is findings with evidence,
often with a suggested fix. Do not impose a template.

## Triage

The user and the agent go through the report together. The decision is the
user's, informed by the agent's opinion. A finding promoted to a bug item is
reproduced first, from the report's own command; one that does not reproduce
is dropped, not filed — `unreproduced` is for a bug that was seen, not for
one that was read.

**Never create items automatically from a report.** Only findings that survive
triage become items, using `workbench new`.

Unattended, the agent triages a pre-merge alone, as SKILL.md "Review
sweeps" says. Sweeps other than pre-merge wait for the user: their findings
are a report under `workbench/reviews/`, and `status` says "awaiting
triage".

## What a sweep may write

Nothing tracked. The report, and anything under `workbench/scratch/<report>/`
— helper scripts, captured output, probes. That directory ignores itself, so
it never appears in the tree's diff, and `review-drop` deletes it with the
report. A helper worth keeping is a finding: it becomes an item, and lands as
a tracked script through the ordinary loop.

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
Any prose beyond the skeleton is findings to that check, so an unchecked
report that only says what was covered needs `--force` too.

The baseline hashes every untracked, unignored file, at open and again at
check. Build output or a vendored tree left unignored turns that into a
crawl; `review-check` says so above 500 files. Ignore it.

The report and its baseline are created before the sweep runs, so a sweep that
errors or is aborted leaves both behind. A same-day collision gets a numbered
suffix (`20260826-docs.2.md`) rather than an error, so orphans do not stop
the next sweep. The report directory needs no placeholder: `workbench review`
creates it, and reports are never tracked.
`workbench status` lists every report in one of four states:

| State | Means |
|---|---|
| unchecked | report and baseline both present — the sweep never returned, or `review-check` failed (tree edited, a citation that resolves nowhere, a scope file never named) and left the baseline for a re-run; inspect, then drop |
| awaiting triage | report only — `review-check` passed, triage is pending |
| stale marker | baseline only — the report was removed by hand; drop it |
