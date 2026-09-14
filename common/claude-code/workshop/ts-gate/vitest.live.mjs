// The live tier (`npm run test:live`): no setup file, so the network guard is off.
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["**/*.live.test.{ts,tsx}"],
    exclude: ["**/node_modules/**", "repos/**", ".worktrees/**"],
  },
});
