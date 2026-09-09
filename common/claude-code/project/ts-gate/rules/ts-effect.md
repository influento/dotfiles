---
paths: ["**/*.{ts,tsx}"]
---

# Effect v4

Recalled API names are often v3 and no longer exist, so check before writing
rather than after it fails to compile.

The reference checkout lives at `repos/effect` — a `--squash` git subtree of
Effect-TS/effect `main`. Refresh it with:

    git subtree pull --prefix=repos/effect \
      https://github.com/Effect-TS/effect.git main --squash

Always read first:

- `repos/effect/LLMS.md` — API overview, 17 KB. Start here.

Then only what the task needs:

- `repos/effect/ai-docs/src/` — runnable examples per topic; `06_schedule/` for retry, repeat, Schedule composition.
- `repos/effect/MIGRATION.md` and `repos/effect/migration/` — where a name you expected went, if one is missing.

Unsure how an API behaves? Read that ONE module:
`repos/effect/packages/effect/src/<M>.ts` and
`repos/effect/packages/effect/test/<M>.test.ts`. Never read the tree broadly —
it is 451 source files.

Read-only. Never edit `repos/effect`, never import from it — the dependency is
`node_modules/effect`, the same rc as `package.json` pins.
