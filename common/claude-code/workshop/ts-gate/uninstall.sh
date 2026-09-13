#!/usr/bin/env bash
# Remove the TS gate from a project. Mirrors install.sh, guided by ts-gate/.install.json.
#   uninstall.sh <target-dir>
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
T="$(cd "${1:?usage: uninstall.sh <target-dir>}" && pwd)"
cd "$T"
[ -f ts-gate/.install.json ] || { echo "no ts-gate/.install.json in $T, nothing to uninstall"; exit 1; }

# 1. Dependencies: only the ones install added.
PM="npm rm"
[ -f pnpm-lock.yaml ] && PM="pnpm remove"
[ -f yarn.lock ] && PM="yarn remove"
{ [ -f bun.lockb ] || [ -f bun.lock ]; } && PM="bun remove"
DEPS=$(node -p 'require("./ts-gate/.install.json").deps.join(" ")')
[ -z "$DEPS" ] || $PM $DEPS

# 2. Scripts
npm pkg delete scripts.gate scripts.gate:local scripts.gate:full scripts.gate:fix scripts.gate:verify scripts.test:live

# 3. eslint, biome and vitest configs: only the ones install wrote and nobody
#    edited since. One that was there before install got the block by hand
#    (install printed it), so the lines to take out are named here.
node -e '
const fs=require("fs"),c=require("crypto"),m=require("./ts-gate/.install.json");
const merged={config:"eslint.config.mjs: remove the ts-gate lines you merged into it (the import of ./ts-gate/eslint.gate.mjs and the gate(...) spread)",
  vitest:"vitest.config.mjs: remove the ts-gate lines you merged into it (setupFiles ./ts-gate/no-network.mjs and the *.live.test.* exclude)"};
for(const k of ["config","biome","vitest"]){
  const o=m[k];
  if(!o){ if(merged[k]) console.log(merged[k]); continue; }
  if(!fs.existsSync(o.file)) continue;
  if(c.createHash("sha256").update(fs.readFileSync(o.file)).digest("hex")===o.sha256) fs.unlinkSync(o.file);
  else console.log(o.file+" was edited after install, left in place."+(k==="config"?" It imports ./ts-gate/eslint.gate.mjs, which is gone: fix by hand.":k==="vitest"?" Its setupFiles names ./ts-gate/no-network.mjs, which is gone: fix by hand.":""));
}'

# 4. Rules
for f in "$SRC"/rules/*.md; do command rm -f ".claude/rules/$(basename "$f")"; done
rmdir .claude/rules 2>/dev/null || true

# 5. Stop hook and allow rules. Empty containers are pruned; an empty settings.json is removed.
S=.claude/settings.json
if [ -f "$S" ]; then
  node -e '
const fs=require("fs"),p=process.argv[1],s=JSON.parse(fs.readFileSync(p,"utf8")),cmd="bash ts-gate/scripts/stop-hook.sh";
if(s.hooks?.Stop){
  s.hooks.Stop=s.hooks.Stop.map(e=>({...e,hooks:(e.hooks??[]).filter(h=>h.command!==cmd)})).filter(e=>e.hooks.length);
  if(!s.hooks.Stop.length) delete s.hooks.Stop;
  if(!Object.keys(s.hooks).length) delete s.hooks;
}
if(Array.isArray(s.permissions?.allow)){
  const ours=new Set(["Bash(npm ci)","Bash(npm run gate:*)","Bash(npm run gate)","Bash(npm run gate:local)","Bash(npm run gate:full)","Bash(npm run gate:fix)","Bash(npm test:*)","Bash(npx vitest:*)","Bash(npx jest:*)"]);
  s.permissions.allow=s.permissions.allow.filter(r=>!ours.has(r));
  if(!s.permissions.allow.length) delete s.permissions.allow;
  if(!Object.keys(s.permissions).length) delete s.permissions;
}
Object.keys(s).length?fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n"):fs.unlinkSync(p);' "$S"
fi
rmdir .claude 2>/dev/null || true

# 6. workbench.premerge, only if it is still ours.
[ "$(git config --get workbench.premerge 2>/dev/null)" = "npm run gate" ] && git config --unset workbench.premerge

# 7. Files. The architecture record is the project's once it differs from the
#    shipped default: moved beside the tree, not deleted with it.
DC=ts-gate/.dependency-cruiser.cjs
if [ -f "$DC" ] && ! cmp -s "$DC" "$SRC/.dependency-cruiser.cjs"; then
  command mv "$DC" dependency-cruiser.kept.cjs
  echo "ts-gate/.dependency-cruiser.cjs was edited (the architecture record): kept as dependency-cruiser.kept.cjs; delete it or move it where the next tool reads it"
fi
command rm -rf ts-gate
echo "uninstalled"
