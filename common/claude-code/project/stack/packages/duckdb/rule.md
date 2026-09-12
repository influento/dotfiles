---
paths: ["src/duck/**"]
---

# DuckDB: @duckdb/node-api

DuckDB is for analytics over files and local data (Parquet, CSV, JSON,
`read_parquet(...)`, a `.duckdb` file); the app's database is drizzle over
Postgres and DuckDB never replaces it. The client is `@duckdb/node-api`, not
the older `duckdb` package: `DuckDBInstance`, `DuckDBConnection`, `run`,
`runAndReadAll`, `stream`, prepared statements, appenders. Check a name in
`node_modules/@duckdb/node-api/README.md` before writing it.

One service, `src/duck/duck.ts`; nothing else imports `@duckdb/node-api`
except for its value types (`DuckDBValue`, `DuckDBTimestampValue`).

| Piece | How |
|---|---|
| instance | `DuckDBInstance.fromCache(path, options)` once, in `Layer.scoped`, `Effect.acquireRelease` with `instance.closeSync()`; `fromCache`, not `create`, so two layers in one process never open the same file twice |
| connection | `instance.connect()` per unit of work, released with `closeSync()` in `Effect.acquireRelease`, so a connection is never shared across fibers |
| query | `connection.runAndReadAll(sql, values)` then `getRowObjects()` / `getColumnsObject()` (`getRowObjectsJS()` for plain JS values); `run` for statements with no result; `connection.stream(sql)` then `fetchChunk()` in a loop (or `runAndReadUntil` / `readUntil` on a reader) for a result that does not fit memory, exposed as a `Stream` |
| params | always bound, never interpolated into the SQL: `$name` with `{ name: value }` as the second argument of `run`/`stream`, or `$1` with `prepare` and `bindInteger(1, v)`; a `DuckDBPreparedStatement` when the same statement runs in a loop |
| bulk load | an appender (`connection.createAppender(table)`, `closeSync()` flushes) or `read_*` straight from the file; never row-by-row inserts |
| values | `bigint` for `BIGINT`/`HUGEINT`, `DuckDBTimestampValue` etc. for temporal types; convert at the service boundary with a `Schema` decode, never `Number(bigint)` inside |
| errors | `Effect.tryPromise` with one tagged `DuckError`; the message from DuckDB is the cause |

API: `node_modules/@duckdb/node-api/README.md` (examples first, "Ways to
run SQL" and "Ways to get result data" tables at the end), then
https://duckdb.org/docs/stable/clients/node_neo/overview.
