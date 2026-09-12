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
Under TanStack Start the first paint's data is the route loader's, not an
atom's (`tanstack-start` rule): query atoms are read only in components that
render after mount, and no atom is dehydrated for SSR.

API: `repos/effect/packages/atom/react/src/Hooks.ts` for the hooks;
`repos/effect/packages/effect/src/unstable/reactivity/` for `Atom`, `AtomRpc`,
`AtomHttpApi`, `AsyncResult`.
