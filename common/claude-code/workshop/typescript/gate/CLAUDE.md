# ts-gate

Gate for AI-written TypeScript: deterministic checks in a Stop hook plus a
judgment checklist in `.claude/rules/`, which workbench's wb-reviewer applies
in fresh context. Workbench is a separate tool; the touchpoints are below.

## Commands

| Command | Does |
|---|---|
| `bash "$TS_GATE/install.sh" <project>` | install; idempotent. From the dotfiles source only (`workshop-setup` sets `$TS_GATE`); the project copy refuses to run |
| `bash "$TS_GATE/uninstall.sh" <project>` | remove exactly what install added, per the manifest `ts-gate/.install.json` |
| `npm run gate:verify` | prove the install: `eslint.config.mjs` spreads `gate()`, `gate:fix` twice is a no-op, a seeded violation blocks a session, the Stop hook releases after the fix; one model call |
| `npm run gate:local` | what the Stop hook runs: `tsc --noEmit`, knip and dependency-cruiser repo-wide; eslint and `biome format` on the changed files of the branch since the default branch plus the working tree; the tests the diff reaches (`vitest run --changed <merge-base>`, so a fixture-only change reruns nothing until a `.ts` file moves too) |
| `npm run gate` | CI, default branch...HEAD, and the whole test suite |
| `npm run gate:full` | whole repo, whole suite |
| `npm run gate:fix` | eslint autofix and `biome format --write`, both run even when the first leaves an error; exits with the worse status |
| `npm run test:live` | the live tier: `*.live.test.ts`, real network and real models, guard off (`ts-gate/vitest.live.mjs`); a person or a scheduled job runs it, never the gate; not in the allow rules |

`gate.sh --list` prints the files the checklist applies to, for the worker
and for wb-reviewer.

## What lands in a project

Install refuses outside git. Then:

- `ts-gate/`: `.dependency-cruiser.cjs`, `eslint.gate.mjs`, `eslint-line.mjs`, `knip.json`, `no-network.mjs`, `vitest.live.mjs`, `scripts/`. Not this file, the installers, `rules/`, `biome.template.json` or `tests/`. A re-run replaces all of it except the manifest, merging back `knip.json`'s `ignore`, `ignoreDependencies` and `entry`, and keeping `.dependency-cruiser.cjs` once it exists (diff it against the source by hand when the default rules move).
- Dependencies by lockfile (`typescript` included); the test plugin by runner (vitest also gets the test step in the gate; jest the plugin only).
- The npm scripts above.
- `eslint.config.mjs`, `biome.json`, `vitest.config.mjs` (vitest only), one ownership rule: written when absent, replaced on re-run unless edited since, a project's own left alone; for a project's own, install prints what to merge (Install output).
- `rules/ts-*.md` → `.claude/rules/`.
- One `Stop` hook and the `permissions.allow` rules in `.claude/settings.json`: `npm ci`, `npm run gate`, `gate:local`, `gate:full`, `gate:fix` (not `gate:verify`, which runs a model), `npm test`, and `npx vitest` or `npx jest` by runner. A re-run replaces the hook entry and keeps its `timeout` (600 for a new entry).
- `premerge=npm run gate` in `.claude/workshop.conf` (Touchpoints); `git config workbench.guards`, the regex naming `npm run gate|lint|build|typecheck` and `tsc`.
- The manifest, `ts-gate/.install.json`: what uninstall reads.

Biome is the formatter only: `biome.json` at the root, copied from
`biome.template.json` (why the name: `install.sh`), linter and assist off.
eslint carries no layout rule, so the two never disagree; `gate:verify`
proves it. A brownfield tree runs `gate:fix` once before the gate can be
green.

knip's `ignoreDependencies` starts empty; `stack add` appends every
dependency it installs, because a package lands before the code that imports
it.

## Rules

Rules whose fix deletes code: `error`. Rules whose fix adds code (size limits,
by default 1000 lines/file, 100/function, 30 statements, 6 params, depth 4):
`warn`. Those thresholds, cognitive complexity (15) and nesting (3) are
`lint.*` keys in `.claude/workshop.conf`, read when eslint loads the config
(the key table: `../../CLAUDE.md`). `gate({ severity })` sets the first tier;
the correctness block (`no-floating-promises`, `switch-exhaustiveness-check`,
`no-unsafe-*`, `restrict-plus-operands`, `no-misused-promises`,
`await-thenable`) runs at `severity` too, so a brownfield `warn` pass covers
it.

