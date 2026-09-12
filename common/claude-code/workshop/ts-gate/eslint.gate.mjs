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

// The words a workbench glossary rejects (`| Use | Never | Because |` rows in
// workbench/GLOSSARY.md), so a rejected word cannot become an identifier. The
// pre-merge review greps the same column over prose and the diff; this catches
// the identifier at the stop that writes it. Substring match on what this
// code declares (`id-match`, a negative lookahead): a rejected `account`
// catches `accountId`, `getAccount` and `ACCOUNT_ID`, which is what a worker
// writes when the prompt says "account" — measured 2026-09-13: three of three
// workers wrote `accountId`, none wrote `account`, so an exact match never
// fires. A read of a property another module owns (`stripe.account`) is not
// ours to rename and is not checked. Workbench knows nothing of this file; a
// project without the glossary gets no rule.
function neverPattern(words) {
  const alts = new Set(
    words.flatMap((w) => [w.toLowerCase(), w[0].toUpperCase() + w.slice(1).toLowerCase(), w.toUpperCase()]),
  );
  return `^(?!.*(?:${[...alts].join("|")})).*$`;
}
function neverWords(file) {
  if (!fs.existsSync(file)) return [];
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const head = lines.findIndex((l) => /^\|\s*use\s*\|\s*never\s*\|/i.test(l));
  if (head < 0) return [];
  const words = new Set();
  for (const line of lines.slice(head + 2)) {
    if (!line.startsWith("|")) break;
    const cell = line.split("|")[2] ?? "";
    for (const w of cell.replaceAll("`", "").split(/[\s,]+/)) {
      if (/^[A-Za-z_$][\w$]*$/.test(w)) words.add(w);
    }
  }
  return [...words];
}

// The gate's own rules, as an inline plugin so a project can switch one off
// by name (`"gate/<rule>": "off"`) without losing the rest. Each is an
// esquery selector or a comment lookup; none needs type information.
const selectorRule = (description, entries) => ({
  meta: { type: "problem", docs: { description }, schema: [] },
  create: (ctx) =>
    Object.fromEntries(entries.map(([selector, message]) => [selector, (node) => ctx.report({ node, message })])),
});

// Effect idioms (stack package `effect`): a tagged value is branched on with
// Match or caught with catchTag, never by reading `_tag` by hand, and it is
// built by its constructor, never as a literal object. Names checked against
// repos/effect at 4.0.0-rc.115 (Match.tag/tags/tagsExhaustive/when/not,
// Effect.catchTag/catchTags, Data.taggedEnum's $match/$is,
// Predicate.isTagged, Schema.TaggedError/TaggedStruct, Data.TaggedError).
const TAG_EQ = 'BinaryExpression[operator=/^[!=]==?$/]';
const effectTags = selectorRule("Effect tagged values go through Match, catchTag and their constructors", [
  [
    `:matches(${TAG_EQ}[left.property.name="_tag"][right.type="Literal"], ${TAG_EQ}[right.property.name="_tag"][left.type="Literal"])`,
    "Effect: no `_tag ===`. In an error channel use Effect.catchTag / catchTags; on a value use Match.value(x).pipe(Match.tag(...), Match.exhaustive), Data.taggedEnum's $is/$match, or Predicate.isTagged for a reusable guard.",
  ],
  [
    'SwitchStatement[discriminant.property.name="_tag"]',
    "Effect: no `switch (x._tag)`. Use Match.value(x).pipe(Match.tagsExhaustive({...})) or the tagged enum's $match, which fail to compile when a member is missed.",
  ],
  [
    ':not(CallExpression[callee.object.name="Match"][callee.property.name=/^(when|not)$/]) > ObjectExpression > Property[key.name="_tag"][value.type="Literal"]',
    "Effect: no literal `_tag:` object. Construct it: `new NotFound({...})` for a Schema.TaggedError / Data.TaggedError, `.make` for a Schema.TaggedStruct, the variant constructor for Data.taggedEnum.",
  ],
  [
    'ConditionalExpression[test.type="BinaryExpression"][test.operator=/^[!=]==?$/][test.right.type="Literal"] > ConditionalExpression.alternate[test.type="BinaryExpression"][test.operator=/^[!=]==?$/][test.right.type="Literal"]',
    "Effect: a chain of literal ternaries is a match. Use Match.value(x).pipe(Match.when(\"a\", ...), Match.when(\"b\", ...), Match.orElse(...)).",
  ],
]);

// `unknown` on a signature leaves the input unparsed and the output unnamed:
// the caller then narrows with typeof and casts. Decode at the boundary
// (Schema.decodeUnknownSync for a value, Schema.fromJsonString for a body)
// and take or return the named type. `cause` and the subject of a type
// predicate are what unknown is for.
const FN = ":matches(:function, TSDeclareFunction, TSEmptyBodyFunctionExpression, TSFunctionType, TSMethodSignature, TSCallSignatureDeclaration)";
const PARAM = ':matches(Identifier.params[name!="cause"], ObjectPattern.params, ArrayPattern.params, AssignmentPattern.params, RestElement.params)';
const noUnknownSignature = selectorRule("unknown stays out of parameters and return types", [
  [
    `${FN}:not([returnType.typeAnnotation.type="TSTypePredicate"]) > ${PARAM} TSUnknownKeyword`,
    "`unknown` parameter: the input is still unparsed here. Decode it where it arrives (Schema.decodeUnknownSync, Schema.fromJsonString for a body) and accept the named type. `cause` and a type predicate's subject are the exceptions.",
  ],
  [
    `:matches(${FN} > TSTypeAnnotation.returnType > TSUnknownKeyword, ${FN} > TSTypeAnnotation.returnType > TSTypeReference[typeName.name=/^(Promise|PromiseLike)$/] > TSTypeParameterInstantiation > TSUnknownKeyword:first-child)`,
    "`unknown` return: the caller gets a value it must parse again. Decode inside and return the named type.",
  ],
]);

