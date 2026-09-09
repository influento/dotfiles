# project/ backlog

What is still to do on the tools themselves, one line each. Not project items:
workbench tracks projects, this tracks workbench and ts-gate.

## workbench

- turn caps: set `maxTurns:` on `wb-reviewer` and `wb-gate` at twice the p95 the first `workbench usage` prints; the worker already treats a partial return as three holds
- per-role tokens in `usage:`: sum each role's transcript (input, output, cache read, cache write) — the reviewer's and gate's at `SubagentStop`, the worker's at archive — into one field like `tok=worker:120k/8k reviewer:40k/3k gate:25k/2k`, so `workbench usage` prints each role's share of the item and the usage review can set each role's effort from its share (a gate at 6% of the item can afford high; a reviewer at 35% is the one to try at low). Verify first whether `SubagentStop` input carries the subagent's own transcript path or only the parent's. Same pass, same transcript: a cache lapse is a request whose cache-write tokens are near the whole context, and the gap since the previous request (transcript timestamps) says why — over an hour: the worker or the user was away, `lapse=gap`; under an hour and over five minutes: the 1h TTL was not in effect, overage, `lapse=ttl`. Count both per role on the line, so the usage review can tell a slow dialog from a plan state
- reviewer effort: try `effort: low` on `wb-reviewer` once a usage review has a baseline at `medium`; the usage line records the worker's effort only, so note the item range the change applies from

## ts-gate

- `gate.sh --local` now runs `tsc --pretty false` and `eslint --format unix`; run `npm run gate:verify` in a real project once, the sample repo was not on the machine that made the change
- Effect migration of brownfield code: not written
