# Usage

What a worker session cost is recorded on its item at archive, as one line
after `commit:`:

```
usage: cost=1.23 effort=low calls=140 reviewer=35/2 gate=20/1 cache=91% misses=2 holds=1 claude=2.1.266 at=1757400000
```

| Field | What it is |
|---|---|
| `cost` | the worker session's cost at list price, in dollars, as Claude Code computes it — the reviewer and the gate ran inside that session, so it is the item's whole cost. On a subscription it is not a bill; it is the one figure that weighs every token class the way the plan does, and it compares item to item |
| `effort` | the highest effort the worker ran at — `workbench.workerEffort`, or `workbench.workerEffortOnHold` once a hold reopened it |
| `calls` | the worker's own tool calls |
| `reviewer` | the reviewer's tool calls, total/instances — `35/2` is two reviewers, 35 calls between them |
| `gate` | the same for the pre-merge gate |
| `cache` | the share of the session's input tokens read from cache; misses beside it are requests that re-read what the cache held |
| `holds` | pre-merge holds across the item's life; the item's `rounds:` line holds the dialog's shape |
| `claude` | the Claude Code version, since a version change rebuilds the cache and may change the figures |
| `at` | when it archived, epoch seconds; the order `workbench usage` sorts by |

The figures come from the status line, which receives the session's running
totals on every repaint, and from the tool-call hook; both write under the
shared git directory, and `archive` folds a worker's into its item and
deletes the working files. An item worked without a lead has no line.

`workbench usage [n]` tabulates the last n records with the medians and p95s,
then lists the sessions recording now. `workbench status` prints a `usage:`
line when a review is due — every ten records, or when an item in the last
five ran at twice the median cost, under 80% cache, or held twice — and is
silent otherwise. `/workbench-review usage` is the review, and opening it
resets the cadence.

## Levers

Every suggestion a usage review makes is one of these, set by the user. Each
names what it moves, so a finding maps to a lever and a lever to the figure
that shows whether it worked.

| Lever | Where | Moves | Reading |
|---|---|---|---|
| worker effort | `git config workbench.workerEffort low\|medium\|high` (low) | `cost`, `holds` | compare the `holds` and `cost` of items at one effort against items at another; three items each at least. Lower effort that holds more is not cheaper: a hold is another reviewer, gate and round of the worker |
| worker effort after a hold | `git config workbench.workerEffortOnHold medium\|high\|off` (medium) | `cost` of items with `holds` ≥ 1 | applies when the held item's worker is opened again, not to the running session, and that reopen is a fresh session — a resume at a new effort re-reads the whole history uncached, and the history is the reasoning that held. Items that held and then merged cheaply at the higher level are the pattern working; items that held at the higher level too are a criterion or design problem, not an effort one |
| reviewer and gate effort | `effort:` in the `wb-reviewer` and `wb-gate` agent definitions (medium), at their source in the dotfiles (a project copy is overwritten by `init`) | `reviewer` calls, dialog quality; `holds` | set on the agent so neither follows the worker's level: the verifier of a low-effort attempt must not run at the attempt's level. A reviewer whose findings the gate then repeats is under-reading; one whose calls exceed the worker's is over-reading. A gate lowered to the worker's level shows as merges the next item's work has to undo |
| reviewer and gate cache lifetime | `subagentPromptCacheTtl: "1h"` in the project's `.claude/settings.json`, or `experimental: cacheTtl: 1h` on the agent | `cache` on items whose dialog had long gaps | the reviewer waits while the worker fixes; a gap past the lifetime re-reads its whole context. Subagents get five minutes unless this is set |
| turn caps | `maxTurns:` on `wb-reviewer` and `wb-gate` | the tail | a ceiling, never a target: twice the p95 `workbench usage` prints. A reviewer or gate that returns partial counts as three holds — the worker parks it, never respawns |
| review rounds and holds | `ROUND_CAP` and `REVIEW_HOLDS` in the CLI | `reviewer` instances, `holds` | fixed by design; a finding here says the design costs more than it catches, and that is the user's call |
| workers at once | `git config workbench.maxWorkers` (5) | total spend per hour, not per item | items sharing a resource run one at a time regardless |
| what the worker loads | the project's `CLAUDE.md` length, `.claude/rules/` scoped by `paths:`, MCP servers the session connects | the cost floor of every request | `/context` in a worker window shows what sits in the prefix; instructions that only matter for one kind of file belong under `paths:` |

Not levers: the model — a worker on a cheaper model pays back in holds and
rounds, and the figures here cannot show it because the whole item reruns —
and the criterion, which is the item's, never the budget's.
