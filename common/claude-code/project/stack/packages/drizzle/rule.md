---
paths: ["src/db/**", "drizzle.config.ts", "drizzle/**"]
---

# Drizzle on Effect

Drizzle is used only through its Effect entry: `drizzle-orm/effect-postgres`
over `@effect/sql-pg`; a query is `yield*`ed inside `Effect.gen`, never
awaited. The Promise entries (`drizzle-orm/node-postgres`,
`drizzle-orm/postgres-js`) and the `pg` driver are not installed:
`@effect/sql-pg` speaks the wire protocol itself.

Verified 2026-09-12 against Postgres 17 with the pins in `package.json`
(migrate, select, insert `returning`, spans out). The shape that worked:

| File | Holds |
|---|---|
| `src/db/schema.ts` | `pgTable(...)` tables, nothing else; imported by server code only |
| `src/db/db.ts` | `class Db extends Context.Service<Db, PgDrizzle.EffectPgDatabase>()("app/Db")` with `static layer = Layer.effect(Db, PgDrizzle.makeWithDefaults()).pipe(Layer.provide(PgClient.layerConfig({ url: Config.Redacted("DATABASE_URL") })))` |
| `src/db/migrate.ts` | `Effect.flatMap(Db, (db) => migrate(db, { migrationsFolder: "./drizzle" }))` from `drizzle-orm/effect-postgres/migrator`, provided `Db.layer`, run by `NodeRuntime.runMain`; `npm run migrate` |
| `drizzle.config.ts` | `defineConfig({ dialect: "postgresql", schema: "./src/db/schema.ts", out: "./drizzle", dbCredentials: { url: process.env.DATABASE_URL! } })` |

- Every module that queries takes `Db` from the environment
  (`const db = yield* Db`, then `db.select().from(todos)`); none builds a
  client. A query fails with `EffectDrizzleQueryError | SqlError`: map it to
  the caller's tagged error at the service, or `Effect.orDie` where the
  failure is a bug; never let it reach an RPC signature raw.
- Migrations: `drizzle-kit generate` writes `drizzle/<stamp>_<name>/migration.sql`;
  the app applies it through `src/db/migrate.ts`. `drizzle-kit migrate` is
  not used: it wants a Node driver (`pg`, `postgres`) that the stack does not
  have. Never `drizzle-kit push` against a database with data. The migration
  is committed with the schema change.
- The RPC contract's schemas are hand-written `Schema.Struct`s, not
  `createSelectSchema(table)` from `drizzle-orm/effect-schema`: the contract
  is imported by the browser, and the table import drags `pg-core` into the
  client bundle (measured: +44 KB). Drift between a row and the contract
  fails to compile where the handler returns the row.
- `Effect.withSpan("Todo.list")` on each handler; Drizzle adds
  `drizzle.operation` and `sql.execute` spans under it by itself.

API: the types under `node_modules/drizzle-orm/effect-postgres/` and
`node_modules/drizzle-orm/effect-core/`, then
https://orm.drizzle.team/docs/connect-effect-postgres.
