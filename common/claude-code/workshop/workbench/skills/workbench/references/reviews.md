# Reviews

A review is a deliberate sweep that produces a report. It is not tracked work
— it is how work gets found — and one of them, `pre-merge`, is the gate every
item passes on its way to `workbench merge`.

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
| `sweep` | periodically, on demand, over an area — looking for bugs, improvements, cleanup, and for `awaiting` items whose trigger never fired |
| `pre-merge` | an item is finished and about to merge. Scope is the item id; the sweep is rooted at the item's worktree wherever it is invoked from, and the files the branch changed are its manifest. A clean `review-check` records the branch commit it read, and `workbench merge` refuses without that record on the branch's last commit — a branch that moved after the review is unreviewed again. `merge --no-review` is the user's override, refused while the mode is `unattended` |
| `docs` | audit documents against the code they describe, and the vocabulary of recent items against `workbench/GLOSSARY.md` |
| `memory` | audit the agent's stored memory for facts that belong in the repo, or are stale |
| `adopt` | bringing an existing project in — see [adopt.md](adopt.md) |
| `watch` | a shift over a running app: observe, recover as contracted, investigate, report — see "Watch shifts" below |
| `security` | vulnerabilities the change introduces — a concrete attack path from untrusted input, nothing theoretical. On an item's branch the diff is the scope; on the default branch, the paths given. On demand, for code with an attack surface: auth, wallets, anything parsing outside input |
| `usage` | what the last items cost and which setting would make the next ones cheaper. The agent runs it when `workbench status` prints a `usage:` line; the report ends in a `suggestions:` block of settings, each the user's to change — see [usage.md](usage.md) |

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

## Watch shifts

`workbench watch "<title>"` writes `workbench/watches/<slug>.md`, the contract
a shift runs under, and prints what to do next — fill it with the user,
allow-list its commands, start the loop. That output is the setup; nothing
here repeats it.

Every tick is a fresh fork; `workbench review watch <slug>` returns the open
shift's report instead of a new one while its baseline exists, so the ticks
share a timeline. What a tick does is the sweep skill's `rules/watch.md`.

`review-check` on a watch verifies the same things as on any report, with one
difference: the shift runs where you work, so a change to the tree — a tracked
edit, a new file, a commit — is listed for you to own rather than failing the
check; by night the list is empty. The baseline stays until `review-drop` ends
the shift; `workbench status` shows it as `watch shift open`. A resumed tick
withdraws the last check's verdict, since it may append findings that check
never saw, so the morning starts with a fresh `review-check`.

Morning: `review-check`, triage, `workbench new bug` for what survived with
the timeline's captures as *What was seen*, then `review-drop`.

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
suffix (`20260826-sweep.2.md`) rather than an error, so orphans do not stop
the next sweep. The report directory needs no placeholder: `workbench review`
creates it, and reports are never tracked.
`workbench status` lists every report in one of four states:

| State | Means |
|---|---|
| unchecked | report and baseline both present — the sweep never returned, or `review-check` failed (tree edited, a citation that resolves nowhere, a scope file never named) and left the baseline for a re-run; inspect, then drop |
| watch shift open | a watch's report and baseline — the shift is running or awaiting its morning check; `review-check`, triage, `review-drop` |
| awaiting triage | report only — `review-check` passed, triage is pending |
| stale marker | baseline only — the report was removed by hand; drop it |
