---
paths: ["src/db/**", "drizzle.config.ts", "drizzle/**"]
---

# Drizzle on Effect (SQLite)

Drizzle is used only through its Effect entry: `drizzle-orm/effect-sqlite-node`
over `@effect/sql-sqlite-node` (one package per dialect; this project runs on SQLite); a query is `yield*`ed inside `Effect.gen`, never
awaited. The Promise entries (`drizzle-orm/better-sqlite3`, `drizzle-orm/libsql`) and
their drivers are not installed: `@effect/sql-sqlite-node` uses `node:sqlite`,
built into Node.

Verified 2026-09-12 on Node 26 with the pins in `package.json` (generate,
migrate, insert `returning`, select). The shape that worked:

| File | Holds |
|---|---|
| `src/db/schema.ts` | `sqliteTable(...)` tables from `drizzle-orm/sqlite-core`, nothing else; imported by server code only |
| `src/db/db.ts` | `class Db extends Context.Service<Db, SqliteDrizzle.EffectSQLiteNodeDatabase>()("app/Db")` with `static layer = Layer.effect(Db, SqliteDrizzle.makeWithDefaults()).pipe(Layer.provide(SqliteClient.layerConfig({ filename: Config.String("DATABASE_FILE") })))` |
| `src/db/migrate.ts` | `Effect.flatMap(Db, (db) => migrate(db, { migrationsFolder: "./drizzle" }))` from `drizzle-orm/effect-sqlite-node/migrator`, provided `Db.layer`, run by `NodeRuntime.runMain`; `npm run migrate` |
| `drizzle.config.ts` | `defineConfig({ dialect: "sqlite", schema: "./src/db/schema.ts", out: "./drizzle", dbCredentials: { url: process.env.DATABASE_FILE! } })` |

- Every module that queries takes `Db` from the environment
  (`const db = yield* Db`, then `db.select().from(todos)`); none builds a
  client. A query fails with `EffectDrizzleQueryError | SqlError`: map it to
  the caller's tagged error at the service, or `Effect.orDie` where the
  failure is a bug; never let it reach an RPC signature raw.
- Migrations: `drizzle-kit generate` writes `drizzle/<stamp>_<name>/migration.sql`;
  the app applies it through `src/db/migrate.ts`. `drizzle-kit migrate` is
  not used: it wants its own driver that the stack does not have. Never `drizzle-kit push` against a database with data. The migration
  is committed with the schema change.
- The RPC contract's schemas are hand-written `Schema.Struct`s, not
  `createSelectSchema(table)` from `drizzle-orm/effect-schema`: the contract
  is imported by the browser, and the table import drags `drizzle-orm/sqlite-core` into the
  client bundle. Drift between a row and the contract
  fails to compile where the handler returns the row.
- The database is one file, `DATABASE_FILE`, per environment; `node:sqlite`
  is synchronous, so a query blocks the event loop for its duration and a
  long scan belongs in a worker or in DuckDB, not here. Tests use
  `filename: ":memory:"` in a test layer and run the migrations into it.
- `Effect.withSpan("Todo.list")` on each handler; Drizzle adds its own
  spans under it by itself.

API: the types under `node_modules/drizzle-orm/effect-sqlite-node/` and
`node_modules/drizzle-orm/effect-core/`, then
https://orm.drizzle.team/docs/connect-effect-sqlite-node.
