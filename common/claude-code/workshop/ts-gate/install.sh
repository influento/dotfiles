#!/usr/bin/env bash
# Install the TS gate into a TypeScript project.
#   install.sh <target-dir>
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
T="$(cd "${1:?usage: install.sh <target-dir>}" && pwd)"
[ -f "$T/package.json" ] || { echo "no package.json in $T"; exit 1; }
[ -f "$T/tsconfig.json" ] || { echo "no tsconfig.json in $T"; exit 1; }
cd "$T"
# The project copy of this script sits at $T/ts-gate: run from there, step 1
# would empty ts-gate/ and then copy it onto itself. Refused before anything moves.
if [ "$SRC" -ef "$T/ts-gate" ]; then
  echo "install.sh is the project copy; run the dotfiles source instead: bash \"\$TS_GATE/install.sh\" $T"; exit 1
fi

# 0. Preconditions. Refused rather than warned: guards is git config.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "$T is not a git repository"; exit 1; }
grep -q '"include"\|"exclude"' tsconfig.json || echo "WARNING: tsconfig.json has no include/exclude; tsc will compile everything, the read-only subtrees 'stack add' puts under repos/ included. Add \"include\": [\"src\"]"
grep -Eq '"strict"[[:space:]]*:[[:space:]]*true' tsconfig.json || echo "WARNING: tsconfig.json lacks \"strict\": true; the type-aware rules assume it"
grep -Eq '"noUncheckedIndexedAccess"[[:space:]]*:[[:space:]]*true' tsconfig.json || echo "WARNING: tsconfig.json lacks \"noUncheckedIndexedAccess\": true; arr[i] and obj[key] are typed as present without it"
node -e 'process.exit(require("./package.json").engines?.node?0:1)' || echo "WARNING: package.json has no engines.node; a Dockerfile or a CI container has nothing to pin node to"

# 1. Files: what the gate runs at the project. Everything but the manifest is
#    replaced on a re-run, except what the project put in: knip.json's ignore
#    lists and entry are merged back, and .dependency-cruiser.cjs (the
#    architecture record) is kept once it exists.
SHIP=".dependency-cruiser.cjs eslint.gate.mjs eslint-line.mjs knip.json no-network.mjs vitest.live.mjs scripts"
KNIP_KEEP=""
[ -f ts-gate/knip.json ] && KNIP_KEEP=$(node -p 'const j=require("./ts-gate/knip.json");JSON.stringify({ignore:j.ignore||[],ignoreDependencies:j.ignoreDependencies||[],entry:j.entry})')
DC_KEEP=""
[ -f ts-gate/.dependency-cruiser.cjs ] && DC_KEEP=$(mktemp) && command cp ts-gate/.dependency-cruiser.cjs "$DC_KEEP"
[ -d ts-gate ] && find ts-gate -mindepth 1 ! -name .install.json -delete
command mkdir -p ts-gate
for f in $SHIP; do command cp -r "$SRC/$f" ts-gate/; done
[ -z "$KNIP_KEEP" ] || node -e '
const fs=require("fs"),p="ts-gate/knip.json",j=JSON.parse(fs.readFileSync(p,"utf8")),k=JSON.parse(process.argv[1]);
for(const key of ["ignore","ignoreDependencies"]) j[key]=[...new Set([...(j[key]||[]),...k[key]])];
if(k.entry) j.entry=k.entry;
fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$KNIP_KEEP"
[ -z "$DC_KEEP" ] || { command mv "$DC_KEEP" ts-gate/.dependency-cruiser.cjs; echo "ts-gate/.dependency-cruiser.cjs kept (the architecture record); the shipped default is in $SRC"; }

