#!/usr/bin/env bash
# Install the TS gate into a TypeScript project.
#   install.sh <target-dir>
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
T="$(cd "${1:?usage: install.sh <target-dir>}" && pwd)"
[ -f "$T/package.json" ] || { echo "no package.json in $T"; exit 1; }
[ -f "$T/tsconfig.json" ] || { echo "no tsconfig.json in $T"; exit 1; }
cd "$T"

# 0. Preconditions. Refused rather than warned: premerge is git config.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "$T is not a git repository"; exit 1; }
grep -q '"include"\|"exclude"' tsconfig.json || echo "WARNING: tsconfig.json has no include/exclude; tsc will compile everything, the read-only subtrees 'stack add' puts under repos/ included. Add \"include\": [\"src\"]"
grep -Eq '"strict"[[:space:]]*:[[:space:]]*true' tsconfig.json || echo "WARNING: tsconfig.json lacks \"strict\": true; the type-aware rules assume it"
grep -Eq '"noUncheckedIndexedAccess"[[:space:]]*:[[:space:]]*true' tsconfig.json || echo "WARNING: tsconfig.json lacks \"noUncheckedIndexedAccess\": true; arr[i] and obj[key] are typed as present without it"

# 1. Files. Everything but the manifest is replaced, so a re-run carries
#    changes — except what the project put in: knip.json's ignore lists (the
#    brownfield baseline, every dependency and file stack added) are merged
#    back, and .dependency-cruiser.cjs, the architecture record, is kept
#    once it exists (diff it against this source by hand when the gate's
#    default rules move).
KNIP_KEEP=""
[ -f ts-gate/knip.json ] && KNIP_KEEP=$(node -p 'const j=require("./ts-gate/knip.json");JSON.stringify({ignore:j.ignore||[],ignoreDependencies:j.ignoreDependencies||[]})')
DC_KEEP=""
[ -f ts-gate/.dependency-cruiser.cjs ] && DC_KEEP=$(mktemp) && command cp ts-gate/.dependency-cruiser.cjs "$DC_KEEP"
[ -d ts-gate ] && find ts-gate -mindepth 1 ! -name .install.json -delete
command mkdir -p ts-gate
command cp -r "$SRC"/. ts-gate/
[ -z "$KNIP_KEEP" ] || node -e '
const fs=require("fs"),p="ts-gate/knip.json",j=JSON.parse(fs.readFileSync(p,"utf8")),k=JSON.parse(process.argv[1]);
for(const key of ["ignore","ignoreDependencies"]) j[key]=[...new Set([...(j[key]||[]),...k[key]])];
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
# Only what the project lacks: a re-run must not move pins the project owns.
NEW=$(node -e '
const p=require("./package.json"),have={...p.dependencies,...p.devDependencies};
console.log(process.argv.slice(1).filter(d=>!(d.replace(/(.)@.*/,"$1") in have)).join(" "))' $DEPS)
[ -z "$NEW" ] || $PM $NEW

# 3. Scripts
FULL="tsc --noEmit && eslint . && biome format . && knip --config ts-gate/knip.json && depcruise --config ts-gate/.dependency-cruiser.cjs src"
[ "$RUNNER" = vitest ] && FULL="$FULL && vitest run --passWithNoTests --exclude 'repos/**' --exclude '.worktrees/**'"
npm pkg set \
  scripts.gate="bash ts-gate/scripts/gate.sh" \
  scripts.gate:local="bash ts-gate/scripts/gate.sh --local" \
  scripts.gate:full="$FULL" \
  scripts.gate:fix="eslint . --fix && biome format --write ." \
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
record_owned() { # key file — the sha the next run compares against; step 8 writes it on a first install
  [ -z "$2" ] || [ ! -f ts-gate/.install.json ] || node -e '
const fs=require("fs"),c=require("crypto"),p="ts-gate/.install.json",m=JSON.parse(fs.readFileSync(p,"utf8")),[k,f]=process.argv.slice(1);
m[k]={file:f,sha256:c.createHash("sha256").update(fs.readFileSync(f)).digest("hex")};
fs.writeFileSync(p,JSON.stringify(m,null,2)+"\n");' "$1" "$2"
}

# 4. ESLint config
TESTS='"**/*.{test,spec}.{ts,tsx}", "**/__tests__/**/*.{ts,tsx}"'
case "$RUNNER" in
  vitest) IMP='import vitest from "@vitest/eslint-plugin";'
          CFG="{ files: [$TESTS], ...vitest.configs.recommended, rules: { ...vitest.configs.recommended.rules, \"vitest/expect-expect\": \"error\" } }," ;;
  jest)   IMP='import jest from "eslint-plugin-jest";'
          CFG="{ files: [$TESTS], ...jest.configs[\"flat/recommended\"], rules: { ...jest.configs[\"flat/recommended\"].rules, \"jest/expect-expect\": \"error\" } }," ;;
  *)      IMP=""; CFG="" ;;
esac
CONFIG="import gate from \"./ts-gate/eslint.gate.mjs\";
$IMP

