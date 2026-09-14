# typescript/ (source tree)

TypeScript is assumed everywhere here; plain JS is not a goal. The gate and
the packages written against it live together, because neither is complete
without the other:

| Path                | What it is                                                                 |
| ------------------- | -------------------------------------------------------------------------- |
| `gate/`             | ts-gate, installed into a project as `ts-gate/`; its contract: `gate/CLAUDE.md` |
| `packages/`         | the TypeScript half of the stack registry, by section; the package format and the CLI: `../stack/CLAUDE.md` |
| `tests/registry.sh` | facts about the shipped packages, and their `eslint.mjs` files loaded by the real gate |

## How the gate and the packages depend on each other

stack → gate:
- `stack add` writes a package's dependencies into `ts-gate/knip.json`'s
  `ignoreDependencies` and a copied file into `ignore`, when that file
  exists; `rm` drops them. `update` writes them again, so a gate installed
  after the packages gets them from `stack update`.
- `effect`, `money` and `tailwind` ship an `eslint.mjs` written to the gate's
  loader contract (`gate/CLAUDE.md`, Rules): a function of `{ severity }`, an
  inline plugin, no core rule that takes options. effect's vitest block relies
  on install writing the runner block before the gate's spread.
- effect's `DEV_DEP` pins `vitest`, because the gate detects the runner from
  `package.json` only.
- `fixtures` exists because the gate refuses the network in tests.

gate → stack, naming no package:
- `eslint.gate.mjs` appends every `.claude/eslint/*.mjs`; `.claude/eslint/**`
  is in knip's `ignore`, and a change there runs the repo-wide tools.
- `repos/**` is in the knip, eslint and vitest ignores and the biome warning.

The gate goes into a project before the packages (`workshop-setup`, step 2
then 4): the knip lists must exist when `stack add` writes them. Effect is a
package (`stack add effect`, in every TypeScript project through
`workshop-setup`), not part of the gate.

## Sections

| Section    | Packages |
| ---------- | -------- |
| `presets`  | `fullstack` |
| `shared`   | `effect`, `money`, `fixtures` |
| `backend`  | `drizzle-postgres`, `drizzle-sqlite`, `drizzle-mysql`, `drizzle-libsql`, `duckdb`, `viem`, `solana-kit`, `jupiter` |
| `frontend` | `tanstack-start`, `atom-react`, `shadcn`, `tailwind` |

A package needs only its own section or `shared`; a preset any section
(`../stack/CLAUDE.md`, The registry). Backend and frontend never need each
other. Placement calls:
- `money` is shared: the UI shows amounts, and it is pure Schema with no
  dependency.
- `viem` and `solana-kit` are backend: their rules wrap them in a server
  service that signs with a key pair. Browser wallets would be a new
  frontend package, not a move.

## What enters the registry

The registry is the priority list: one pick per need, chosen once, the reason
in the conf's comment. Anything that touches control flow, errors, IO or data
is Effect-native, or wrapped once behind a service; UI,
styling and tooling are orthogonal and free (`shadcn`). That is what keeps a
second ORM, a second schema library or a second retry helper out of a
project: a worker that needs one finds the pick in `stack list`, not on npm.

| Need | Pick | Why |
|---|---|---|
| runtime, HTTP, RPC, Schema, CLI, retry, streams | `effect` (core and `effect/unstable/*`) | in the box |
| database | `drizzle-<dialect>`: `drizzle-postgres`, `drizzle-sqlite`, `drizzle-mysql`, `drizzle-libsql` (`drizzle-orm/effect-<dialect>` over `@effect/sql-<dialect>`) | native Effect v4 entries, the only ORM with them; one package per dialect because the dialect is the project's choice, not the registry's. Verified 2026-09-12: Postgres 17, SQLite on `node:sqlite`, libSQL on a file, MySQL 8. Not in the registry: `pglite` (tests), `d1`/`sqlite-do` (Cloudflare), `sqlite-bun`/`-wasm`/`-react-native` (not Node), `mssql`/`clickhouse` (no drizzle Effect entry) |
| client state | `atom-react` | first party; `AtomRpc` bridges to RPC |
| tracing, logs, metrics | in `effect` (`effect/unstable/observability`, OTLP out) | verified 2026-09-12; `@effect/opentelemetry` is the SDK bridge, not needed |
| auth | none | Better Auth dropped 2026-09-12 (no Effect API planned); a project that needs auth writes it over Drizzle and `HttpApiMiddleware` |
| framework | `tanstack-start` | Effect RPC from one file route; decided over Next.js 2026-09-12 |
| tests, AI, CLI | in `effect` (`@effect/vitest`, `@effect/ai-*`, `effect/unstable/cli`) | first party |
| money | `money` (no dep: `Schema.BigInt`, `Schema.BigDecimal`, `Schema.brand`) | the invariant prebuilt: branded units and kinds from `src/core/money.ts`, a rule, and `money/no-number` in its `eslint.mjs` (no `Number()`, `parseFloat`, `toFixed` on an amount). decimal.js, big.js, dinero are not added |
| test data | `fixtures` (no dep: `Schema`, `Effect`, `Stream` in effect, `node:fs`) | recorded responses in place of the network, which ts-gate refuses in tests: `Fixture.load` / `stream` / `record` from `src/core/fixture.ts`, a rule; msw, nock, polly are not added |
| EVM chains | `viem` | the one EVM client; ethers and web3.js are not added. Promise-based, wrapped once in a service |
| Solana | `solana-kit` (`@solana/kit`) | the current SDK, functions over values; `@solana/web3.js` 1.x is not added. Wrapped once |
| Solana swaps | `jupiter` (`@jup-ag/api`) | the aggregator's generated client over its Swap API; needs `solana-kit` to sign and send |
| analytical SQL, files | `duckdb` (`@duckdb/node-api`) | in-process over Parquet/CSV/JSON and a local file; not the app database (the SQL database reached through `drizzle-<dialect>`) |

