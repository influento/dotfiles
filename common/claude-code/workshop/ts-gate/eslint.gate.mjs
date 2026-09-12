// Volume gate: rules that fire on "more code than there should be", plus
// the correctness subset of recommendedTypeChecked that catches a bug the
// compiler lets through. Cherry-picked on purpose; the rest of
// recommendedTypeChecked is not here, and mixing all of it in is what makes
// day one unsurvivable.
//
// Tiers:
//   error — the fix deletes or collapses code, or the code is wrong
//           (correctness; `correctness: false` drops that block).
//   warn  — size signals. Attention only; the fix would add code (splits,
//           parameter objects), so they never block.
//
// Usage in your eslint.config.mjs:
//   import gate from "./ts-gate/eslint.gate.mjs";
//   export default [ ...gate({ tsconfigRootDir: import.meta.dirname }) ];

import fs from "node:fs";
import { join } from "node:path";
import tseslint from "typescript-eslint";
import sonarjs from "eslint-plugin-sonarjs";

// The money invariant's escape hatches (stack package `money`: amounts are
// branded bigint or BigDecimal, never a number). The types stop a number
// from getting in; these stop one from being made on purpose.
const moneyEscapes = [
  {
    selector: "CallExpression[callee.name=/^(parseFloat|parseInt|Number)$/]",
    message: "money: no float or Number() conversion; decode through the wire Schema into a branded unit or BigDecimal (src/core/money.ts)",
  },
  {
    selector: "CallExpression[callee.property.name=/^(toNumber|toFixed)$/]",
    message: "money: format with BigDecimal.format or String(units), never through a number",
  },
];

// Whether `stack add money` is recorded in the project (.claude/stack.conf,
// one `name|…` row per package): the gate's only reading of the manifest.
const stackHas = (root, name) => {
  try {
    return fs.readFileSync(join(root, ".claude/stack.conf"), "utf8").split("\n").some((l) => l.startsWith(`${name}|`));
  } catch {
    return false;
  }
};

/**
 * @param {object}  opts
 * @param {string}  opts.tsconfigRootDir  directory holding your tsconfig.json
 * @param {"error"|"warn"} [opts.severity="error"]  use "warn" for the first rollout pass
 * @param {boolean} [opts.correctness=true]  the type-aware correctness block
 * @param {boolean} [opts.money]  the money escape-hatch block; default: on when `.claude/stack.conf` lists `money`
 * @param {string[]} [opts.files]
 */