The gate knows no stack package. Every `.claude/eslint/*.mjs` (`stack add`
copies a package's `eslint.mjs` there) is imported when `eslint.gate.mjs`
loads; its default export, an array of flat config blocks or a function of
`{ tsconfigRootDir, severity }` returning one, is appended after the gate's
blocks in file-name order. Anything else fails the config load, naming the
file. Only a function follows `gate({ severity })`. A package file registers
its own inline plugin and never sets a core rule that takes options
(`no-restricted-syntax`): a later block replaces a rule's options, so two
files setting one would erase each other. Install writes the runner's block
before the spread, so a package's options for a runner rule (`effect`'s
test-block list) come after the recommended ones. A project overrides a
package rule after the spread, like a gate rule. `.claude/eslint/**` is in
knip's `ignore`, and a change there alone still runs the repo-wide tools at
stop.

Four rules are the gate's own, an inline plugin `gate` in `eslint.gate.mjs`,
so a project switches one off by name (`"gate/<rule>": "off"` after the
spread) without losing the rest: `no-double-assertion`, `no-module-mock`
(`vi.fn` and `spyOn` pass) and `no-unknown-signature` (`unknown` on a
parameter or a return) at `severity`;
`safety-comment` (every `as` except `as const` carries a `SAFETY:` comment)
at `warn`. `linterOptions.noInlineConfig` is on: an `eslint-disable` comment
has no effect and is itself reported. A rule that is wrong for a file changes
in `eslint.config.mjs`, in its own commit.

No test reaches the network (the contract: `rules/ts-gate.md`):
`vitest.config.mjs` loads `ts-gate/no-network.mjs`, which patches
`net.Socket.prototype.connect` and `fetch` to throw, naming the test and the
host, for any host off loopback (`loopback()` in `no-network.mjs`; a unix
socket path is local). The stack's `fixtures` package is the recording
loader. Only vitest loads the file; scripts and the app keep the network.
`*.live.test.ts` is excluded from `npm test`, the gate and the Stop hook.

## Stop hook

Runs `gate:local` and blocks on every stop while red, capped: the same output
`gate.repeat_cap` stops running (default 3) gets one last block that says to
park it, and the next stop is allowed — a fight the model is not winning
costs a full turn per round. A failure that changes resets the count. What it
feeds back is the first `gate.output_lines` lines (default 80), `tsc --pretty
false` and eslint through `ts-gate/eslint-line.mjs` (one line per problem); CI
keeps the readable formats. Both keys are read from `.claude/workshop.conf` on
every run, and the hook's messages state the number in effect.

The entry's `timeout` is 600 s as install writes it; a slower gate raises it
by hand in `.claude/settings.json`, and a re-install keeps it. Claude Code
kills the hook at `timeout` (probed 2.1.270); the rest of the command never
runs.

## Touchpoints

Workbench, all on this side:

- `premerge`: its merge runs the gate in the branch worktree. Install writes
  it only when `.claude/workshop.conf` has no such key, over the
  commented-out `# premerge=` line `workbench init` writes; uninstall removes
  it only while it is exactly `npm run gate`. A project that needs more at
  merge (a build, a migration check) points it at its own wrapper —
  `premerge=bash scripts/premerge.sh`, the script running `npm run gate` and
  its extras — rather than editing files under `ts-gate/`, which the next
  install overwrites.
- `guards`: this toolchain's words for a step that proves nothing; workbench
  holds only the rule.
- The allow rules: a session run without prompts is denied anything not
  listed.
- `.worktrees/**` in the eslint ignores: `eslint .` in the main checkout
  would lint every item worktree.
- The glossary: `eslint.gate.mjs` reads the `Never` column of
  `workbench/GLOSSARY.md` when the file exists and feeds it to `id-match`
  over what the code declares, as a substring: a worker writes `accountId`,
  `getAccount` and `ACCOUNT_ID` for a rejected `account`, never the bare
  word. Reads of a property another module owns (`stripe.account`)
  and strings are not checked; test names and prose stay with wb-reviewer's
  grep.

Stack: the `.claude/eslint/*.mjs` files the gate loads, and `knip.json`'s
lists stack appends to.

## Project requirements