# 2. Dependencies. Runner detection picks the test plugin.
PM="npm i -D"
[ -f pnpm-lock.yaml ] && PM="pnpm add -D"
[ -f yarn.lock ] && PM="yarn add -D"
{ [ -f bun.lockb ] || [ -f bun.lock ]; } && PM="bun add -d"
DEPS="typescript@5 eslint@10 typescript-eslint@8 eslint-plugin-sonarjs@4 knip@6 dependency-cruiser @biomejs/biome@2"
RUNNER=""
grep -q '"vitest"' package.json && RUNNER=vitest && DEPS="$DEPS @vitest/eslint-plugin"
grep -q '"jest"' package.json && [ -z "$RUNNER" ] && RUNNER=jest && DEPS="$DEPS eslint-plugin-jest"
# A peer-installed vitest (@effect/vitest pulls one in) is in node_modules but
# not in package.json, so it does not count: the gate would run no tests.
[ -n "$RUNNER" ] || echo "WARNING: no test runner in package.json (\"vitest\" or \"jest\" as a devDependency) — the gate will run no tests and write no vitest config; npm i -D vitest@5, then re-run install"
# Only what the project lacks: a re-run must not move pins the project owns.
NEW=$(node -e '
const p=require("./package.json"),have={...p.dependencies,...p.devDependencies};
console.log(process.argv.slice(1).filter(d=>!(d.replace(/(.)@.*/,"$1") in have)).join(" "))' $DEPS)
[ -z "$NEW" ] || $PM $NEW

# 3. Scripts
FULL="tsc --noEmit && eslint . && biome format . && knip --config ts-gate/knip.json && depcruise --config ts-gate/.dependency-cruiser.cjs src"
# repos/** and .worktrees/** are excluded by vitest.config.mjs (or the lines
# install prints for a foreign one); the live tier's exclude stays here because
# a foreign config that lacks it would run real network from gate:full.
[ "$RUNNER" = vitest ] && FULL="$FULL && vitest run --passWithNoTests --exclude '**/*.live.test.*'"
# test:live: the live tier (*.live.test.ts, real network), a script a person
# runs; not in the allow rules, so an unattended worker cannot.
[ "$RUNNER" != vitest ] || npm pkg set scripts.test:live="vitest run --config ts-gate/vitest.live.mjs"
npm pkg set \
  scripts.gate="bash ts-gate/scripts/gate.sh" \
  scripts.gate:local="bash ts-gate/scripts/gate.sh --local" \
  scripts.gate:full="$FULL" \
  scripts.gate:fix='eslint . --fix; e=$?; biome format --write .; b=$?; exit $((e > b ? e : b))' \
  scripts.gate:verify="bash ts-gate/scripts/verify.sh"

# A config this install wrote (the manifest names it under a key) is replaced
# on re-run like every other file, unless it was edited since — then it is
# kept, and not offered for merging again: its gate block is already there.
# A config the project brought itself is never touched. Sets OWN to the file
# to write (empty: keep), returns 1 when a foreign config exists.
owned_target() { # key default-file foreign-file...
  local key=$1 def=$2 f="" sha="" g; shift 2
  OWN=""
  [ -f ts-gate/.install.json ] && read -r f sha < <(node -e '
const m=require("./ts-gate/.install.json"),k=process.argv[1];console.log(m[k]?m[k].file+" "+m[k].sha256:"")' "$key")
  if [ -n "$f" ] && [ -f "$f" ]; then
    if [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$sha" ]; then OWN=$f; else echo "$f edited since install, kept"; fi
    return 0
  fi
  for g in "$@"; do [ -e "$g" ] && return 1; done
  OWN=$def
}

# 4. ESLint config
TESTS='"**/*.{test,spec}.{ts,tsx}", "**/__tests__/**/*.{ts,tsx}"'
case "$RUNNER" in
  # Written before the gate's spread: a test-block list a library needs
  # (@effect/vitest's it.effect) comes from its stack package's .claude/eslint
  # file, which gate() appends, and a later block's options win.
  vitest) IMP='import vitest from "@vitest/eslint-plugin";'
          CFG="{ files: [$TESTS], ...vitest.configs.recommended }," ;;
  jest)   IMP='import jest from "eslint-plugin-jest";'
          CFG="{ files: [$TESTS], ...jest.configs[\"flat/recommended\"], rules: { ...jest.configs[\"flat/recommended\"].rules, \"jest/expect-expect\": \"error\" } }," ;;
  *)      IMP=""; CFG="" ;;
esac
CONFIG="import gate from \"./ts-gate/eslint.gate.mjs\";
$IMP