export default function gate({
  tsconfigRootDir,
  severity = "error",
  correctness = true,
  money = stackHas(tsconfigRootDir, "money"),
  files = ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
}) {
  const E = severity;
  return [
    {
      files,
      plugins: { "@typescript-eslint": tseslint.plugin, sonarjs },
      languageOptions: {
        parser: tseslint.parser,
        parserOptions: { projectService: true, tsconfigRootDir },
      },
      rules: {
        // --- defensive padding (type-aware) -------------------------------
        // Highest-value rule here. Catches null-checks and `?.` on values the
        // type system already proves non-nullish. Note: it does NOT flag
        // `if (!id)` on `id: string` — "" is falsy, so that check is real.
        // Required-param guards are a skill concern, not a lint concern.
        "@typescript-eslint/no-unnecessary-condition": E,
        "@typescript-eslint/no-unnecessary-boolean-literal-compare": E,
        "@typescript-eslint/no-unnecessary-type-conversion": E,
        "@typescript-eslint/no-unnecessary-template-expression": E,
        "@typescript-eslint/prefer-optional-chain": E,
        "@typescript-eslint/prefer-nullish-coalescing": E,

        // --- over-specified types -----------------------------------------
        "@typescript-eslint/no-unnecessary-type-assertion": E,
        "@typescript-eslint/no-unnecessary-type-arguments": E,
        "@typescript-eslint/no-unnecessary-type-parameters": E,
        "@typescript-eslint/no-unnecessary-type-constraint": E,
        "@typescript-eslint/no-unnecessary-qualifier": E,
        "@typescript-eslint/no-inferrable-types": E,
        "@typescript-eslint/no-redundant-type-constituents": E,

        // --- type holes: ratchet down on legacy, zero on greenfield --------
        "@typescript-eslint/no-explicit-any": E,
        "@typescript-eslint/ban-ts-comment": E,
        "@typescript-eslint/consistent-type-assertions": [
          E,
          { assertionStyle: "as", objectLiteralTypeAssertions: "never" },
        ],
        // `x as unknown as Y` is a deliberate override — worse than `any`.
        "no-restricted-syntax": [
          E,
          {
            selector: 'TSAsExpression > TSAsExpression[typeAnnotation.type="TSUnknownKeyword"]',
            message: "Double assertion through unknown. Fix the type instead.",
          },
          ...(money ? moneyEscapes : []),
        ],

        // --- ceremony with no effect --------------------------------------
        "@typescript-eslint/no-useless-default-assignment": E,
        "@typescript-eslint/no-useless-empty-export": E,
        "@typescript-eslint/no-unnecessary-parameter-property-assignment": E,
        "@typescript-eslint/no-useless-constructor": E,
        "no-useless-constructor": "off", // the TS-aware rule above covers it
        "no-useless-catch": E,
        "no-useless-return": E,
        "no-useless-rename": E,
        "no-else-return": E,
        "no-lonely-if": E,
        "no-empty": [E, { allowEmptyCatch: false }],
        "no-empty-function": "off",
        "@typescript-eslint/no-empty-function": E,
        "no-unused-vars": "off",
        "@typescript-eslint/no-unused-vars": E,

        // --- the same code, twice -----------------------------------------
        // The single best "wrote the helper again instead of finding it" gate.
        "sonarjs/no-identical-functions": [E, 3],
        "sonarjs/no-identical-expressions": E,

        // --- shapes that should have collapsed ----------------------------
        "sonarjs/prefer-immediate-return": E,
        "sonarjs/prefer-single-boolean-return": E,
        "sonarjs/no-redundant-boolean": E,
        "sonarjs/no-redundant-jump": E,
        "sonarjs/no-collapsible-if": E,
        "sonarjs/no-gratuitous-expressions": E,
        "sonarjs/no-unused-collection": E,
        "sonarjs/no-dead-store": E,

        // --- hand-rolled stdlib -------------------------------------------
        // The loop or helper already exists as a method. Fix deletes code.
        "@typescript-eslint/prefer-includes": E,
        "@typescript-eslint/prefer-find": E,
        "@typescript-eslint/prefer-for-of": E,
        "@typescript-eslint/prefer-string-starts-ends-with": E,
        "prefer-object-has-own": E,
        "prefer-object-spread": E,
        "prefer-spread": E,
        "prefer-rest-params": E,

        // --- correctness (type-aware): wrong, not merely too much ---------
        // A promise nobody awaits, a switch a new union member falls out of,
        // `any` flowing through, string + number. Greenfield has no reason
        // to wait for these; brownfield ratchets them with the rest.
        ...(correctness
          ? {
              "@typescript-eslint/no-floating-promises": E,
              "@typescript-eslint/no-misused-promises": E,
              "@typescript-eslint/await-thenable": E,
              "@typescript-eslint/switch-exhaustiveness-check": E,
              "@typescript-eslint/restrict-plus-operands": E,
              "@typescript-eslint/no-unsafe-argument": E,
              "@typescript-eslint/no-unsafe-assignment": E,
              "@typescript-eslint/no-unsafe-call": E,
              "@typescript-eslint/no-unsafe-member-access": E,
              "@typescript-eslint/no-unsafe-return": E,
            }
          : {}),

        // --- the one hard shape rule --------------------------------------
        "sonarjs/cognitive-complexity": [E, 15],
        "sonarjs/no-nested-functions": [E, { threshold: 3 }],

        // --- size signals: warn only, never block ---------------------------
        "max-lines": ["warn", { max: 1000, skipBlankLines: true, skipComments: true }],
        "max-lines-per-function": ["warn", { max: 100, skipBlankLines: true, skipComments: true }],
        "max-statements": ["warn", 30],
        "max-params": ["warn", 6],
        "max-depth": ["warn", 4],
      },
    },
    {
      // Tests legitimately repeat themselves and run long.
      files: ["**/*.{test,spec}.{ts,tsx}", "**/__tests__/**/*.{ts,tsx}"],
      rules: {
        "sonarjs/no-identical-functions": "off",
        "max-lines": "off",
        "max-lines-per-function": "off",
        "max-statements": "off",
      },
    },
  ];
}
