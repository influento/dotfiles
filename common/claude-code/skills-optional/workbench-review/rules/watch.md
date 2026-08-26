# Watch

One tick of a shift. The contract is `workbench/watches/<slug>.md` — read it
first, every tick; it is the whole authority for what may change the running
system. Then read the report's tail: the shift so far lives there, not in you.

## The tick

1. Run every check under **Healthy when**.
2. All green → update the one liveness line (`checked: N ticks, last HH:MM`)
   in place with `sed -i` — the only edit that ever rewrites a line of the
   report — and return. Nothing else is written on a green tick.
3. Failed → **capture before recovering**: the failing check's output, the
   log tail, process and socket state, whatever the failure names. A restart
   destroys the evidence; the evidence is the point.
4. Recover with **Recovery** step 1, re-check; the next step only if still
   failed. Nothing outside that list changes the running system in order to
   bring it back.
5. Same signature as an earlier entry → count it on that entry (`3×`), do not
   narrate it again.
6. Investigate. This is free: read anything, poke the running app, send it
   requests, write helper scripts and captures under the scratch directory the
   skeleton names. Every action that changes the app's state — a request that
   writes, a cleared queue, a killed process — goes in the timeline with its
   output. Nothing tracked in the repository changes, ever.
7. Append the entry: `HH:MM  seen → did → outcome`, command and output, the
   signature, and a hypothesis **labelled as a hypothesis**. `workbench find`
   on the paths the failure names, once.
8. **Escalate** as the contract says — typically the same signature three
   times in one shift: stop recovering, mark the entry `ESCALATED`, notify as
   stated, return.

## What the report is never given

A `Write`. The tool is in the sweep's set for the other reasons, and
`review-check` tolerates changes during a watch, so nothing but this line
stops a rewrite — which drops what earlier ticks recorded. Append through
Bash; `sed -i` touches the liveness line alone.

## What a shift never does

It never fixes. Not a bounds check, not a config line, not with a green test,
not at 4am. A fix is an item with a criterion and a merge the user saw; the
shift's job is to hand over that item ready-made, with the evidence already
captured.

## Findings

Below the timeline, one per distinct signature or observation, with the
evidence lines they rest on and a suggested fix if one is obvious. Morning
triage turns them into items; the timeline's captures become the item's
*What was seen* and *How to reproduce*.
