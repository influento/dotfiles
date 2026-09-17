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
# shellcheck disable=SC2086  # $PM is "pnpm remove" etc., $DEPS a word list
[ -z "$DEPS" ] || $PM $DEPS

# 2. Scripts: the ones install set, each back to what the project had under
#    the name. A manifest without the entry recorded none: the whole set goes.
node -e '
const m=require("./ts-gate/.install.json");
const s=m.scripts??Object.fromEntries(["gate","gate:local","gate:full","gate:fix","gate:verify","test:live"].map(k=>[k,null]));
for(const [k,v] of Object.entries(s)) console.log(k+"\t"+(v===null?"":"="+v));' | while IFS=$'\t' read -r k v; do
  if [ -z "$v" ]; then npm pkg delete "scripts.$k"; else npm pkg set "scripts.$k=${v#=}"; fi
done

# 3. Configs: only the ones install wrote and nobody edited since. For one
#    that predates install, the hand-merged lines are named.
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

# 4. Rule files: the names install recorded; the source's names for a
#    manifest without them.
RULES=$(node -p 'const m=require("./ts-gate/.install.json");(m.rules??[]).join("\n")')
if [ -n "$RULES" ]; then
  while IFS= read -r f; do command rm -f ".claude/rules/$(basename "$f")"; done <<< "$RULES"
else
  for f in "$SRC"/rules/*.md; do command rm -f ".claude/rules/$(basename "$f")"; done
fi
rmdir .claude/rules 2>/dev/null || true

# 5. Stop hook and allow rules. Empty containers are pruned; an empty settings.json is removed.
S=.claude/settings.json
if [ -f "$S" ]; then
  node -e '
const fs=require("fs"),p=process.argv[1],s=JSON.parse(fs.readFileSync(p,"utf8")),cmd="bash ts-gate/scripts/stop-hook.sh",m=require("./ts-gate/.install.json");
if(s.hooks?.Stop){
  s.hooks.Stop=s.hooks.Stop.map(e=>({...e,hooks:(e.hooks??[]).filter(h=>h.command!==cmd)})).filter(e=>e.hooks.length);
  if(!s.hooks.Stop.length) delete s.hooks.Stop;
  if(!Object.keys(s.hooks).length) delete s.hooks;
}
if(Array.isArray(s.permissions?.allow)){
  // The rules install added; every one it writes, for a manifest that recorded none.
  const ours=new Set(m.allow??["Bash(npm ci)","Bash(npm run gate)","Bash(npm run gate:local)","Bash(npm run gate:full)","Bash(npm run gate:fix)","Bash(npm test:*)","Bash(npx vitest:*)"]);
  s.permissions.allow=s.permissions.allow.filter(r=>!ours.has(r));
  if(!s.permissions.allow.length) delete s.permissions.allow;
  if(!Object.keys(s.permissions).length) delete s.permissions;
}
Object.keys(s).length?fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n"):fs.unlinkSync(p);' "$S"
fi
rmdir .claude 2>/dev/null || true

# 6. premerge, only if it is still ours: every premerge line of
#    .claude/workshop.conf goes when the one in effect (the last) is exactly
#    'npm run gate'; a file left empty is removed.
CONF=.claude/workshop.conf
if [ -f "$CONF" ]; then
  LAST=$(sed -n 's/^[[:space:]]*premerge[[:space:]]*=[[:space:]]*//p' "$CONF" | sed 's/[[:space:]]*$//' | tail -n 1)
  if [ "$LAST" = "npm run gate" ]; then
    sed -i '/^[[:space:]]*premerge[[:space:]]*=/d' "$CONF"
    grep -q '[^[:space:]]' "$CONF" || command rm -f "$CONF"
  fi
fi
case "$(git config --get workbench.guards 2>/dev/null)" in 'npm run (gate|lint|build|typecheck)|'*) git config --unset workbench.guards ;; esac

# 7. Files. The architecture record is the project's once it differs from the
#    shipped default: moved beside the tree, not deleted with it.
DC=ts-gate/.dependency-cruiser.cjs
if [ -f "$DC" ] && ! cmp -s "$DC" "$SRC/.dependency-cruiser.cjs"; then
  command mv "$DC" dependency-cruiser.kept.cjs
  echo "ts-gate/.dependency-cruiser.cjs was edited (the architecture record): kept as dependency-cruiser.kept.cjs; delete it or move it where the next tool reads it"
fi
command rm -rf ts-gate
echo "uninstalled"
