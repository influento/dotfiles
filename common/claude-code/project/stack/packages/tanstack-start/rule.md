---
paths: ["src/routes/**", "src/router.tsx", "src/start.ts", "src/rpc/**", "src/server/**", "vite.config.ts"]
---

# TanStack Start

Scaffolded by `npx @tanstack/cli create`, never by hand; routes are files
under `src/routes/`. A `--blank` scaffold has no `src/start.ts`; add it
(`export const startInstance = createStart(() => ({}))`), because nothing
else imports `@tanstack/react-start`, and without that import the `server`
option on `createFileRoute` does not typecheck.

Verified on Start 1.168 + Effect 4.0.0-rc.115 (2026-09-12): the six files
below compile, build with import protection on, serve SSR, and mutate,
with the `drizzle-postgres` rule's `Db` underneath against a real Postgres.

## The shape

| File | Holds |
|---|---|
| `src/rpc/contract.ts` | `RpcGroup.make(Rpc.make(...))` and the schemas: client-safe, imported by both sides |
| `src/server/live.ts` | `Group.toLayer(...)` handlers over the app's services (`Drizzle`, `Auth`, ...) |
| `src/server/runtime.server.ts` | `memoMap = Layer.makeMemoMapUnsafe()`, `AppLive = Handlers.pipe(Layer.provide(Db.layer), Layer.provideMerge(Observability))`, `ManagedRuntime.make(AppLive, { memoMap })`, and `rpcInProcess(f)` = `RpcTest.makeClient(Group, { flatten: true })` run in it |
| `src/routes/api/rpc.ts` | `HttpRouter.toWebHandler(RpcServer.layerHttp({ group, path: "/api/rpc", protocol: "http" }).pipe(Layer.provide(AppLive), Layer.provide(RpcSerialization.layerNdjson)), { memoMap })`; `server: { handlers: { POST: ({ request }) => handler(request) } }` |
| `src/rpc/client.ts` | `Protocol = RpcClient.layerProtocolHttp({ url: "/api/rpc" })` over `FetchHttpClient.layer` + `layerNdjson`; `class Client extends AtomRpc.Service<Client>()("Client", { group, protocol: Protocol })`; `rpcBrowser(f)` = `ManagedRuntime` over `Layer.effect(Client, RpcClient.make(Group, { flatten: true }))` |
| `src/rpc/call.ts` | `rpc = createIsomorphicFn().server(rpcInProcess).client(rpcBrowser)`, typed `<A, E>(f: (client: Client["Service"]) => Effect<A, E>) => Promise<A>` |

One memo map is the point of `runtime.server.ts`: the API route's handler
and the SSR in-process client build `AppLive` once between them, so there is
one pool, one tracer, one of everything. The relative `/api/rpc` works in
the browser because Effect's `Url.make` resolves against `location`; on the
server there is no `location`, which is why SSR goes in-process and never
over HTTP.

## Where data comes from

- **First paint: the route loader.** `loader: () => rpc((c) => c("listTodos", undefined))`,
  read with `Route.useLoaderData()`. Start runs it in-process on SSR, over
  HTTP on client navigation, and dehydrates the result itself.
- **Mutations: atoms.** `useAtomSet(Client.mutation("addTodo"), { mode: "promise" })`,
  then `useRouter().invalidate()` to re-run the loaders.
- **Client-only reads: atoms.** `useAtomValue(Client.query(tag, payload))` in
  a component that first renders after mount. Never in an SSR-rendered
  component: on the server the query fails (no `location`) and the failure
  is rendered into the HTML.
- **No atom hydration.** `HydrationBoundary` and `Hydration.dehydrate` exist,
  but need a per-request registry and atoms already read in loaders, at
  which point the loader is the data and the atom is a copy. No TanStack
  Query, no `effect-query`: loaders are Start's cache.

Business logic is not in server functions, loaders or route files: no
Drizzle, no `Auth`, no `Effect.gen` there. A loader calls `rpc`, a route
file exports `Route`. `HttpApi` is not used for the app's own client; it
enters only when a third party needs the API (OpenAPI), beside the RPC route.

Reference: https://tanstack.com/start/latest/docs/framework/react/overview,
`repos/effect/packages/effect/src/unstable/rpc/RpcServer.ts` (`layerHttp`,
`toHttpEffect`), `.../rpc/RpcTest.ts` (`makeClient`),
`.../http/HttpRouter.ts` (`toWebHandler`),
`.../reactivity/AtomRpc.ts` (`Service`, `query`, `mutation`).
