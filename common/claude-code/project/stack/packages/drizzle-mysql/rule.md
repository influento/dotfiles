---
paths: ["src/db/**", "drizzle.config.ts", "drizzle/**"]
---

# Drizzle on Effect (MySQL)

Drizzle is used only through its Effect entry: `drizzle-orm/effect-mysql2`
over `@effect/sql-mysql2` (one package per dialect; this project runs on MySQL); a query is `yield*`ed inside `Effect.gen`, never
awaited. The Promise entry (`drizzle-orm/mysql2`) is not imported anywhere: `@effect/sql-mysql2`
owns the `mysql2` pool.

Verified 2026-09-12 against MySQL 8 with the pins in `package.json` (generate,
migrate, insert `$returningId`, select). The shape that worked:

| File | Holds |
|---|---|
| `src/db/schema.ts` | `mysqlTable(...)` tables from `drizzle-orm/mysql-core`, nothing else; imported by server code only |
| `src/db/db.ts` | `class Db extends Context.Service<Db, MysqlDrizzle.EffectMysql2Database>()("app/Db")` with `static layer = Layer.effect(Db, MysqlDrizzle.makeWithDefaults()).pipe(Layer.provide(MysqlClient.layerConfig({ url: Config.Redacted("DATABASE_URL") })))` |
| `src/db/migrate.ts` | `Effect.flatMap(Db, (db) => migrate(db, { migrationsFolder: "./drizzle" }))` from `drizzle-orm/effect-mysql2/migrator`, provided `Db.layer`, run by `NodeRuntime.runMain`; `npm run migrate` |
| `drizzle.config.ts` | `defineConfig({ dialect: "mysql", schema: "./src/db/schema.ts", out: "./drizzle", dbCredentials: { url: process.env.DATABASE_URL! } })` |

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
  is imported by the browser, and the table import drags `drizzle-orm/mysql-core` into the
  client bundle. Drift between a row and the contract
  fails to compile where the handler returns the row.
- MySQL has no `RETURNING`: an insert ends in `.$returningId()` for the
  generated keys, then a select for the row.
- `Effect.withSpan("Todo.list")` on each handler; Drizzle adds its own
  spans under it by itself.

API: the types under `node_modules/drizzle-orm/effect-mysql2/` and
`node_modules/drizzle-orm/effect-core/`, then
https://orm.drizzle.team/docs/connect-effect-mysql2.
