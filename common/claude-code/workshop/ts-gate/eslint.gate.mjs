// The gate's eslint rules: volume (more code than there should be), the
// correctness subset of recommendedTypeChecked, and the inline `gate/*`
// plugin. Cherry-picked on purpose: the rest of recommendedTypeChecked is not
// here, and mixing all of it in is what makes day one unsurvivable. Tiers,
// switches and the measured evidence: CLAUDE.md in the ts-gate source, Rules.
//
// Usage in your eslint.config.mjs:
//   import gate from "./ts-gate/eslint.gate.mjs";
//   export default [ ...gate({ tsconfigRootDir: import.meta.dirname }) ];

import fs from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import tseslint from "typescript-eslint";
import sonarjs from "eslint-plugin-sonarjs";

// Lint a stack package brings (`stack add` copies packages/<name>/eslint.mjs to
// .claude/eslint/<name>.mjs): each file's default export, an array of flat
// config objects or a function of the gate's options returning one, appended
// after the gate's own, in file-name order. The gate names no package; it
// loads what is there. Imported at module load because import() is async and
// gate() is not; ts-gate/ sits at the project root.
const extrasDir = join(import.meta.dirname, "..", ".claude", "eslint");
const extras = [];
for (const file of fs.existsSync(extrasDir) ? fs.readdirSync(extrasDir).filter((f) => f.endsWith(".mjs")).sort() : []) {
  const { default: blocks } = await import(pathToFileURL(join(extrasDir, file)).href);
  extras.push({ file, blocks });
}
const extraBlocks = (opts) =>
  extras.flatMap(({ file, blocks }) => {
    const out = typeof blocks === "function" ? blocks(opts) : blocks;
    if (!Array.isArray(out)) {
      throw new Error(`.claude/eslint/${file}: the default export must be an array of eslint config objects, or a function returning one`);
    }
    return out;
  });

// The project's settings (.claude/workshop.conf, `key=value` lines; the key
// table: workshop/CLAUDE.md in the dotfiles source), read as workbench and
// scripts/stop-hook.sh read them: lines trimmed, blank and `#` lines skipped,
// split at the first `=`, the last occurrence wins, an invalid value is the
// default.
const workshopConf = (root) => {
  const conf = new Map();
  let text = "";
  try {
    text = fs.readFileSync(join(root, ".claude/workshop.conf"), "utf8");
  } catch {
    return conf;
  }
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    const eq = line.indexOf("=");
    if (line === "" || line.startsWith("#") || eq < 0) continue;
    conf.set(line.slice(0, eq).trim(), line.slice(eq + 1).trim());
  }
  return conf;
};
const confCount = (conf, key, fallback) => {
  const v = conf.get(key);
  return v !== undefined && /^[1-9][0-9]{0,8}$/.test(v) ? Number(v) : fallback;
};

// Words the workbench glossary rejects (`| Use | Never |` rows in
// workbench/GLOSSARY.md), as a negative lookahead for id-match over what this
// code declares. Substring, not exact: a worker writes `accountId`, never
// `account` (CLAUDE.md, Touchpoints). A property another module owns
// (`stripe.account`) is not ours to rename and is not checked.
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

// `x as unknown as Y` is a deliberate override — worse than `any`.
const noDoubleAssertion = selectorRule("no double assertion through unknown", [
  ['TSAsExpression > TSAsExpression[typeAnnotation.type="TSUnknownKeyword"]', "Double assertion through unknown. Fix the type instead."],
]);

// `vi.mock` / `jest.mock` replaces a module wholesale: the test then proves
// the mock, and the seam the code should have (a Layer, an injected
// interface) never gets written. Spies and `vi.fn` stay: they fake at a
// boundary the caller chose.
const noModuleMock = selectorRule("no module mocking", [
  [
    'CallExpression[callee.object.name=/^(vi|jest)$/][callee.property.name=/^(mock|doMock|unstable_mockModule)$/]',
    "Module mocking. Reach the dependency through a seam the code has: a Layer, an injected interface, or a fake at a boundary not ours (an external service, time, randomness).",
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

const gatePlugin = {
  rules: {
    "no-double-assertion": noDoubleAssertion,
    "no-module-mock": noModuleMock,
    "no-unknown-signature": noUnknownSignature,
    "safety-comment": safetyComment,
  },
};

/**
 * @param {object}  opts
 * @param {string}  opts.tsconfigRootDir  directory holding your tsconfig.json
 * @param {"error"|"warn"} [opts.severity="error"]  use "warn" for the first rollout pass
 */
export default function gate({ tsconfigRootDir, severity = "error" }) {
  const E = severity;
  const never = neverWords(join(tsconfigRootDir, "workbench/GLOSSARY.md"));
  // Thresholds only; severities and options stay as written below.
  const conf = workshopConf(tsconfigRootDir);
  const limit = (key, fallback) => confCount(conf, key, fallback);
  return [
    {
      files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
      plugins: { "@typescript-eslint": tseslint.plugin, sonarjs, gate: gatePlugin },
      // No inline escape: a disable comment is a hole the Stop hook cannot see
      // (measured; CLAUDE.md). A rule wrong for a file changes in
      // eslint.config.mjs, in its own commit.
      linterOptions: { noInlineConfig: true, reportUnusedDisableDirectives: "error" },
      languageOptions: {
        parser: tseslint.parser,
        // Root config files (vitest.config.ts, vite.config.ts) sit outside
        // tsconfig's include, so the project service has no program for them
        // and eslint . fails to parse them; the default project covers them.
        parserOptions: { projectService: { allowDefaultProject: ["*.config.ts", "*.config.mts"] }, tsconfigRootDir },
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
        ...(never.length
          ? { "id-match": [E, neverPattern(never), { onlyDeclarations: true, properties: true }] }
          : {}),
        // The inline plugin above.
        "gate/no-double-assertion": E,
        "gate/no-module-mock": E,
        "gate/no-unknown-signature": E,
        "gate/safety-comment": "warn",

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

        // --- the one hard shape rule --------------------------------------
        "sonarjs/cognitive-complexity": [E, limit("lint.complexity", 15)],
        "sonarjs/no-nested-functions": [E, { threshold: limit("lint.max_nesting", 3) }],

        // --- size signals: warn only, never block ---------------------------
        "max-lines": ["warn", { max: limit("lint.max_lines", 1000), skipBlankLines: true, skipComments: true }],
        "max-lines-per-function": ["warn", { max: limit("lint.max_lines_per_function", 100), skipBlankLines: true, skipComments: true }],
        "max-statements": ["warn", limit("lint.max_statements", 30)],
        "max-params": ["warn", limit("lint.max_params", 6)],
        "max-depth": ["warn", limit("lint.max_depth", 4)],
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
    ...extraBlocks({ tsconfigRootDir, severity }),
  ];
}
