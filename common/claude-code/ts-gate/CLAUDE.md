# ts-gate

Gate for AI-written TypeScript: deterministic checks in a Stop hook plus a
judgment checklist in `.claude/rules/`. Installed into a project as one unit,
alongside workbench, whose wb-reviewer applies the checklist in fresh context.
The two are separate tools; the `project-setup` skill installs both in order.

## Commands

| Command | Does |
|---|---|
| `bash ts-gate/install.sh <project>` | install; idempotent |
| `bash ts-gate/uninstall.sh <project>` | remove exactly what install added, per `ts-gate/.install.json`; leaves `effect` and `repos/effect` |
| `npm run gate:verify` | prove the install: seeded violation blocks a session, hook releases after the fix; one model call |
| `npm run gate:local` | branch since the default branch plus working tree; what the Stop hook runs |
| `npm run gate` | CI, default branch...HEAD |
| `npm run gate:full` | whole repo |
| `npm run gate:fix` | eslint autofix |

## Install steps

Refuses outside git, before the first commit, or (first run) on a dirty tree.
Then: effect subtree at `repos/effect` and `effect@rc` → copy this dir → deps
by lockfile (`typescript` included), test plugin by runner → scripts →
`eslint.config.mjs` if none exists (else prints the block to merge; until it
is merged knip flags `ts-gate/eslint.gate.mjs` and two plugins unused) →
`rules/ts-*.md` to `.claude/rules/` → one `Stop` hook and two
`permissions.allow` rules (`npm ci`, `npm run gate:*`) in
`.claude/settings.json` → `git config workbench.premerge "npm run gate"` if
unset (set to something else: printed, chain it by hand) → manifest
`ts-gate/.install.json`.

Run it before `workbench init`; commit between the two. `effect` is in knip's
`ignoreDependencies`: install adds it before any code imports it.

The Stop hook runs `gate:local` and blocks on every stop while red (Claude Code
ends the turn after 8). It exits in milliseconds when no TypeScript changed.
Re-running install replaces the entry and removes the agent hook of earlier
versions. `gate.sh --list` prints the files the checklist applies to, for the
worker and for wb-reviewer.

Workbench touchpoints, all on this side: the `premerge` key (its merge runs
the gate in the branch worktree; per clone, like every workbench key, so a
fresh clone sets it again or re-runs install), the allow rules (an unattended
worker is denied anything not listed), and `.worktrees/**` in the eslint
ignores (`eslint .` in the main checkout would lint every item worktree).
Workbench knows nothing of ts-gate.

## Project requirements

- `tsconfig.json`: `strict: true` and an `include`. Type-aware rules are the point.
- Commit `.claude/settings.json`, `.claude/rules/`, `ts-gate/`. A worktree without them has no gate.
- Fresh checkout: `npm ci` before the first stop; `git config workbench.premerge "npm run gate"` if workbench merges from it.
- Keep tools out of `repos/effect`: tsconfig `include`, `vitest run --dir src`. eslint and knip ignores are written by install.

## Severity

Rules whose fix deletes code: `error`. Rules whose fix adds code (size limits:
1000 lines/file, 100/function, 30 statements, 6 params, depth 4): `warn`.
`tsc --noEmit`, knip, dependency-cruiser: repo-wide, block. eslint: changed files.

## Brownfield

1. `gate({ tsconfigRootDir, severity: "warn" })` in `eslint.config.mjs`. Record the count.
2. Stop hook and PR CI lint changed files only at `error`.
3. `npm run gate:fix`, commit alone.
4. Ratchet the warning count in CI.
5. At zero: `severity: "error"`.

knip: first run's legitimate findings go into `ignore` / `ignoreDependencies`
in `ts-gate/knip.json`; that is the baseline. dependency-cruiser: fix cycles
before wiring, no allowlist. Effect migration of brownfield code: TODO.

## Architecture record

`ts-gate/.dependency-cruiser.cjs` `forbidden` rules are the architecture. Rule
changes are their own commit, never with the code that needed them. Runtime
wiring (DI container, dynamic `import()`, registries) is invisible to import
analysis: layer rules must also cover the file holding the registrations.

## Rejected

jscpd (`sonarjs/no-identical-functions` covers it), cloc comment ratio,
madge (dependency-cruiser covers it), api-extractor, size-limit,
type-coverage, Stryker, diff coverage. Each returns only with a reason from a
real codebase. Details in `~/dev/projects/code-metrics/research.md`.

An `agent` Stop hook applying `ts-lean-code.md` was built and measured: about
13 s and a model call per stop, chat-only turns included, and redundant with
wb-reviewer. Removed 2026-09-03. Platform facts if it ever returns: its subagent runs in
don't-ask mode, where read-only git is auto-allowed but running a script needs
`permissions.allow` (`Bash(bash ts-gate/scripts/gate.sh --list)`), piped
commands are refused, and it reads the session transcript unless told not to.

## Working on ts-gate itself

- Decide tools, rules, severities in chat first; wire after agreement. Less code.
- Verify rule names and hook contracts against the installed package or the docs, never memory.
- After any change: install on `~/dev/projects/code-metrics/sample/` (own git repo, Effect v4 wallet tracker), commit there, `npm run gate:verify`.
- Smoke test for install/uninstall: install, install again, uninstall, diff against the pre-install tree.
