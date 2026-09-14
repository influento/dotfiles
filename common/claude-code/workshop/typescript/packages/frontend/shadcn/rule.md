---
paths: ["components.json", "components/ui/**", "src/components/ui/**"]
---

# shadcn/ui

Components are owned by the project once added, but they are added by the CLI,
never written by hand: `npx shadcn@latest add <component>`. Search before
assuming a name (`npx shadcn@latest search <term>`); view before editing
(`npx shadcn@latest view <component>`).

The `shadcn` skill has the CLI reference, theming (CSS variables, OKLCH, dark
mode), composition rules and the registry format. Invoke it for any of that
instead of recalling an older API — `components.json` decides the framework,
Tailwind version, base library and aliases, and the skill reads it.

`npx shadcn@latest init` is interactive and is the user's step, not yours.
Until `components.json` exists there is no shadcn in this project.
