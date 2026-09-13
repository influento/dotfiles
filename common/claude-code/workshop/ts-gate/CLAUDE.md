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
| `npm run gate:local` | what the Stop hook runs: `tsc --noEmit`, knip and dependency-cruiser repo-wide; eslint and `biome format` on the changed files of the branch since the default branch plus the working tree; the tests the diff reaches (`vitest run --changed <merge-base>`, so a fixture-only change reruns nothing until a `.ts` file moves too). `--passWithNoTests`, `repos/**` and `.worktrees/**` excluded on the command line |
| `npm run gate` | CI, default branch...HEAD, and the whole test suite |
| `npm run gate:full` | whole repo, whole suite |
| `npm run gate:fix` | eslint autofix and `biome format --write`, both run even when the first leaves an error; exits with the worse status |
| `npm run test:live` | the live tier: `*.live.test.ts`, real network and real models, guard off (`ts-gate/vitest.live.mjs`: the live pattern, no setup file); a person or a scheduled job runs it, never the gate; not in the allow rules |

`gate.sh --list` prints the files the checklist applies to, for the worker
and for wb-reviewer.

## What lands in a project

Install refuses outside git. Then:

- `ts-gate/`: `.dependency-cruiser.cjs`, `eslint.gate.mjs`, `eslint-line.mjs`, `knip.json`, `no-network.mjs`, `vitest.live.mjs`, `scripts/`. Not this file, the installers, `rules/`, `biome.template.json` or `tests/`. A re-run replaces all of it except the manifest, merging back `knip.json`'s `ignore`, `ignoreDependencies` and `entry`, and keeping `.dependency-cruiser.cjs` once it exists (diff it against the source by hand when the default rules move).
- Dependencies by lockfile (`typescript` included); the test plugin by runner (vitest also gets the test step in the gate; jest the plugin only).
- The npm scripts above.
- `eslint.config.mjs`, `biome.json`, `vitest.config.mjs` (vitest only), one ownership rule: written when absent, replaced on re-run unless edited since, a project's own left alone. For a project's own, install prints what to merge: the eslint block (until merged, knip flags `ts-gate/eslint.gate.mjs` and two plugins unused), the `setupFiles` and live-tier `exclude` lines for vitest; a project's own biome config is what the gate formats with.
- `rules/ts-*.md` → `.claude/rules/`.
- One `Stop` hook and the `permissions.allow` rules in `.claude/settings.json`: `npm ci`, `npm run gate`, `gate:local`, `gate:full`, `gate:fix` (not `gate:verify`, which runs a model), `npm test`, and `npx vitest` or `npx jest` by runner. A re-run replaces the hook entry.
- `git config workbench.premerge "npm run gate"` if unset (set to something else: printed, chain it by hand) and `workbench.guards`, the regex naming `npm run gate|lint|build|typecheck` and `tsc`.
- The manifest, `ts-gate/.install.json`: what uninstall reads.

Biome is the formatter only: `biome.json` at the root, copied from
`biome.template.json` (why the name: `install.sh`), linter and assist off,
`.ts`/`.tsx`, spaces. eslint carries no layout rule, so the two never
disagree; `gate:verify` proves it. A brownfield tree runs `gate:fix` once
before the gate can be green.

knip's `ignoreDependencies` starts empty; `stack add` appends every
dependency it installs, because a package lands before the code that imports
it.

## Rules

Rules whose fix deletes code: `error`. Rules whose fix adds code (size limits:
1000 lines/file, 100/function, 30 statements, 6 params, depth 4): `warn`.
`gate({ severity })` sets the first tier; the correctness block
(`no-floating-promises`, `switch-exhaustiveness-check`, `no-unsafe-*`,
`restrict-plus-operands`, `no-misused-promises`, `await-thenable`) runs at
`severity` too, so a brownfield `warn` pass covers it.

Two `no-restricted-syntax` selectors are the gate's own: the double assertion
through `unknown`, and `vi.mock` / `jest.mock` / `doMock` /
`unstable_mockModule` (module mocking; `vi.fn` and `spyOn` pass). The second
moves ts-lean-code's mocking row from reviewer judgment into the Stop hook.
The money block (`no-restricted-syntax`, the calls in `moneyEscapes`) is on
when `.claude/stack.conf` has a `money|` row — `stack add money` — and off
otherwise; `gate({ money: true })` forces it. The Effect idiom rule
`gate/effect-tags` is on when `.claude/stack.conf` lists `effect`;
`gate({ effect: true })` forces it. Those two reads of `.claude/stack.conf`
are the gate's only knowledge of stack.

Three rules are the gate's own, an inline plugin `gate` in `eslint.gate.mjs`
(what each matches is written above its selectors), so a project switches one
off by name (`"gate/<rule>": "off"` after the spread) without losing the
rest: `effect-tags` at `severity`; `no-unknown-signature` (`unknown` on a
parameter or a return; `cause` and the subject of a type predicate excepted)
at `severity`; `safety-comment` (every `as` except `as const` carries a
`SAFETY:` comment on the assertion or the statement holding it) at `warn`.
Ported from anti-slop and measured 2026-09-13, three `claude -p --effort low`
workers per cell on a task that tempts the pattern, rule off in the base
branch of the before cell, a reviewer in both cells and a fixer in the before
cell:

