# TS gate

The Stop hook runs `npm run gate:local` (compile, lint, dead code, structure, and the tests the change reaches) and blocks until it passes — the same failure three times over, it tells you to park it instead, and lets the next stop through. It covers the branch since the default branch plus the working tree, so committing does not clear it.
Fresh clone or worktree: `npm ci` first, the gate refuses to run without `node_modules`.
Tests never reach the network: `ts-gate/no-network.mjs` throws on any connect or fetch to a host other than loopback, and there is no opt-out in a test. A response from a real endpoint is recorded once outside vitest (a script, the CLI) and committed as a fixture the test reads; a dependency on a live service is faked at the seam (a Layer, a stub `fetch`). A test may listen on 127.0.0.1 and talk to itself.
`ts-gate/.dependency-cruiser.cjs` is the architecture record. Never edit it in the same change as the code that needed it; propose rule changes separately.
