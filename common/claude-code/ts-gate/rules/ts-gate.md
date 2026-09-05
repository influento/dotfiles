# TS gate

Run `npm run gate:local` before declaring work done. The Stop hook runs it too and blocks until it passes; the judgment checks in `ts-lean-code.md` are yours to apply, no hook runs them. It covers the branch since the default branch plus the working tree, so committing does not clear it.
Fresh clone or worktree: `npm ci` first, the gate refuses to run without `node_modules`.
`ts-gate/.dependency-cruiser.cjs` is the architecture record. Never edit it in the same change as the code that needed it; propose rule changes separately.
