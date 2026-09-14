---
paths: ["**/*.css", "**/*.tsx"]
---

# Tailwind CSS v4

This project is on v4, configured in CSS. What you remember is mostly v3;
when unsure, the upgrade guide (tailwindcss.com/docs/upgrade-guide) decides.

- No `tailwind.config.js`. Tokens are `@theme` variables in the main
  stylesheet, the one with `@import "tailwindcss"` (`components.json` names
  it under `tailwind.css`). A JS config loads only through `@config`.
- `@import "tailwindcss"`, never `@tailwind base/components/utilities`.
  Custom utilities are `@utility`, not `@layer utilities`. `@apply` outside
  the main stylesheet needs `@reference "<main stylesheet>"` first.
- The scales moved one step, and the old names still compile: v3 `shadow-sm`
  and `shadow` are v4 `shadow-xs` and `shadow-sm`; the same for `rounded-*`,
  `blur-*` and `drop-shadow-*`. `ring` is 1px now (v3's is `ring-3`);
  `outline-none` is `outline-hidden`.
- `flex!`, not `!flex`. A variable is `bg-(--brand)`, not `bg-[--brand]`.
- A border is `currentColor` unless a color class says otherwise.
- A class name is a whole string in the source, never `bg-${tone}-500`: map
  each value to a complete class. Tailwind generates only what it finds
  written out.

`@shadcn/lint` runs in the gate on `.ts` and `.tsx`
(`.claude/eslint/tailwind.mjs`): theme colors only, no arbitrary values, no
inline styles, no appearance classes on a design-system component from
outside it, only classes this project's Tailwind generates. Its message names
the fix (a variant, a size, a token); take it. When nothing fits, add the
variant in the component file or the token in `@theme`, and say so in the
summary: a new token or variant is a design decision. A real class Tailwind
does not generate (a plugin's, another stylesheet's) goes in an `allow` entry
of `shadcn/no-unknown-classes`, set after the `gate()` spread in
`eslint.config.mjs`. It does not read CSS, so the lines above are the only
check there.
