// The money invariant's escape hatches, appended to ts-gate's eslint config
// from .claude/eslint/money.mjs. Amounts are branded bigint or BigDecimal,
// never a number: the types stop a number from getting in, this stops one
// from being made on purpose. A project changes the rule after the gate's
// spread in eslint.config.mjs, never here (stack update re-copies this file).
const SELECTORS = [
  [
    "CallExpression[callee.name=/^(parseFloat|parseInt|Number)$/]",
    "money: no float or Number() conversion; decode through the wire Schema into a branded unit or BigDecimal (src/core/money.ts)",
  ],
  [
    "CallExpression[callee.property.name=/^(toNumber|toFixed)$/]",
    "money: format with BigDecimal.format or String(units), never through a number",
  ],
];
const noNumber = {
  meta: { type: "problem", docs: { description: "an amount is never converted to or formatted through a number" }, schema: [] },
  create: (ctx) => Object.fromEntries(SELECTORS.map(([selector, message]) => [selector, (node) => ctx.report({ node, message })])),
};

export default ({ severity }) => [
  {
    files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
    plugins: { money: { rules: { "no-number": noNumber } } },
    rules: { "money/no-number": severity },
  },
];
