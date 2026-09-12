// The live tier: `*.live.test.ts`, real network, real models, real cost.
// Not loaded by `npm test`, the gate or the Stop hook (their config excludes
// the pattern); `npm run test:live` runs it, by a person or a scheduled job
// with credentials, and its output is evidence in the item, pasted once. No
// setup file here: the network guard is off. A live test is never the only
// test of the code it covers.
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["**/*.live.test.{ts,tsx}"],
    exclude: ["**/node_modules/**", "repos/**", ".worktrees/**"],
  },
});
