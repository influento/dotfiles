# project/ backlog

What is still to do on the tools themselves, one line each. Not project items:
workbench tracks projects, this tracks workbench and ts-gate.

## workbench

- turn caps: set `maxTurns:` on `wb-reviewer` and `wb-gate` at twice the p95 the first `workbench usage` prints; the worker already treats a partial return as three holds
- reviewer effort: try `effort: low` on `wb-reviewer` once a usage review has a baseline at `medium`; the usage line records the worker's effort only, so note the item range the change applies from

## ts-gate

- `gate.sh --local` now runs `tsc --pretty false` and `eslint --format unix`; run `npm run gate:verify` in a real project once, the sample repo was not on the machine that made the change
- Effect migration of brownfield code: not written
