#!/usr/bin/env bash
# Install the TS gate into a TypeScript project.
#   install.sh <target-dir>
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
T="$(cd "${1:?usage: install.sh <target-dir>}" && pwd)"
[ -f "$T/package.json" ] || { echo "no package.json in $T"; exit 1; }
[ -f "$T/tsconfig.json" ] || { echo "no tsconfig.json in $T"; exit 1; }
cd "$T"

# 0. Preconditions, then the Effect reference checkout before anything dirties the
#    tree. Refused rather than warned: a gate without repos/effect has a rule
#    pointing nowhere, and premerge is git config.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "$T is not a git repository"; exit 1; }
git rev-parse --verify -q HEAD >/dev/null || { echo "no commit yet in $T: commit the scaffold first, git subtree needs HEAD"; exit 1; }
if [ ! -d repos/effect ]; then
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "uncommitted changes in $T: commit or stash first, git subtree refuses a dirty tree"; exit 1; }
  git subtree add --prefix=repos/effect https://github.com/Effect-TS/effect.git main --squash
fi
grep -q '"include"\|"exclude"' tsconfig.json || echo "WARNING: tsconfig.json has no include/exclude; tsc will compile repos/effect. Add \"include\": [\"src\"]"
grep -Eq '"strict"[[:space:]]*:[[:space:]]*true' tsconfig.json || echo "WARNING: tsconfig.json lacks \"strict\": true; the type-aware rules assume it"

# 1. Files. Everything but the manifest is replaced, so a re-run carries changes.
[ -d ts-gate ] && find ts-gate -mindepth 1 ! -name .install.json -delete
command mkdir -p ts-gate
command cp -r "$SRC"/. ts-gate/

# 2. Dependencies. Runner detection picks the test plugin.
PM="npm i -D"
[ -f pnpm-lock.yaml ] && PM="pnpm add -D"
[ -f yarn.lock ] && PM="yarn add -D"
{ [ -f bun.lockb ] || [ -f bun.lock ]; } && PM="bun add -d"
DEPS="typescript@5 eslint@10 typescript-eslint@8 eslint-plugin-sonarjs@4 knip@6 dependency-cruiser"
RUNNER=""
grep -q '"vitest"' package.json && RUNNER=vitest && DEPS="$DEPS @vitest/eslint-plugin"
grep -q '"jest"' package.json && [ -z "$RUNNER" ] && RUNNER=jest && DEPS="$DEPS eslint-plugin-jest"
# Only what the project lacks: a re-run must not move pins the project owns.
NEW=$(node -e '
const p=require("./package.json"),have={...p.dependencies,...p.devDependencies};
console.log(process.argv.slice(1).filter(d=>!(d.replace(/(.)@.*/,"$1") in have)).join(" "))' $DEPS)
[ -z "$NEW" ] || $PM $NEW
grep -q '"effect"' package.json || ${PM% -[dD]} effect@rc

# 3. Scripts
npm pkg set \
  scripts.gate="bash ts-gate/scripts/gate.sh" \
  scripts.gate:local="bash ts-gate/scripts/gate.sh --local" \
  scripts.gate:full="tsc --noEmit && eslint . && knip --config ts-gate/knip.json && depcruise --config ts-gate/.dependency-cruiser.cjs src" \
  scripts.gate:fix="eslint . --fix" \
  scripts.gate:verify="bash ts-gate/scripts/verify.sh"

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
# A config this install wrote (the manifest names it) is replaced on re-run
# like every other file, unless it was edited since — then it is kept, and not
# offered for merging again: its gate block is already there. Only a config
# the project brought itself gets the block to merge.
WROTE=""
OWNED=""; OWNED_SHA=""
[ -f ts-gate/.install.json ] && read -r OWNED OWNED_SHA < <(node -e '
const m=require("./ts-gate/.install.json");console.log(m.config?m.config.file+" "+m.config.sha256:"")')
if [ -n "$OWNED" ] && [ -f "$OWNED" ]; then
  if [ "$(sha256sum "$OWNED" | cut -d' ' -f1)" = "$OWNED_SHA" ]; then
    printf '%s\n' "$CONFIG" > "$OWNED"; WROTE=$OWNED
    node -e '
const fs=require("fs"),c=require("crypto"),p="ts-gate/.install.json",m=JSON.parse(fs.readFileSync(p,"utf8"));
m.config.sha256=c.createHash("sha256").update(fs.readFileSync(m.config.file)).digest("hex");
fs.writeFileSync(p,JSON.stringify(m,null,2)+"\n");'
  else
    echo "$OWNED edited since install, kept"
  fi
elif [ -f eslint.config.mjs ] || [ -f eslint.config.js ] || [ -f eslint.config.ts ]; then
  echo "eslint config exists, not touched. Merge this in:"; echo "$CONFIG"
else
  printf '%s\n' "$CONFIG" > eslint.config.mjs; WROTE=eslint.config.mjs
fi

# 5. Rules
command mkdir -p .claude/rules
command cp ts-gate/rules/*.md .claude/rules/

# 6. Stop hook: the deterministic gate. Our entry is replaced, foreign entries
#    are untouched. Judgment review is wb-reviewer's job under workbench.
#    The allow rules cover the commands the rules tell the agent to run by hand;
#    an unattended workbench worker is denied anything not listed.
node -e '
const fs=require("fs"),p=".claude/settings.json";
const s=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8")):{};
s.hooks??={}; s.hooks.Stop??=[];
const command="bash ts-gate/scripts/stop-hook.sh";
s.hooks.Stop=s.hooks.Stop.map(e=>({...e,hooks:(e.hooks??[]).filter(h=>h.command!==command)})).filter(e=>e.hooks.length);
s.hooks.Stop.push({hooks:[{type:"command",command,timeout:600}]});
s.permissions??={}; s.permissions.allow??=[];
for(const r of ["Bash(npm ci)","Bash(npm run gate:*)"]) s.permissions.allow.includes(r)||s.permissions.allow.push(r);
fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n");'

# 7. workbench: its merge runs this command in the branch worktree and refuses on
#    non-zero. Per clone, like every workbench key; inert without workbench.
PREMERGE=$(git config --get workbench.premerge 2>/dev/null || true)
if [ -z "$PREMERGE" ]; then git config workbench.premerge "npm run gate" 2>/dev/null && echo "set git config workbench.premerge 'npm run gate'"
elif [ "$PREMERGE" != "npm run gate" ]; then echo "NOTE: workbench.premerge is '$PREMERGE', left alone; the gate runs at merge only if that command runs 'npm run gate'"; fi

# 8. Manifest: what this install added, so uninstall removes exactly that.
#    Kept on re-run, when every dep already counts as present.
[ -f ts-gate/.install.json ] || node -e '
const fs=require("fs"),c=require("crypto"),[runner,cfg,...specs]=process.argv.slice(1);
const deps=specs.map(d=>d.replace(/(.)@.*/,"$1"));
const config=cfg?{file:cfg,sha256:c.createHash("sha256").update(fs.readFileSync(cfg)).digest("hex")}:null;
fs.writeFileSync("ts-gate/.install.json",JSON.stringify({runner,deps,config},null,2)+"\n");' "$RUNNER" "$WROTE" $NEW

echo
echo "installed. runner: ${RUNNER:-none}"
[ -f src/index.ts ] || [ -f src/main.ts ] || echo "WARNING: set \"entry\" in ts-gate/knip.json — neither src/index.ts nor src/main.ts exists"
echo "next: npm run gate:verify"
