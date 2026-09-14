#!/usr/bin/env bash
# The TypeScript registry against its gate: facts about the shipped packages,
# and their eslint.mjs files as stack add copies them, loaded by the real gate.
# Plain bash, no framework. Run: bash tests/registry.sh
set -euo pipefail

HERE=$(readlink -f "$(dirname "$0")/..")
REG="$HERE/packages"
REAL_NPM=$(command -v npm || true)
export REAL_NPM
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export HOME="$TMP/home"
mkdir -p "$HOME"
git config --global init.defaultBranch main

fail=0
check() { if "$@" >/dev/null 2>&1; then echo "ok   $*"; else echo "FAIL $*"; fail=1; fi; }
not() { ! "$@"; }

echo "== the shipped registry"
check not grep -rq 'ServiceMap' "$REG"
check grep -q 'vitest@5' "$REG/shared/effect/package.conf"

echo "== effect's lint file without @vitest/eslint-plugin: effect/tags alone, no vitest block"
mkdir -p "$TMP/lint" && cp "$REG/shared/effect/eslint.mjs" "$TMP/lint/effect.mjs"
check test "$(node --input-type=module -e '
const { default: f } = await import(process.argv[1]);
const c = f({ severity: "error" });
console.log(c.length, c.map((b) => Object.keys(b.rules).join()).join(" "));' "$TMP/lint/effect.mjs")" = "1 effect/tags"

echo "== the registry's lint files as stack add copies them, through real eslint under the gate"
# Borrows the node_modules of a project where ts-gate was installed for real;
# the gate's install runs against that, with 'npm i' a no-op. Unset, the leg says so.
if [ -z "${TSGATE_REAL_PROJECT:-}" ]; then
  echo "skip: set TSGATE_REAL_PROJECT to a project with a real ts-gate install to run this leg"
else
  mkdir -p "$TMP/real/src" "$TMP/realbin" && cd "$TMP/real" && git init -q
  printf '{"name":"real","version":"1.0.0","engines":{"node":">=26"},"devDependencies":{"vitest":"^5.0.0"}}\n' > package.json
  echo '{"compilerOptions":{"strict":true,"noUncheckedIndexedAccess":true,"noEmit":true,"target":"es2024","module":"nodenext"},"include":["src"]}' > tsconfig.json
  ln -s "$TSGATE_REAL_PROJECT/node_modules" node_modules
  cat > "$TMP/realbin/npm" <<'N'
#!/usr/bin/env bash
case "${1:-}" in i|install) ;; *) exec "$REAL_NPM" "$@" ;; esac
N
  chmod +x "$TMP/realbin/npm"
  PATH="$TMP/realbin:$PATH" bash "$HERE/gate/install.sh" . >/dev/null
  ESL="$TSGATE_REAL_PROJECT/node_modules/.bin/eslint"
  reports() { local out; out=$("$ESL" "src/$1.ts" 2>&1 || true); grep -q -- "$2" <<< "$out"; }
  mkdir -p .claude/eslint
  for p in effect money; do cp "$REG/shared/$p/eslint.mjs" ".claude/eslint/$p.mjs"; done
  printf 'export const isNotFound = (e: { readonly _tag: string }): boolean => e._tag === "NotFound";\n' > src/tagged.ts
  printf 'export const amount = (s: string): number => parseFloat(s);\n' > src/amount.ts
  printf 'import { it } from "@effect/vitest";\nimport { Effect } from "effect";\nimport { expect } from "vitest";\n\nit.effect("adds", () => Effect.sync(() => expect(1 + 1).toBe(2)));\n' > src/tags.test.ts
  check reports tagged "effect/tags"
  check reports amount "money/no-number"
  check not reports tags.test "no-standalone-expect"
  mv .claude/eslint/effect.mjs "$TMP/effect.mjs.aside"
  check reports tags.test "vitest/no-standalone-expect"   # without effect's file the same expect is standalone
  mv "$TMP/effect.mjs.aside" .claude/eslint/effect.mjs
  if [ -d "$TSGATE_REAL_PROJECT/node_modules/@shadcn/lint" ]; then
    cp "$REG/frontend/tailwind/eslint.mjs" .claude/eslint/tailwind.mjs
    check bash -c "'$ESL' --print-config src/tagged.ts | grep -q 'shadcn/no-raw-colors'"
  else
    echo "skip: no @shadcn/lint in TSGATE_REAL_PROJECT, tailwind's lint file not loaded"
  fi
fi

if [ "$fail" -eq 0 ]; then echo "all passed"; else echo "FAILURES"; exit 1; fi