| Rule | Before: leaked / reviewer caught / fixer removed | After: leaked | Turns before → after |
|---|---|---|---|
| `effect-tags` ("handle NotFound and Timeout differently") | 3/3 wrote `e._tag === "NotFound" ? … : …` / 0/3 / 0/3 | 0/3, rule fired 1–4 times per session | 46, 32, 28 → 46, 32, 32 |
| `no-unknown-signature` ("a queue message, shape not guaranteed") | 3/3 wrote `message: unknown` / 0/3 / 0/3 | 0/3: two wrote `message: Schema.Json`, one wrote an inline disable (now impossible, below) | 36, 25, 33 → 33, 52, 44 |
| `safety-comment` ("brand the id as UserId") | 1/3 cast `id as UserId` without a reason / 1/1 / 1/1 | 0/3 unjustified; the one `as` written carried a real invariant | 53, 52, 34 → 46, 29, 35 |

The first two catch what the review round misses outright, at zero to about
ten extra worker turns; the third is cheap and the reviewer catches the cast
anyway, so it stays a warning. A JSON-body task did not tempt `unknown` at
all (6/6 wrote `body: string` over `Schema.fromJsonString`), so the rule is a
backstop for the payload whose type nobody named.
`linterOptions.noInlineConfig` is on: an `eslint-disable` comment has no
effect and is itself reported. A rule that is wrong for a file changes in
`eslint.config.mjs`, in its own commit.

No test reaches the network: `vitest.config.mjs` loads
`ts-gate/no-network.mjs`, which patches `net.Socket.prototype.connect` (the
one door: `net`, `http`, `tls`, undici's `fetch` and `WebSocket`) and
`fetch` to throw, naming the test and the host, for any host but loopback
(`localhost`, `127.*`, `::1`; a unix socket path is local). No opt-out inside
a test: a test that needs a live endpoint is a recording, run once outside
vitest (a script, the CLI), its response committed as a fixture (the stack's
`fixtures` package is the loader). Only vitest loads the file; scripts and
the app keep the network. The exception is a tier, not a flag:
`*.live.test.ts` is excluded from `npm test`, the gate and the Stop hook, and
`npm run test:live` runs it for real.

## Stop hook

Runs `gate:local` and blocks on every stop while red, capped: the same output
three stops running gets one last block that says to park it, and the next
stop is allowed — a fight the model is not winning costs a full turn per
round. A failure that changes resets the count. What it feeds back is the
first 80 lines, `tsc --pretty false` and eslint through
`ts-gate/eslint-line.mjs` (one line per problem); CI keeps the readable
formats. It exits in milliseconds when no TypeScript changed.

## Touchpoints

Workbench, all on this side: the `premerge` key (its merge runs the gate in
the branch worktree; per clone, like every workbench key, so a fresh clone
sets it again or re-runs install), the `guards` key (this toolchain's words
for a step that proves nothing; workbench holds only the rule), the allow
rules (a session run without prompts is denied anything not listed),
`.worktrees/**` in the eslint ignores (`eslint .` in the main checkout would
lint every item worktree), and the glossary: `eslint.gate.mjs` reads the
`Never` column of `workbench/GLOSSARY.md` when the file exists and feeds it to
`id-match` as a negative lookahead over what the code declares, so a rejected
word cannot become an identifier at the stop that writes it — `accountId`,
`getAccount` and `ACCOUNT_ID` for a rejected `account` (a worker writes
those, never the bare word: measured three of three, 2026-09-13). Reads of a
property another module owns (`stripe.account`) and strings are not checked;
test names and prose stay with wb-reviewer's grep. Workbench knows nothing of
ts-gate.

Stack: the two `.claude/stack.conf` reads above, and `knip.json`'s lists it
appends to. Effect is a stack package, not the gate's; `ts-lean-code.md`
names it because every project has it.

## Project requirements

- `tsconfig.json`: `strict: true`, `noUncheckedIndexedAccess: true` and an `include`. Type-aware rules are the point; install warns when either flag is missing.
- Commit `.claude/settings.json`, `.claude/rules/`, `ts-gate/`, `eslint.config.mjs`, `biome.json`, `vitest.config.mjs`. A worktree without them has no gate.
- Fresh checkout: `npm ci` before the first stop; `git config workbench.premerge "npm run gate"` if workbench merges from it.
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
| `NOTE: workbench.premerge is '<x>'` | chain, never replace: `git config workbench.premerge "<x> && npm run gate"` |
| `WARNING` (tsconfig flags or `include`, `engines.node`, biome includes, knip entry, no runner) | fix first |

Then `npm run gate:full`. Greenfield: green. Brownfield: the first run is the
baseline, per the section below. Commit `ts-gate: install` only when
`gate:full` exits 0 or every remaining red is a recorded warning.

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

- Decide tools, rules, severities in chat first; wire after agreement. Less code.
- Verify rule names and hook contracts against the installed package or the docs, never memory.
- After any change: `bash tests/ts-gate.sh` — a scratch project with npm, npx and every tool shimmed and logged, so it runs offline in seconds; covers install, re-install, the project-copy refusal, which tools the gate runs for a config-only change, the Stop hook's release, verify's `gate()` check, uninstall, what is and is not copied. Then the real thing: scaffold a throwaway TypeScript project in a temp directory (`git init`, `package.json`, strict `tsconfig.json`, one commit), install, install again, `npm run gate:verify`, uninstall, diff against the pre-install tree.
