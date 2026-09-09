# Statuses

The five statuses an item carries, abandoning, and what each gate asks of
them. Item classes, fields, IDs and `find`: [items.md](items.md).

`status:` is the first field of every item. An optional `milestone: <slug>`
line may follow it — see [milestones.md](milestones.md).

| Status | Merged? | Archived? | Means |
|---|---|---|---|
| `open` | not yet | no | in flight |
| `awaiting — <trigger>` | yes | never as-is | everything verifiable was verified; the criterion needs an event you can name a time for. When it fires, re-state as `open`, record the evidence, archive |
| `unreproduced` | n/a | yes | a bug that could not be reproduced |
| `unverified — <trigger>` | yes | yes | as `awaiting`, but no bound can be named for the trigger |
| `abandoned — <why>` | never | yes | the user dropped it after it was opened — started or not; the why is the record |

The trigger or the why goes in the status line rather than in prose so that
these can be found by grep.
Those five are the whole set — `archive` refuses any other word, `done`
included. An
archived item keeps `open`; under `archive/` that reads as verified and
shipped.

A status entered with nobody to decide it carries ` (agent)` at the end —
`awaiting — the next deploy (agent)` — and a line in `DECISIONS.md` points
at it. The user confirms by deleting the
marker. `merge` and `archive` read the status the same with or without it;
only `status` and grep tell them apart.

**Merged and still `open`, with no branch, is not a state.** It is an item
that merged with its criterion unrun and did not say so. `workbench status`
lists it under its own heading; the repair is to archive it or give it the
status it needed at merge.

A research item is `open` until archived and nothing else: the other statuses
qualify a claim about code, and research makes none.

`unreproduced` and `unverified` are the only two archive bypasses for a claim
about code. Both archive a statement of what was *not* proved, which is what
keeps the archive honest — an item archived as if it were verified would spend
the one guarantee the whole system provides. `abandoned` is the third and
makes no claim at all: it records a decision.

### Abandoning

Work the user drops after it was opened is archived as `abandoned — <why>`,
whether the item was started or not; deleting the file is the one exit that
leaves nothing greppable, and `workbench find` on the paths it named is how
the next person learns it was tried. One path for both cases, `commit: none`.
A started item's branch is retired by `archive`; half-built work on it is
dropped only with `--discard`, which names each file. Shipped work is not
abandoned — with its trailer on the default branch the item merged, and
`archive` refuses the status. Research never takes it: a research item ends
by spawning or dropping its concepts. Abandoning is the user's decision;
unattended, the agent parks it with `workbench call` and does other work —
`abandoned — … (agent)` is refused at the archive like any provisional
status.

### What each gate asks

This is the one place the status rules live; the other references link here.

| Gate | Asks | Passes with |
|---|---|---|
| merge (`workbench merge`) | has everything that *can* be verified now been verified? — the pre-merge review's question; the command checks that a review passed on the branch's last commit, and that the item is `open` with a fenced block under Evidence or carries `awaiting` / `unverified` with a trigger | `open` with evidence, or `awaiting` / `unverified` chosen at pre-merge — by the user, or by the agent with ` (agent)` when nobody is there |
| archive (`workbench archive`) | has the criterion been satisfied? — the command checks that a fenced block sits under Evidence itself, that the status is one of the five, and that no heading outside the template is present; not what the evidence shows | `open` with evidence recorded; `unreproduced`, `unverified` and `abandoned` without |
| archive, research | has every concept reached a terminal state that names something real, and is the Outcome written? | `open`, no evidence block; the branch retired, `--discard` if it carried prototypes |

Research never passes the merge gate: there is nothing to ship, and what it
decided is spawned as items that pass it themselves.