export default [
  { ignores: [\"dist/**\", \"coverage/**\", \"repos/**\", \".worktrees/**\", \"**/*.generated.ts\"] },
  ...gate({ tsconfigRootDir: import.meta.dirname }),
  $CFG
];"
WROTE=""
if owned_target config eslint.config.mjs eslint.config.mjs eslint.config.js eslint.config.ts; then
  [ -z "$OWN" ] || { printf '%s\n' "$CONFIG" > "$OWN"; WROTE=$OWN; }
else
  echo "eslint config exists, not touched. Merge this in:"; echo "$CONFIG"
fi
record_owned config "$WROTE"

# 4b. Biome config. At the root, not in ts-gate/: Biome refuses a second
#     biome.json anywhere in the tree it scans, whatever `includes` says, so
#     the shipped file has a name it never discovers and is copied out.
BIOME_WROTE=""
if owned_target biome biome.json biome.json biome.jsonc; then
  [ -z "$OWN" ] || { command cp ts-gate/biome.template.json "$OWN"; BIOME_WROTE=$OWN; }
else
  echo "biome config exists, not touched; the gate formats with it (ts-gate/biome.template.json is what install writes: formatter only, .ts/.tsx, spaces)"
fi
record_owned biome "$BIOME_WROTE"

# 4c. vitest config: loads ts-gate/no-network.mjs, so no test reaches the
#     network (loopback allowed). Only vitest reads it; scripts and the app
#     keep the network. A project's own config gets the line to add.
VITEST_WROTE=""
if [ "$RUNNER" = vitest ]; then
  VCONFIG='import { defineConfig } from "vitest/config";

// ts-gate: no test reaches the network; see ts-gate/no-network.mjs.
export default defineConfig({ test: { setupFiles: ["./ts-gate/no-network.mjs"] } });'
  if owned_target vitest vitest.config.mjs vitest.config.* vite.config.* vitest.workspace.*; then
    [ -z "$OWN" ] || { printf '%s\n' "$VCONFIG" > "$OWN"; VITEST_WROTE=$OWN; }
  else
    echo "vitest config exists, not touched. Add to it: test: { setupFiles: [\"./ts-gate/no-network.mjs\"] }"
  fi
  record_owned vitest "$VITEST_WROTE"
fi

# 5. Rules
command mkdir -p .claude/rules
command cp ts-gate/rules/*.md .claude/rules/

# 6. Stop hook: the deterministic gate. Our entry is replaced, foreign entries
#    are untouched. Judgment review is wb-reviewer's job under workbench.
#    The allow rules cover the commands the rules tell the agent to run by hand
#    and the test runner a criterion names; an unattended workbench worker is
#    denied anything not listed.
node -e '
const fs=require("fs"),p=".claude/settings.json";
const s=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
s.hooks??={}; s.hooks.Stop??=[];
const command="bash ts-gate/scripts/stop-hook.sh";
s.hooks.Stop=s.hooks.Stop.map(e=>({...e,hooks:(e.hooks??[]).filter(h=>h.command!==command)})).filter(e=>e.hooks.length);
s.hooks.Stop.push({hooks:[{type:"command",command,timeout:600}]});
s.permissions??={}; s.permissions.allow??=[];
const rules=["Bash(npm ci)","Bash(npm run gate:*)","Bash(npm test:*)"];
if(process.argv[1]) rules.push("Bash(npx "+process.argv[1]+":*)");
for(const r of rules) s.permissions.allow.includes(r)||s.permissions.allow.push(r);
fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n");' "$RUNNER"

# 7. workbench: its merge runs this command in the branch worktree and refuses on
#    non-zero. Per clone, like every workbench key; inert without workbench.
PREMERGE=$(git config --get workbench.premerge 2>/dev/null || true)
if [ -z "$PREMERGE" ]; then git config workbench.premerge "npm run gate" 2>/dev/null && echo "set git config workbench.premerge 'npm run gate'"
elif [ "$PREMERGE" != "npm run gate" ]; then echo "NOTE: workbench.premerge is '$PREMERGE', left alone; the gate runs at merge only if that command runs 'npm run gate'"; fi

# 8. Manifest: what this install added, so uninstall removes exactly that.
#    Kept on re-run, when every dep already counts as present.
[ -f ts-gate/.install.json ] || node -e '
const fs=require("fs"),c=require("crypto"),[runner,cfg,bio,vit,...specs]=process.argv.slice(1);
const deps=specs.map(d=>d.replace(/(.)@.*/,"$1"));
const own=f=>f?{file:f,sha256:c.createHash("sha256").update(fs.readFileSync(f)).digest("hex")}:null;
fs.writeFileSync("ts-gate/.install.json",JSON.stringify({runner,deps,config:own(cfg),biome:own(bio),vitest:own(vit)},null,2)+"\n");' "$RUNNER" "$WROTE" "$BIOME_WROTE" "$VITEST_WROTE" $NEW

echo
echo "installed. runner: ${RUNNER:-none}"
[ -f src/index.ts ] || [ -f src/main.ts ] || echo "WARNING: set \"entry\" in ts-gate/knip.json — neither src/index.ts nor src/main.ts exists"
echo "next: npm run gate:verify"
