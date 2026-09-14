# TS gate

The Stop hook runs `npm run gate:local` (compile, lint, dead code, structure, the tests the change reaches) over the branch since the default branch plus the working tree, so committing does not clear it. It blocks until green; after repeated identical failures it says to park it and lets the next stop through.
Fresh clone or worktree: `npm ci` first; the gate refuses to run without `node_modules`.
Tests never reach the network: `ts-gate/no-network.mjs` throws on any connect or fetch off loopback, with no opt-out in a test. Record a real response once outside vitest and commit it as a fixture the test reads; fake a live service at the seam (a Layer, a stub `fetch`). Code that must be proven against the real endpoint or model gets a `*.live.test.ts` beside its unit test: `npm run test:live` runs it, the gate never does, and it is never the only test of that code.
`ts-gate/.dependency-cruiser.cjs` is the architecture record. Never edit it in the same change as the code that needed it; propose rule changes separately.
