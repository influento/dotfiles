---
paths: ["src/db/**", "drizzle.config.ts", "drizzle/**"]
---

# Drizzle on Effect

Drizzle is used only through its Effect entry: `drizzle-orm/effect-postgres`
over a `PgClient.layer(...)` from `@effect/sql-pg`; a query is `yield*`ed
inside `Effect.gen`, never awaited. The Promise entries
(`drizzle-orm/node-postgres`, `drizzle-orm/postgres-js`) and the `pg` driver
are not used: `@effect/sql-pg` speaks the wire protocol itself. The Drizzle
guide predates that and installs `pg` for its type parsers; add it only when
a query needs one, and say so in the commit.

- One `Db` service, `src/db/db.ts`, provides the Drizzle instance from
  `PgDrizzle.makeWithDefaults()`; every module that queries takes `Db` from
  the environment, none builds a client.
- Tables in `src/db/schema.ts`. `drizzle-orm/effect-schema` derives Effect
  `Schema` from a table; no hand-written duplicate of a row type.
- Migrations: `drizzle-kit generate`, then `drizzle-kit migrate`, config in
  `drizzle.config.ts` (`dialect: "postgresql"`, `out: "./drizzle"`). Never
  `drizzle-kit push` against a database with data. The migration is committed
  with the schema change.

API: the types under `node_modules/drizzle-orm/effect-postgres/` and
`node_modules/drizzle-orm/effect-core/` are the reference, then
https://orm.drizzle.team/docs/connect-effect-postgres.
