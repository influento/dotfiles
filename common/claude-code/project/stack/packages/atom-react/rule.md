---
paths: ["**/*.tsx"]
---

# Client state: @effect/atom-react

An `Atom` per piece of state; a component reads it with `useAtomValue`,
writes with `useAtomSet`, both with `useAtom`. A call to the server is an
atom built with `AtomRpc` over the derived RPC client (or `AtomHttpApi`), and
the component renders its `Result` (initial, success, failure) — it never
calls `Effect.runPromise`, never fetches in `useEffect`, never holds server
data in `useState`.

No second reactive system: no TanStack Query, no Zustand, no Redux, no SWR.
If a route loader ever needs Query for SSR hydration, that is a stack
decision (`effect-query` is the bridge), not a per-file one.

API: `repos/effect/packages/atom/react/src/Hooks.ts` for the hooks;
`repos/effect/packages/effect/src/unstable/reactivity/` for `Atom`, `AtomRpc`,
`AtomHttpApi`, `AsyncResult`.
