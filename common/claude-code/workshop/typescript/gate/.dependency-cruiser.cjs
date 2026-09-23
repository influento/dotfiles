// Structure gate and the architecture record: change it in its own commit (rules/ts-gate.md).
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
    {
      name: "no-workbench",
      severity: "error",
      comment: "workbench/ holds a spike's prototypes, deleted when the spike is archived; what the code keeps is copied into it",
      from: {},
      to: { path: "^workbench/" },
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
