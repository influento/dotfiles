# stack (source tree)

The libraries, toolkits and tools a project chooses, one at a time, and the
way of working with each. Only `bin/stack` is deployed (→ `~/.local/bin/stack`);
the registry under `packages/` is read from this tree when a project runs
`stack add`, and what add copies is committed in the project so worktrees and
clones carry it.

No templates: a project's stack is whatever was added to it, and a preset
(`fullstack`) is only a list of packages — what it expands to is
recorded, the preset is not. No one shape: a private toolkit is a subtree
plus its own skills (`shardx-scripts`); a public library with a published
skill is that skill through skills.sh plus a short rule (`shadcn`); a plain
dependency is `DEP` and a rule. Every key is optional, the package is
whatever it needs.

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

## Layout

| Path                            | What it is                                                                       |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `bin/stack`                     | the CLI: `list`, `show`, `add`, `update` (per part: subtree pull, skills.sh update, re-copy), `rm`, `status` |
| `packages/effect/`              | the runtime: subtree pinned to the release tag, `effect` + `@effect/platform-node`, `@effect/vitest` as dev dep, the always-on rule with the never-added table |
| `packages/drizzle-{postgres,sqlite,mysql,libsql}/`, `atom-react/` | `NEEDS=effect`, a pinned dep, a rule; no subtree — the Effect monorepo already holds `@effect/*` sources. The four drizzle rules share one shape and differ in driver, table module and `drizzle.config.ts` dialect |
| `packages/viem/`, `solana-kit/`, `jupiter/`, `duckdb/` | `NEEDS=effect` (`jupiter` also `solana-kit`), a pinned dep, a rule that wraps the Promise API once in a service; no subtree, no skill — none of the four repositories publishes one, and the docs are the types in `node_modules` (plus `viem.sh/llms.txt`) |
| `packages/tanstack-start/`      | `NEEDS="effect atom-react"`, no dep (its CLI scaffolds), `SETUP` printed, the RPC-route rule |
| `packages/fullstack/`           | preset: `KIND=preset`, `NEEDS` only |
| `packages/shardx-scripts/`      | private toolkit: reference subtree, its two skills copied out of it, a rule       |
| `packages/shadcn/`              | public library: the `shadcn` skill through skills.sh, a path-scoped rule, a setup command printed |
| `packages/<name>/package.conf`  | `KEY=value`, read line by line, never sourced; keys below                         |
| `packages/<name>/rule.md`       | optional; → `.claude/rules/<name>.md` verbatim                                    |
| `packages/<name>/skills/<s>/`   | optional; → `.claude/skills/<s>/`, own-written or vendored from upstream          |
| `tests/stack.sh`                | end-to-end, in a temp project against a temp registry and a local bare "private" repo |

`package.conf` keys, every one optional but `NOTE`:

| Key                     | Meaning                                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------------------------- |
| `KIND`                  | `toolkit` (run as scripts), `lib` (imported), `cli`, `service`, `preset` (NEEDS only, expanded, not recorded); shown in `list` and the CLAUDE.md line |
| `NEEDS`                 | package names, space separated, added first (transitively; a cycle is refused). `rm` refuses a package another added one needs |
| `REFERENCE`             | a repository worth reading, as a `--squash` subtree at `repos/<name>`: `private:<repo>` → `<git config private.root>/<repo>.git`, or `git:<url>`. Only when the agent should read the source or its docs; most public libraries have none |
| `REF`                   | branch or tag for the subtree; default `main`. A pinned dependency pins its tag too (`effect@4.0.0-rc.115`) |
| `DEP`                   | package-manager specs, space separated, exact versions (`effect@4.0.0-rc.115`); installed with the runner the lockfile says |
| `DEV_DEP`               | the same, as dev dependencies (`-D`; bun `-d`)                                                            |
| `SKILLS_ADD`            | a skills.sh package (`shadcn/ui`): `npx skills add <pkg> --agent claude-code --skill <pick> -y --copy`, every prompt answered by flag; the CLI writes `.claude/skills/` and `skills-lock.json` |
| `SKILLS_PICK`           | which of that package's skills, comma separated; empty is every one (`--skill '*'`)                        |
| `SKILLS_FROM_REFERENCE` | a directory inside the subtree whose `<s>/SKILL.md` children are copied as skills after the subtree lands |
| `SETUP`                 | one command the user runs after add (`npx shadcn@latest init`); printed, never run, because it asks questions |
| `NOTE`                  | one line for the CLAUDE.md block: what it is and where to start                                           |

