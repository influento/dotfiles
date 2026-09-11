# ts-gate

Gate for AI-written TypeScript: deterministic checks in a Stop hook plus a
judgment checklist in `.claude/rules/`, which workbench's wb-reviewer applies
in fresh context. Workbench is a separate tool; the touchpoints are below.

## Commands

| Command | Does |
|---|---|
| `bash ts-gate/install.sh <project>` | install; idempotent |
| `bash ts-gate/uninstall.sh <project>` | remove exactly what install added, per `ts-gate/.install.json` |
| `npm run gate:verify` | prove the install: seeded violation blocks a session, hook releases after the fix; one model call |
| `npm run gate:local` | branch since the default branch plus working tree, and the tests that diff reaches (`vitest --changed`); what the Stop hook runs |
| `npm run gate` | CI, default branch...HEAD, and the whole test suite |
| `npm run gate:full` | whole repo, whole suite |
| `npm run gate:fix` | eslint autofix |

## Install steps

Refuses outside git. Then: copy this dir → deps
by lockfile (`typescript` included), test plugin by runner (vitest also
gets the test step in the gate; jest the plugin only) → scripts →
`eslint.config.mjs` if none exists (else prints the block to merge; until it
is merged knip flags `ts-gate/eslint.gate.mjs` and two plugins unused) →
`rules/ts-*.md` to `.claude/rules/` → one `Stop` hook and the
`permissions.allow` rules (`npm ci`, `npm run gate:*`, `npm test`, and
`npx vitest` or `npx jest` by runner) in `.claude/settings.json` → `git config workbench.premerge "npm run gate"` if
unset (set to something else: printed, chain it by hand) → manifest
`ts-gate/.install.json`.

knip's `ignoreDependencies` starts empty; `stack add` appends every
dependency it installs, because a package lands before the code that imports
it. Effect itself is a stack package (`stack add effect`, in every TypeScript
project by `project-setup`); `ts-lean-code.md` names it because every project
has it, and the gate installs nothing of it.

The Stop hook runs `gate:local` and blocks on every stop while red, capped: the
same output three stops running gets one last block that says to park it, and
the next stop is allowed — a fight the model is not winning costs a full turn
per round. A failure that changes resets the count. What it feeds back is the
first 80 lines, `tsc --pretty false` and eslint through `ts-gate/eslint-line.mjs`
(one line per problem); CI keeps the readable formats. It exits in
milliseconds when no TypeScript changed. Re-running install replaces the hook
entry. `gate.sh --list` prints the files the checklist applies to, for the
worker and for wb-reviewer.

Workbench touchpoints, all on this side: the `premerge` key (its merge runs
the gate in the branch worktree; per clone, like every workbench key, so a
fresh clone sets it again or re-runs install), the allow rules (an unattended
worker is denied anything not listed), and `.worktrees/**` in the eslint
ignores (`eslint .` in the main checkout would lint every item worktree).
Workbench knows nothing of ts-gate.

## Project requirements

- `tsconfig.json`: `strict: true`, `noUncheckedIndexedAccess: true` and an `include`. Type-aware rules are the point; install warns when either flag is missing.
- Commit `.claude/settings.json`, `.claude/rules/`, `ts-gate/`. A worktree without them has no gate.
- Fresh checkout: `npm ci` before the first stop; `git config workbench.premerge "npm run gate"` if workbench merges from it.
- Keep tools out of `repos/` (the stack's read-only subtrees): tsconfig `include`. eslint and knip ignores are written by install; the gate's vitest calls exclude it themselves, a project's own `vitest` script should too.

## Severity

Rules whose fix deletes code: `error`. Rules whose fix adds code (size limits:
1000 lines/file, 100/function, 30 statements, 6 params, depth 4): `warn`.
`tsc --noEmit`, knip, dependency-cruiser: repo-wide, block. eslint: changed files.
The correctness block in `eslint.gate.mjs` (`no-floating-promises`,
`switch-exhaustiveness-check`, `no-unsafe-*`, `restrict-plus-operands`,
`no-misused-promises`, `await-thenable`) runs at the gate severity, so a
brownfield `warn` pass covers it; `gate({ correctness: false })` drops it.
Tests: `--local` runs what the diff reaches (`vitest run --changed
<merge-base>`, so a fixture-only change reruns nothing until a `.ts` file
moves too); CI and `gate:full` run the suite. `--passWithNoTests`, and
`repos/**` and `.worktrees/**` excluded on the command line.

## Brownfield

1. `gate({ tsconfigRootDir, severity: "warn" })` in `eslint.config.mjs`. Record the count.
2. Stop hook and PR CI lint changed files only at `error`.
3. `npm run gate:fix`, commit alone.
4. Ratchet the warning count in CI.
5. At zero: `severity: "error"`.

knip: first run's legitimate findings go into `ignore` / `ignoreDependencies`
in `ts-gate/knip.json`; that is the baseline. dependency-cruiser: fix cycles
before wiring, no allowlist.

## Architecture record

`ts-gate/.dependency-cruiser.cjs` `forbidden` rules are the architecture. Rule
changes are their own commit, never with the code that needed them. Runtime
wiring (DI container, dynamic `import()`, registries) is invisible to import
analysis: layer rules must also cover the file holding the registrations.
