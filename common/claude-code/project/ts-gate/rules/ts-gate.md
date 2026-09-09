# TS gate

The Stop hook runs `npm run gate:local` and blocks until it passes — the same failure three times over, it tells you to park it instead, and lets the next stop through. It covers the branch since the default branch plus the working tree, so committing does not clear it.
Fresh clone or worktree: `npm ci` first, the gate refuses to run without `node_modules`.
`ts-gate/.dependency-cruiser.cjs` is the architecture record. Never edit it in the same change as the code that needed it; propose rule changes separately.