export default [
  { ignores: [\"dist/**\", \"coverage/**\", \"repos/**\", \".worktrees/**\", \"**/*.generated.ts\"] },
  $CFG
  ...gate({ tsconfigRootDir: import.meta.dirname }),
];"
WROTE=""
if owned_target config eslint.config.mjs eslint.config.mjs eslint.config.js eslint.config.ts; then
  [ -z "$OWN" ] || { printf '%s\n' "$CONFIG" > "$OWN"; WROTE=$OWN; }
else
  echo "eslint config exists, not touched. Merge this in:"; echo "$CONFIG"
fi

# 4b. Biome config. At the root, not in ts-gate/: Biome refuses a second
#     biome.json anywhere in the tree it scans, whatever `includes` says, so
#     the shipped file has a name it never discovers and is copied out.
BIOME_WROTE=""
if owned_target biome biome.json biome.json biome.jsonc; then
  [ -z "$OWN" ] || { command cp "$SRC/biome.template.json" "$OWN"; BIOME_WROTE=$OWN; }
else
  echo "biome config exists, not touched; the gate formats with it"
  # gate:full and gate:fix format the whole tree: a config that does not leave
  # out the read-only subtrees and the gate's own files rewrites thousands of
  # files at the first run, and the next install puts ts-gate/ back.
  for g in biome.json biome.jsonc; do
    [ -f "$g" ] || continue
    grep -q 'repos/' "$g" && grep -q 'ts-gate/' "$g" \
      || echo "WARNING: $g does not leave repos/** and ts-gate/** alone; add to it: \"files\": { \"includes\": [\"**\", \"!repos/**\", \"!ts-gate/**\", \"!.worktrees/**\"] }"
  done
fi

# 4c. vitest config: the no-network setup file and the live-tier exclude. A
#     project's own config gets the two lines to add.
VITEST_WROTE=""
if [ "$RUNNER" = vitest ]; then
  VCONFIG='import { configDefaults, defineConfig } from "vitest/config";

// ts-gate: no test reaches the network (ts-gate/no-network.mjs); *.live.test.ts
// is the live tier, run by `npm run test:live` (ts-gate/vitest.live.mjs).
export default defineConfig({
  test: {
    setupFiles: ["./ts-gate/no-network.mjs"],
    exclude: [...configDefaults.exclude, "**/*.live.test.{ts,tsx}", "repos/**", ".worktrees/**"],
  },
});'
  if owned_target vitest vitest.config.mjs vitest.config.* vite.config.* vitest.workspace.*; then
    [ -z "$OWN" ] || { printf '%s\n' "$VCONFIG" > "$OWN"; VITEST_WROTE=$OWN; }
  else
    echo "vitest config exists, not touched. Add to it: test: { setupFiles: [\"./ts-gate/no-network.mjs\"], exclude: [...configDefaults.exclude, \"**/*.live.test.{ts,tsx}\", \"repos/**\", \".worktrees/**\"] }"
  fi
fi

# 5. Rule files
command mkdir -p .claude/rules
command cp "$SRC"/rules/*.md .claude/rules/

# 6. Stop hook: our entry is replaced, foreign entries are untouched. The
#    allow rules: what the rule files tell the agent to run by hand and the
#    test runner a criterion names; an unattended worker is denied the rest.
node -e '
const fs=require("fs"),p=".claude/settings.json";
const s=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
s.hooks??={}; s.hooks.Stop??=[];
const command="bash ts-gate/scripts/stop-hook.sh";
// A timeout set by hand survives the re-run; 600 only for a fresh entry.
const timeout=s.hooks.Stop.flatMap(e=>e.hooks??[]).find(h=>h.command===command)?.timeout??600;
s.hooks.Stop=s.hooks.Stop.map(e=>({...e,hooks:(e.hooks??[]).filter(h=>h.command!==command)})).filter(e=>e.hooks.length);
s.hooks.Stop.push({hooks:[{type:"command",command,timeout}]});
s.permissions??={}; s.permissions.allow??=[];
// Not gate:* — that would cover gate:verify, which starts a model session.
const rules=["Bash(npm ci)","Bash(npm run gate)","Bash(npm run gate:local)","Bash(npm run gate:full)","Bash(npm run gate:fix)","Bash(npm test:*)"];
if(process.argv[1]) rules.push("Bash(npx "+process.argv[1]+":*)");
s.permissions.allow=s.permissions.allow.filter(r=>r!=="Bash(npm run gate:*)");
for(const r of rules) s.permissions.allow.includes(r)||s.permissions.allow.push(r);
fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n");' "$RUNNER"

# 7. workbench keys; inert without workbench. premerge goes in the committed
#    .claude/workshop.conf, only when the file has no premerge key: a project
#    points it at its own wrapper, which a re-install must not undo. A value
#    an older install left in git config is carried over instead. Read with
#    the same last-occurrence rule as scripts/stop-hook.sh.
CONF=.claude/workshop.conf
PREMERGE=""
HAS_PREMERGE=0
if [ -f "$CONF" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    case "$line" in '#'*) continue ;; *=*) ;; *) continue ;; esac
    k=${line%%=*}; k="${k%"${k##*[![:space:]]}"}"
    [ "$k" = premerge ] || continue
    HAS_PREMERGE=1; PREMERGE=${line#*=}; PREMERGE="${PREMERGE#"${PREMERGE%%[![:space:]]*}"}"
  done < "$CONF"
fi
if [ "$HAS_PREMERGE" -eq 0 ]; then
  PREMERGE=$(git config --local --get workbench.premerge 2>/dev/null || true)
  [ -n "$PREMERGE" ] || PREMERGE="npm run gate"
  command mkdir -p .claude
  # Over the commented-out line workbench init writes, else appended.
  if [ -f "$CONF" ] && grep -Eq '^[[:space:]]*#[[:space:]]*premerge[[:space:]]*=' "$CONF"; then
    PREMERGE="$PREMERGE" awk '!done && /^[[:space:]]*#[[:space:]]*premerge[[:space:]]*=/ { print "premerge=" ENVIRON["PREMERGE"]; done = 1; next } { print }' "$CONF" > "$CONF.tmp"
    command mv "$CONF.tmp" "$CONF"
  else
    [ ! -s "$CONF" ] || [ -z "$(tail -c1 "$CONF")" ] || echo >> "$CONF"
    printf 'premerge=%s\n' "$PREMERGE" >> "$CONF"
  fi
  git config --local --unset workbench.premerge 2>/dev/null || true
  echo "set premerge=$PREMERGE in $CONF"
fi
[ "$PREMERGE" = "npm run gate" ] || echo "NOTE: premerge is '$PREMERGE' in $CONF, left alone; the gate runs at merge only if that command runs 'npm run gate'"
#    guards: the words for a criterion step that proves nothing. Workbench
#    holds the rule; the words are this toolchain's.
GUARDS='npm run (gate|lint|build|typecheck)|(^|[^[:alnum:]])(npx )?tsc([^[:alnum:]]|$)'
[ "$(git config --get workbench.guards 2>/dev/null || true)" = "$GUARDS" ] \
  || { git config workbench.guards "$GUARDS" 2>/dev/null && echo "set git config workbench.guards for npm run gate/lint/build/typecheck and tsc"; }

# 8. Manifest: what this install added, so uninstall removes exactly that. A
#    config written this run gets its sha (what the next run compares
#    against); a kept or foreign one keeps its entry. On a re-run the runner
#    is re-recorded (vitest may have arrived since) and the deps this run
#    added join the list.
node -e '
const fs=require("fs"),c=require("crypto"),p="ts-gate/.install.json",[runner,cfg,bio,vit,...specs]=process.argv.slice(1);
const m=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
for(const [k,f] of [["config",cfg],["biome",bio],["vitest",vit]])
  if(f) m[k]={file:f,sha256:c.createHash("sha256").update(fs.readFileSync(f)).digest("hex")}; else m[k]??=null;
m.runner=runner; m.deps=[...new Set([...(m.deps||[]),...specs.map(d=>d.replace(/(.)@.*/,"$1"))])];
fs.writeFileSync(p,JSON.stringify(m,null,2)+"\n");' "$RUNNER" "$WROTE" "$BIOME_WROTE" "$VITEST_WROTE" $NEW

echo
echo "installed. runner: ${RUNNER:-none}"
[ -f src/index.ts ] || [ -f src/main.ts ] || echo "WARNING: set \"entry\" in ts-gate/knip.json — neither src/index.ts nor src/main.ts exists"
echo "next: npm run gate:verify"