Skills reach a project three ways and `status` treats them differently: from
`packages/<name>/skills/` (compared with the registry), from the reference
subtree (compared with a fresh link rewrite), or through skills.sh (left to
its lockfile). `rm` sends skills.sh skills back through `npx skills remove` so
the lockfile stays true.

`update` is per part, each with the mechanism it has: `git subtree pull` for
a reference, `npx skills update <names> -p -y` for skills.sh skills, a plain
re-copy for the rule and registry skills (those have no update of their own;
the registry is the source). The skills CLI's update ignores copy mode and
leaves `.agents/skills/<s>/` plus a symlink at `.claude/skills/<s>` (skills
1.x); `stack update` folds that back into a committed copy and removes
`.agents/`, so worktrees keep reading real files.

The private host never appears in this public repository: `private:` resolves
through `git config private.root`, which `setup-github` sets in
`~/.gitconfig.local`.

## What `add` puts in a project

Per package, what it `NEEDS` first, each part only when the conf names it: a
`--squash` subtree at `repos/<name>` as a read-only reference (needs HEAD and
a clean tree), the dependencies (and, when `ts-gate/knip.json` exists, their
names in `ignoreDependencies`, because the package lands before the code that
imports it), the rule, the skills as committed copies, one line in the block
between `<!-- stack:start -->` and `<!-- stack:end -->` in CLAUDE.md, and a
row in `.claude/stack.conf` (`name|subtree|rule|skills`) that `status`,
`update` and `rm` read back. A preset writes no row and no line: `stack add
fullstack` records `effect`, `atom-react`, `tanstack-start`, `shadcn`, in that order (`stack show
fullstack` prints it).

A skill copied out of the subtree had relative links that climbed to its
repository root (`../../../docs/x.md` from `.claude/skills/<s>/`); in the
project it sits at the same depth, so the same climb now steps into
`repos/<name>/` — `copy_skill` rewrites exactly that prefix and nothing else.
`status` compares a copy against a fresh rewrite, so a differing copy is one
bit, as for workbench's agents: it does not say which side moved.

Rule or skill for a package: a rule (`.claude/rules/`, loaded by path or
always) for how the project works with the thing; a skill only for a task
("set up an account", "add a migration"), because skill descriptions compete
as triggers and a rule does not. Most public libraries need only the subtree
and a short rule saying what to read first; conventions grow into the rule as
they are learned.

## Commands

Run from this directory (`common/claude-code/workshop/stack/`):

- Lint: `shellcheck -x bin/stack tests/stack.sh`
- Test: `bash tests/stack.sh`
- Real check: in a scratch git project with one commit, `stack add
  shardx-scripts`, then `stack status` and read the rewritten links in
  `.claude/skills/*/SKILL.md`

## Adding a package

1. `mkdir packages/<name>`, write `package.conf` (at least `KIND` and `NOTE`).
   First the "What enters the registry" test: is it the one pick for its
   need, and Effect-native or wrapped once? The reason goes in the comment.
   `NEEDS=effect` for anything that imports it; `DEP` at an exact version.
2. If it publishes a skill (its docs, or `npx skills add <owner/repo> --list`):
   `SKILLS_ADD`, and `SKILLS_PICK` when not every skill applies. Nothing else
   is needed for the docs then; the skill carries them.
3. If instead its repository is worth reading: `REFERENCE` and `REF`. Private
   ones as `private:<repo>`. If it ships skills under `.claude/skills`,
   `SKILLS_FROM_REFERENCE=.claude/skills` and write none here.
4. If it is imported: `DEP`. If its own installer asks questions: `SETUP`.
5. `rule.md`: what is non-negotiable, where to start. Short; path-scoped with
   `paths:` frontmatter when the thing has files of its own, always-on
   otherwise. Skills only for tasks.
6. `stack show <name>`, then a real `stack add` in a scratch project.
