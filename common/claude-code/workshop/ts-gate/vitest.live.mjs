// The live tier: `*.live.test.ts`, real network, real models, real cost.
// `npm run test:live` only, never `npm test`, the gate or the Stop hook; no
// setup file, so the network guard is off.
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["**/*.live.test.{ts,tsx}"],
    exclude: ["**/node_modules/**", "repos/**", ".worktrees/**"],
  },
});
