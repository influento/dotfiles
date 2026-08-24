# Reviews

A review is a deliberate sweep that produces a report. It is not part of
finishing an item, and it is not tracked work — it is how work gets found.

Run one with `/workbench-review <reason> ["scope"]`, which forks so the sweep's
reading stays out of the main context. Quote a scope with spaces — the skill
takes it as one argument, and an unquoted second word is dropped.
`workbench review <reason> [scope]` alone just opens the report file.

## How the sweep is held to its contract

The fork's tool set is `Read`, `Glob`, `Grep`, `Bash`, `Write` — no `Edit`, no
subagents, no web. That removes the convenient ways to change a file, nothing
more: `Bash` must stay so the sweep can build, test and grep, and it can write
through a redirect. The real gate is `workbench review-check`, run in the
invoking context on the returned path.

The report is opened, and the tree's state recorded, by a preprocessed block in
the skill — before the fork's first turn. So the baseline predates anything the
sweep can do, and the check is two-sided by construction: a clean-tree check
would not do, since mid-item the tree is normally dirty and the sweep's edits
would be indistinguishable from the user's own. It compares content, not just
`git status`, because an already-modified file keeps the same status line when
it is modified again. The only permitted delta is the report appearing.

**What the check does not cover.** A sweep that reads nothing and reports
confidently produces the same clean result as a genuinely clean scope. That is
held by the sweep's instructions, not by the check — treat a pass as "wrote
only its report", never as "did the work honestly".

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
review runs -> report written -> triaged jointly -> items created -> report deleted
```

Reports are never archived. Once triaged, everything worth keeping is in an
item, and the report is redundant.

Because the report file is created before the sweep runs, a sweep that errors
or is aborted leaves an empty skeleton behind. A same-day collision gets a
numbered suffix rather than an error, so orphans do not stop the next sweep —
`workbench status` lists everything still in `workbench/reviews/`, and anything
there is either waiting for triage or an orphan to delete.

## What pre-merge review covers

- the criterion is genuinely satisfied by the evidence recorded
- the root cause is stated, for a bug
- documentation: written where it should not have been, or a discovered fact
  left out of the item that found it
- tests, if any, stay within what the criterion describes
- the item's prose and the commit subject use the glossary's words
- whether anything left unverified could in fact be verified now, by
  synthesising the event — `awaiting` and `unverified` are the user's call, not
  the agent's

The two most often missed: a discovered fact left out of the item whose work
found it, and a test that reaches past what the criterion describes.