// Every `as` that survives no-unnecessary-type-assertion is a claim the
// compiler could not make. It carries its reason as a `SAFETY:` comment on
// the assertion or the statement holding it, so a reader (and the reviewer)
// sees the invariant, or else the cast goes: decode with Schema, narrow
// with a guard, fix the type. `as const` is not an assertion.
const SAFETY = /(?:^|[^\w])SAFETY\s*:\s*\S/;
const STATEMENTS = new Set(["ExpressionStatement", "VariableDeclaration", "ReturnStatement", "ThrowStatement", "PropertyDefinition"]);
const safetyComment = {
  meta: { type: "suggestion", docs: { description: "a type assertion states its invariant in a SAFETY: comment" }, schema: [] },
  create(ctx) {
    const src = ctx.sourceCode;
    const justifiedBefore = (owner, node) =>
      src.getCommentsBefore(owner).some((c) => c.range[1] <= node.range[0] && SAFETY.test(c.value));
    const justified = (node) => {
      for (let cur = node; cur && cur.type !== "Program"; cur = cur.parent) {
        if (justifiedBefore(cur, node)) return true;
        if (STATEMENTS.has(cur.type)) {
          const p = cur.parent;
          return p?.type === "ExportNamedDeclaration" && p.declaration === cur && justifiedBefore(p, node);
        }
      }
      return false;
    };
    return {
      'TSAsExpression:not([typeAnnotation.typeName.name="const"])'(node) {
        if (!justified(node)) {
          ctx.report({
            node,
            message:
              "Type assertion without a `SAFETY:` comment. State the invariant TypeScript cannot see, right before the assertion or its statement; or drop the cast: decode with Schema, narrow with a guard, fix the type.",
          });
        }
      },
    };
  },
};

const gatePlugin = { rules: { "effect-tags": effectTags, "no-unknown-signature": noUnknownSignature, "safety-comment": safetyComment } };

/**
 * @param {object}  opts
 * @param {string}  opts.tsconfigRootDir  directory holding your tsconfig.json
 * @param {"error"|"warn"} [opts.severity="error"]  use "warn" for the first rollout pass
 * @param {boolean} [opts.correctness=true]  the type-aware correctness block
 * @param {boolean} [opts.money]  the money escape-hatch block; default: on when `.claude/stack.conf` lists `money`
 * @param {boolean} [opts.effect]  the Effect idiom rule (`gate/effect-tags`); default: on when `.claude/stack.conf` lists `effect`
 * @param {string[]} [opts.files]
 * @param {string}  [opts.glossary="workbench/GLOSSARY.md"]  relative to tsconfigRootDir; its Never column feeds id-match
 */
export default function gate({
  tsconfigRootDir,
  severity = "error",
  correctness = true,
  money = stackHas(tsconfigRootDir, "money"),
  effect = stackHas(tsconfigRootDir, "effect"),
  files = ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
  glossary = "workbench/GLOSSARY.md",
}) {
  const E = severity;
  const never = neverWords(join(tsconfigRootDir, glossary));
  return [
    {
      files,
      plugins: { "@typescript-eslint": tseslint.plugin, sonarjs, gate: gatePlugin },
      // No inline escape: a `// eslint-disable` on a gate rule is a hole the
      // stop hook cannot see (measured 2026-09-13: one worker in three wrote
      // one on `gate/no-unknown-signature` rather than name the type). A rule
      // that is wrong for a file changes in eslint.config.mjs, in its own commit.
      linterOptions: { noInlineConfig: true, reportUnusedDisableDirectives: "error" },
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
        // `vi.mock` / `jest.mock` replaces a module wholesale: the test then
        // proves the mock, and the seam the code should have (a Layer, an
        // injected interface) never gets written. Spies and `vi.fn` stay:
        // they fake at a boundary the caller chose.
        "no-restricted-syntax": [
          E,
          {
            selector: 'TSAsExpression > TSAsExpression[typeAnnotation.type="TSUnknownKeyword"]',
            message: "Double assertion through unknown. Fix the type instead.",
          },
          {
            selector:
              'CallExpression[callee.object.name=/^(vi|jest)$/][callee.property.name=/^(mock|doMock|unstable_mockModule)$/]',
            message:
              "Module mocking. Reach the dependency through a seam the code has: a Layer, an injected interface, or a fake at a boundary not ours (an external service, time, randomness).",
          },
          ...(money ? moneyEscapes : []),
        ],
        ...(never.length
          ? { "id-match": [E, neverPattern(never), { onlyDeclarations: true, properties: true }] }
          : {}),
        // The gate's own rules (inline plugin above). `unknown` in a
        // signature is a type hole like `any`; the SAFETY comment is a fix
        // that adds a line, so it warns.
        "gate/no-unknown-signature": E,
        "gate/safety-comment": "warn",
        ...(effect ? { "gate/effect-tags": E } : {}),

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
