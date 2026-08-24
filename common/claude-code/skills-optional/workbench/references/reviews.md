# Reviews

A review is a deliberate sweep that produces a report. It is not part of
finishing an item, and it is not tracked work — it is how work gets found.

Run one with `/workbench-review <reason> [scope]`, which forks so the sweep's
reading stays out of the main context. `workbench review <reason> [scope]` alone
just opens the report file.

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
