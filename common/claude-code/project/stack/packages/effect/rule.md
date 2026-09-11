---
paths: ["**/*.{ts,tsx}"]
---

# Effect v4

Recalled API names are often v3 and no longer exist, so check before writing
rather than after it fails to compile.

The reference checkout lives at `repos/effect` — a `--squash` git subtree of
Effect-TS/effect at the tag `package.json` pins. `effect` and every
`@effect/*` package share one version number: bumped together in the stack
registry, never one at a time in a project; `stack update effect` moves the
subtree with them.

Always read first:

- `repos/effect/LLMS.md` — API overview, 17 KB. Start here.

Then only what the task needs:

- `repos/effect/ai-docs/src/` — runnable examples per topic; `06_schedule/` for retry, repeat, Schedule composition.
- `repos/effect/MIGRATION.md` and `repos/effect/migration/` — where a name you expected went, if one is missing.
- `repos/effect/packages/<p>/` for `@effect/<p>`: `platform/node`, `sql/pg`, `atom/react`, `opentelemetry`, `vitest`, `ai`.

Unsure how an API behaves? Read that one module:
`repos/effect/packages/effect/src/<M>.ts` and
`repos/effect/packages/effect/test/<M>.test.ts`. Never read the tree broadly —
it is hundreds of source files.

Read-only. Never edit `repos/effect`, never import from it — the dependency is
`node_modules/effect`, the same version `package.json` pins.

## In the box, so never added

| Need | Effect | Not added |
|---|---|---|
| validation, parsing, codecs | `Schema` | zod, valibot, arktype, io-ts |
| retry, backoff, repeat, cron | `Schedule` | p-retry, async-retry, node-cron |
| HTTP client, server, typed API | `effect/unstable/http`, `effect/unstable/httpapi` | axios, node-fetch, ky, express, hono, fastify |
| RPC | `effect/unstable/rpc` | trpc, orpc |
| CLI | `effect/unstable/cli` | commander, yargs, oclif |
| DI, config, resources | `ServiceMap`, `Layer`, `Config`, `Scope` | inversify, tsyringe, dotenv |
| concurrency, queues, streams | `Fiber`, `Queue`, `Stream` | p-limit, p-queue, rxjs |
| cache, duration, logs, metrics | `Cache`, `Duration`, `Logger`, `Metric` | lru-cache, ms, pino, winston |
| tests of Effect code | `@effect/vitest` | |

Errors are in the signature: `Effect<A, E, R>` with tagged error classes in
`E` (`LLMS.md` names the v4 constructor), never `throw` past a boundary, never
`unknown` left in `E` where the cause is known. A library outside the stack
that returns Promises is wrapped once, in one service (`Effect.tryPromise`
with a tagged error), and nothing else imports it.