`effect` and every `@effect/*` share one version; the pins across `effect`,
the `drizzle-*` packages and `atom-react` move in one commit. `drizzle-orm` is built against
one Effect version (`devDependencies.effect` of the release): check that its
`effect-core/errors.js` calls a `Schema` constructor the pinned Effect still
has before moving either pin.

## Two ways in, and the database

A project starts with one of two, by what it is, and names its database
(decided 2026-09-12; the `service` preset went the same day, when the
database stopped being Postgres by default):

| Project | Entry | Brings |
|---|---|---|
| CLI, library, worker, backend service | `stack add effect` | the runtime |
| app with a UI | `stack add fullstack` | effect + tanstack-start, atom-react, shadcn |
| anything that owns a database | `stack add drizzle-<dialect>` beside the entry | Drizzle on Effect for that dialect |

The packages stay separate units under the preset rather than one `effect`
package holding everything, because a CLI would then carry drizzle-kit and a
database driver it never imports, and a service that grows a UI later runs
`stack add tanstack-start atom-react`, not a reinstall. The database is never
inside a preset: the dialect is the project's, so `workshop-setup` asks the
entry and then the dialect (or none); a single package later (`stack add
drizzle-sqlite` in a CLI that grew a database) is the same command.

## Packages

| Path                            | What it is                                                                       |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `packages/shared/effect/`       | the runtime: subtree pinned to the release tag, `effect` + `@effect/platform-node`, `@effect/vitest` as dev dep, the always-on rule with the never-added table, `eslint.mjs`: `effect/tags` and @effect/vitest's test blocks for the vitest plugin |
| `packages/shared/money/`        | `NEEDS=effect`, no dep, a path-scoped rule, `files/src/core/money.ts` and `eslint.mjs` (`money/no-number`) |
| `packages/shared/fixtures/`     | `NEEDS=effect`, no dep, a path-scoped rule and `files/src/core/fixture.ts` (load, stream, record over `fixtures/`); the other half of the gate's network guard |
| `packages/backend/drizzle-{postgres,sqlite,mysql,libsql}/` | `NEEDS=effect`, a pinned dep, a rule; no subtree — the Effect monorepo already holds `@effect/*` sources. The four drizzle rules share one shape and differ in driver, table module and `drizzle.config.ts` dialect |
| `packages/backend/viem/`, `solana-kit/`, `jupiter/`, `duckdb/` | `NEEDS=effect` (`jupiter` also `solana-kit`), a pinned dep, a rule that wraps the Promise API once in a service; no subtree, no skill — none of the four repositories publishes one, and the docs are the types in `node_modules` (plus `viem.sh/llms.txt`) |
| `packages/frontend/atom-react/` | `NEEDS=effect`, a pinned dep, a rule; no subtree, as for drizzle |
| `packages/frontend/tanstack-start/` | `NEEDS="effect atom-react"`, no dep (its CLI scaffolds), `SETUP` printed, the RPC-route rule |
| `packages/frontend/shadcn/`     | public library: `NEEDS=tailwind`, the `shadcn` skill through skills.sh, a path-scoped rule, a setup command printed |
| `packages/frontend/tailwind/`   | `@shadcn/lint` as dev dep, a rule for the v4 facts the lint cannot see (CSS, renamed scales), and `eslint.mjs`: the lint's rules, which the gate appends. No skill: Tailwind Labs publishes none, the skills.sh ones are tutorials. Standalone, since the lint works without shadcn |
| `packages/presets/fullstack/`   | preset: `KIND=preset`, `NEEDS` only |

## Commands

Run from this directory (`common/claude-code/workshop/typescript/`):

- Lint: `shellcheck -x tests/registry.sh`
- Test: `bash tests/registry.sh`; with `TSGATE_REAL_PROJECT` set to a project
  with a real ts-gate install, it also runs the registry's `eslint.mjs` files
  through real eslint under the gate
- The gate's own lint and tests: `gate/CLAUDE.md`, Working here
