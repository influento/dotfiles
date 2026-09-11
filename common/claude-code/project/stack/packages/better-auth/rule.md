---
paths: ["src/auth/**"]
---

# Better Auth, wrapped once

Better Auth has no Effect API. It lives in `src/auth/` and nowhere else:

- `src/auth/auth.ts`: the `betterAuth({...})` instance with
  `drizzleAdapter(db, { provider: "pg" })` over the stack's `Db`, and an
  `Auth` service whose methods call `auth.api.*` inside `Effect.tryPromise`
  with a tagged error. Nothing outside `src/auth/` imports `better-auth`.
- One `HttpApi` middleware that turns the request's session into a
  `CurrentUser` service; handlers ask for `CurrentUser`, never for a cookie.
- The auth routes are `auth.handler` (a fetch handler) mounted at
  `/api/auth/*` — in TanStack Start, `src/routes/api/auth/$.ts`.

Its tables: `npx auth@latest generate` writes the Drizzle schema for the
enabled plugins; that file is migrated by `drizzle-kit` like every other
table, never by Better Auth's own migrate.

Reference `repos/better-auth/docs/content/docs/`: `adapters/drizzle.mdx`,
`integrations/tanstack.mdx`, `plugins/` for 2FA, passkeys, organizations.
Read-only.
