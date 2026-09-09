// Structure gate. Cycles and barrel chains from day one; layers once decided.
// This file IS the architecture record. Change it in its own commit, never
// alongside the code change that needed it.
module.exports = {
  forbidden: [
    { name: "no-circular", severity: "error", from: {}, to: { circular: true } },
    {
      name: "no-barrel-chain",
      severity: "error",
      comment: "index.ts importing index.ts loads the whole tree and breeds cycles",
      from: { path: "(^|/)index\\.tsx?$" },
      to: { path: "(^|/)index\\.tsx?$" },
    },
    // Layers. One rule per forbidden direction. Example for src/{domain,app,ui}:
    // { name: "domain-is-leaf", severity: "error",
    //   from: { path: "^src/domain" }, to: { path: "^src/(app|ui)" } },
    // { name: "app-below-ui", severity: "error",
    //   from: { path: "^src/app" }, to: { path: "^src/ui" } },
  ],
  options: {
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,
    doNotFollow: { path: "node_modules" },
    exclude: { path: "\\.(test|spec)\\.tsx?$" },
  },
};
