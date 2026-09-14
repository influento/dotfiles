# shardx-scripts

The toolkit lives at `repos/shardx-scripts` — a `--squash` git subtree of the
private `shardx-scripts` repository. Refresh it with `stack update shardx-scripts`.

It is run, not imported: `node repos/shardx-scripts/<script>` from this
project, with the fleet passed by flag (`--url=`, `--workspaces=`,
`--per-workspace=`, `--app`) rather than by editing its `config.mjs`.

Always read first:

- `repos/shardx-scripts/README.md` — what each directory is, the two window
  postures, the grid, what `verify.mjs` checks and in which order.

Then only what the task needs:

- `repos/shardx-scripts/docs/FINDINGS.md` — the measurements behind every
  constant; the reason a number is what it is.
- `repos/shardx-scripts/docs/window-grid.md` — the tile, the traps, the cost.
- `repos/shardx-scripts/docs/launch-no-cdp.md` — a browser that reports no
  debug endpoint.

Two skills came with it: `setup-account` (profile → proxy → fonts → launch →
verify → wallet, one command) and `run-shardx-browser` (posture and placement
of one account's window). Invoke them for that work instead of reading the
scripts.

Non-negotiable: `launch/run.mjs`, never `launch/launch.mjs`. One request that
exits on the host IP has already linked the account to this machine.

Read-only. Never edit `repos/shardx-scripts`; a change it needs goes to the
repository itself and comes back with `stack update`.
