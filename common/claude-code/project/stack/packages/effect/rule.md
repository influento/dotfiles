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
| tracing, log and metric export | `effect/unstable/observability` (`Otlp`) | @effect/opentelemetry, @opentelemetry/*, Sentry SDK |
| tests of Effect code | `@effect/vitest` | |

Errors are in the signature: `Effect<A, E, R>` with tagged error classes in
`E` (`LLMS.md` names the v4 constructor), never `throw` past a boundary, never
`unknown` left in `E` where the cause is known. A library outside the stack
that returns Promises is wrapped once, in one service (`Effect.tryPromise`
with a tagged error), and nothing else imports it.

## Observability

One layer in the main layer, verified 2026-09-12 against an OTLP receiver:

```ts
const Observability = Otlp.layerFromConfig({ resource: { serviceName: "<app>" } }).pipe(
  Layer.provide(OtlpSerialization.layerJson),
  Layer.provide(FetchHttpClient.layer),
)
export const AppLive = Handlers.pipe(Layer.provide(Db.layer), Layer.provideMerge(Observability))
```

It reads `OTEL_EXPORTER_OTLP_ENDPOINT` (and `OTEL_SDK_DISABLED`); with no
endpoint set it exports nothing, so local runs need no receiver.
`Otlp.layerJson({ baseUrl })` is the same with the URL in code. Spans come
from `Effect.withSpan` and `Effect.fn("Name")` on service methods, logs from
`Effect.log*`, metrics from `Metric`; `@effect/sql-pg` and RPC add their own
spans underneath. `@effect/opentelemetry` is the bridge to the OpenTelemetry
SDK and its `@opentelemetry/*` peers; it is not needed to export OTLP and is
not installed.