- `tsconfig.json`: `strict: true`, `noUncheckedIndexedAccess: true` and an `include`. Type-aware rules are the point; install warns when either flag is missing.
- Commit `.claude/settings.json`, `.claude/rules/`, `.claude/workshop.conf`, `ts-gate/`, `eslint.config.mjs`, `biome.json`, `vitest.config.mjs`. A worktree without them has no gate.
- Fresh checkout: `npm ci` before the first stop.
- Keep tools out of `repos/` (the stack's read-only subtrees): tsconfig `include`. eslint and knip ignores are written by install; the gate's vitest calls exclude it themselves, a project's own `vitest` script should too.

## Greenfield

A project with nothing yet is scaffolded before install and committed as
`scaffold`. Install reads `package.json` and `tsconfig.json`, so the least it
needs is there first:

```
git init -b main && npm init -y && npm i -D vitest@5
```

- `vitest` in `package.json` before install: the runner is detected from
  there, and a peer-installed vitest (what `@effect/vitest` pulls in later)
  never lands in it — without it the gate runs no tests.
- No `typescript` in the scaffold: install pins `typescript@5` with the rest
  of its dependencies. An unpinned `typescript@latest` resolves to 7.x, which
  `typescript-eslint` refuses as a peer, and the install fails.
- `tsconfig.json`: `"strict": true`, `"noUncheckedIndexedAccess": true`,
  `"erasableSyntaxOnly": true`, `"noEmit": true`, `"module": "nodenext"`,
  `"allowImportingTsExtensions": true`, `"include": ["src"]`. Node runs the
  sources as they are, so relative imports are written with `.ts`
  (`from "./health.ts"`); nodenext otherwise demands `.js`, which node cannot
  resolve to a `.ts` file.
- `package.json`: `"engines": { "node": ">=<major>" }`, the node this runs
  on; `"scripts": { "start": "node src/index.ts" }`, the run model, decided
  here.
- `src/index.ts` with one export (knip's entry).
- `.gitignore`: `node_modules`.

## Install output

Every line install prints is acted on before anything else goes in:

| Line | Do |
|---|---|
| the eslint block, for a project with its own config | merge it; until then knip flags `ts-gate/eslint.gate.mjs` and two plugins unused |
| the vitest `setupFiles` and live-tier `exclude` lines, for a project's own vitest config | add them; without them tests may reach the network and `npm test` runs the live tier |
| `NOTE: premerge is '<x>' in .claude/workshop.conf` | make sure `<x>` runs `npm run gate` (a wrapper script, Touchpoints); never replace it with the bare gate |
| `WARNING` (tsconfig flags or `include`, `engines.node`, biome includes, knip entry, no runner) | fix first |

A project's own biome config is what the gate formats with. Then `npm run
gate:full`. Greenfield: green. Brownfield: the first run is the baseline, per
the section below. Commit `ts-gate: install` only when `gate:full` exits 0 or
every remaining red is a recorded warning.

## Brownfield

1. `gate({ tsconfigRootDir, severity: "warn" })` in `eslint.config.mjs`. Record the count.
2. Stop hook and PR CI lint changed files only at `error`.
3. `npm run gate:fix` (eslint fixes, then the whole tree formatted), commit alone.
4. Ratchet the warning count in CI.
5. At zero: `severity: "error"`.

knip: first run's legitimate findings go into `ignore` / `ignoreDependencies`
in `ts-gate/knip.json`; that is the baseline. dependency-cruiser: fix cycles
before wiring, no allowlist.

## Architecture record

`ts-gate/.dependency-cruiser.cjs` `forbidden` rules are the architecture, in
their own commit (`rules/ts-gate.md`). Runtime wiring (DI container, dynamic
`import()`, registries) is invisible to import analysis: layer rules must
also cover the file holding the registrations.

## Working here

Rejected tools: jscpd (`sonarjs/no-identical-functions` covers it), cloc
comment ratio, madge (dependency-cruiser covers it), api-extractor,
size-limit, type-coverage, Stryker, diff coverage. Each returns only with a
reason from a real codebase. No `agent` Stop hook: judgment review is
wb-reviewer's job.

- Decide tools, rules, severities in chat first; wire after agreement.
- Verify rule names and hook contracts against the installed package or the docs, never memory.
- After any change: `bash tests/ts-gate.sh` (npm, npx and every tool shimmed and logged; offline, seconds). Then the real thing: a throwaway project per Greenfield in a temp directory (`git init`, one commit), install, install again, `npm run gate:verify`, uninstall, diff against the pre-install tree.
