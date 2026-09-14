// Effect idioms, appended to ts-gate's eslint config from
// .claude/eslint/effect.mjs. A project changes a rule after the gate's spread
// in eslint.config.mjs, never here (stack update re-copies this file).

// The vitest plugin is ts-gate's, installed only when the project had vitest
// at install time; without it there is no vitest lint to configure, so its
// block below is left out rather than failing the whole config.
const vitest = await import("@vitest/eslint-plugin").then(
  (m) => m.default,
  (e) => {
    if (e.code === "ERR_MODULE_NOT_FOUND") return null;
    throw e;
  },
);

// A tagged value is branched on with Match or caught with catchTag, never by
// reading `_tag` by hand, and it is built by its constructor, never as a
// literal object. Names checked against repos/effect at 4.0.0-rc.115
// (Match.tag/tags/tagsExhaustive/when/not, Effect.catchTag/catchTags,
// Data.taggedEnum's $match/$is, Predicate.isTagged,
// Schema.TaggedError/TaggedStruct, Data.TaggedError). Measured 2026-09-13 as
// ts-gate's `gate/effect-tags`: 3/3 workers wrote `e._tag === ...` without
// it, 0/3 with it (ts-gate's CLAUDE.md, Rules).
const TAG_EQ = "BinaryExpression[operator=/^[!=]==?$/]";
const TAG_SELECTORS = [
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
    'Effect: a chain of literal ternaries is a match. Use Match.value(x).pipe(Match.when("a", ...), Match.when("b", ...), Match.orElse(...)).',
  ],
];
const tags = {
  meta: { type: "problem", docs: { description: "Effect tagged values go through Match, catchTag and their constructors" }, schema: [] },
  create: (ctx) => Object.fromEntries(TAG_SELECTORS.map(([selector, message]) => [selector, (node) => ctx.report({ node, message })])),
};

// @effect/vitest's testers are test blocks the vitest plugin does not
// recognise; without the list every Effect test is a standalone expect. The
// vitest block ts-gate's install writes sits before the gate's spread, so
// these options come after its recommended settings.
const BLOCKS = ["it.effect", "it.live", "it.scoped", "it.scopedLive", "it.prop", "effect", "live", "scoped", "scopedLive"];

export default ({ severity }) => [
  {
    files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
    plugins: { effect: { rules: { tags } } },
    rules: { "effect/tags": severity },
  },
  ...(vitest
    ? [
        {
          files: ["**/*.{test,spec}.{ts,tsx}", "**/__tests__/**/*.{ts,tsx}"],
          plugins: { vitest },
          rules: {
            "vitest/expect-expect": ["error", { additionalTestBlockFunctions: BLOCKS }],
            "vitest/no-standalone-expect": ["error", { additionalTestBlockFunctions: BLOCKS }],
          },
        },
      ]
    : []),
];
