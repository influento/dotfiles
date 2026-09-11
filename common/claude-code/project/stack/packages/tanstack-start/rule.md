---
paths: ["src/routes/**", "src/router.tsx", "vite.config.ts"]
---

# TanStack Start

Scaffolded by `npx @tanstack/cli create`, never by hand; routes are files
under `src/routes/`.

Business logic is not in server functions. It is Effect RPC
(`effect/unstable/rpc`) served from one API route (`src/routes/api/rpc.ts`)
through Effect's web-handler adapter (`repos/effect/LLMS.md` has the v4 name;
v3's was `HttpApp.toWebHandler`), with the app's main layer provided there
once. The client is the derived RPC client behind `AtomRpc`. A loader or a
server function stays thin: it calls the RPC client and returns data — no
Drizzle, no `Auth`, no `Effect.gen` in a route file.

Components are plain React: values in, callbacks out, state from atoms
(`atom-react` rule). No TanStack Query.

Reference: https://tanstack.com/start/latest/docs/framework/react/overview;
a minimal Start + Effect RPC wiring is
https://github.com/kevin-courbet/tanstack-effect-example.
