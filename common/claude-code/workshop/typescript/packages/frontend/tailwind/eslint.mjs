// Tailwind design-system lint (@shadcn/lint), appended to ts-gate's eslint
// config from .claude/eslint/tailwind.mjs. Classes are checked against the
// project's own Tailwind v4 theme and components: components.json when it
// exists, components/ui or src/components/ui otherwise. The setup is the
// package's adoption guide with every core rule at error; a project changes a
// rule after the gate's spread in eslint.config.mjs, never here (stack update
// re-copies this file). A class from outside Tailwind (a plugin, another
// stylesheet) is such a change: "shadcn/no-unknown-classes": ["error",
// { allow: ["prose"] }] there.
import { plugin as shadcn } from "@shadcn/lint";

export default [
  {
    files: ["**/*.ts", "**/*.tsx"],
    plugins: { shadcn },
    rules: {
      "shadcn/no-restyle": ["error", { allow: ["layout"] }],
      "shadcn/no-raw-colors": "error",
      "shadcn/no-arbitrary-values": ["error", { allow: ["layout"] }],
      "shadcn/no-inline-styles": "error",
      "shadcn/require-static-classes": "error",
      "shadcn/no-unknown-classes": "error",
    },
  },
  {
    // The components own their appearance and may need structural values
    // (ring-[3px]); colors and inline styles stay checked inside them.
    files: ["components/ui/**", "src/components/ui/**"],
    rules: {
      "shadcn/no-restyle": "off",
      "shadcn/no-arbitrary-values": "off",
      "shadcn/require-static-classes": "off",
    },
  },
];
