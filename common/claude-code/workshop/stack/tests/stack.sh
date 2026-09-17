#!/usr/bin/env bash
# End-to-end tests for the stack CLI, in a throwaway project against a
# throwaway registry and a local bare "private" repository.
# Plain bash, no framework. Run: bash tests/stack.sh
set -euo pipefail

STACK=$(readlink -f "$(dirname "$0")/../bin/stack")
REAL_NPM=$(command -v npm || true)
export REAL_NPM
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export HOME="$TMP/home"
mkdir -p "$HOME"
git config --global init.defaultBranch main
# private.root is <host>:<dir> in life; file://<dir> exercises the same
# <root>/<repo>.git concatenation without ssh.
git config --global private.root "file://$TMP/srv"

fail=0
check() { if "$@" >/dev/null 2>&1; then echo "ok   $*"; else echo "FAIL $*"; fail=1; fi; }
not() { ! "$@"; }

# --- a "private" upstream that ships its own skills and docs -----------------
mkdir -p "$TMP/up/.claude/skills/run-thing" "$TMP/up/docs"
cat > "$TMP/up/README.md" <<'R'
# thing
R
echo "grid facts" > "$TMP/up/docs/grid.md"
cat > "$TMP/up/.claude/skills/run-thing/SKILL.md" <<'S'
---
name: run-thing
description: Run the thing.
---
Read [grid](../../../docs/grid.md) and [sibling](./notes.md) and [dot](../../../.hidden).
S
echo "notes" > "$TMP/up/.claude/skills/run-thing/notes.md"
git -C "$TMP/up" init -q && git -C "$TMP/up" add -A && git -C "$TMP/up" commit -qm up
mkdir -p "$TMP/srv" && git clone -q --bare "$TMP/up" "$TMP/srv/thing.git"

# --- the registry ------------------------------------------------------------
export STACK_REGISTRY="$TMP/reg"
mkdir -p "$STACK_REGISTRY/general/packages/thing" "$STACK_REGISTRY/general/packages/plain/skills/plain-skill" "$STACK_REGISTRY/general/packages/lib"
cat > "$STACK_REGISTRY/general/packages/thing/package.conf" <<'C'
KIND=toolkit
REFERENCE=private:thing
REF=main
DEP=
SKILLS_FROM_REFERENCE=.claude/skills
NOTE="A thing, run as scripts."
C
echo "# thing rule" > "$STACK_REGISTRY/general/packages/thing/rule.md"
cat > "$STACK_REGISTRY/general/packages/plain/package.conf" <<'C'
KIND=cli
NOTE="Skills only, no source."
C
printf -- '---\nname: plain-skill\ndescription: x\n---\nbody\n' > "$STACK_REGISTRY/general/packages/plain/skills/plain-skill/SKILL.md"
cat > "$STACK_REGISTRY/general/packages/lib/package.conf" <<'C'
KIND=lib
DEP=left-pad@1.3.0
NOTE="A library."
C
mkdir -p "$STACK_REGISTRY/general/packages/lib/files/src/core"
echo "export const one = 1" > "$STACK_REGISTRY/general/packages/lib/files/src/core/lib.ts"
echo "# lib rule" > "$STACK_REGISTRY/general/packages/lib/rule.md"
mkdir -p "$STACK_REGISTRY/general/packages/ui"
cat > "$STACK_REGISTRY/general/packages/ui/package.conf" <<'C'
KIND=lib
SKILLS_ADD=acme/ui
SKILLS_PICK=ui
SETUP="npx acme init"
NOTE="Skills through skills.sh."
C
# skills.sh, shimmed: records its argv, writes the skill and the lockfile the
# way the real CLI does under --agent claude-code --copy.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/skills-shim" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SKILLS_LOG:?}"
case "$1" in
  add)
    pkg=$2; pick=""; while [ $# -gt 0 ]; do [ "$1" = --skill ] && pick=$2; shift; done
    [ "$pick" = '*' ] && pick="ui,ui-migrate"
    node -e '
const fs=require("fs"),[pkg,pick]=process.argv.slice(1);
const l=fs.existsSync("skills-lock.json")?JSON.parse(fs.readFileSync("skills-lock.json","utf8")):{version:1,skills:{}};
for (const s of pick.split(",")) {
  fs.mkdirSync(`.claude/skills/${s}`,{recursive:true});
  fs.writeFileSync(`.claude/skills/${s}/SKILL.md`,`---\nname: ${s}\ndescription: x\n---\nfrom ${pkg}\n`);
  l.skills[s]={source:pkg,sourceType:"github",skillPath:`skills/${s}/SKILL.md`,computedHash:"h"};
}
fs.writeFileSync("skills-lock.json",JSON.stringify(l,null,2)+"\n");' "$pkg" "$pick" ;;
  update)
    # like skills 1.x: refreshed content, but as .agents/skills/<s> + a symlink
    shift; for s in "$@"; do
      case "$s" in -*) continue ;; esac
      mkdir -p .agents/skills; rm -rf ".agents/skills/$s"; mv ".claude/skills/$s" ".agents/skills/$s"
      echo "updated" >> ".agents/skills/$s/SKILL.md"; ln -s "../../.agents/skills/$s" ".claude/skills/$s"
    done ;;
  remove)
    s=""; while [ $# -gt 0 ]; do [ "$1" = --skill ] && s=$2; shift; done
    node -e '
const fs=require("fs"),l=JSON.parse(fs.readFileSync("skills-lock.json","utf8"));
delete l.skills[process.argv[1]]; fs.writeFileSync("skills-lock.json",JSON.stringify(l,null,2)+"\n");' "$s"
    rm -rf ".claude/skills/$s" ;;
esac
SHIM
chmod +x "$TMP/bin/skills-shim"
export STACK_SKILLS_CMD="$TMP/bin/skills-shim" SKILLS_LOG="$TMP/skills.log"

# --- the project -------------------------------------------------------------
P="$TMP/proj"; mkdir -p "$P"; cd "$P"
git init -q
echo "# proj" > CLAUDE.md
git add -A && git commit -qm scaffold

echo "== list / show"
out=$("$STACK" list); check grep -q '^general$' <<< "$out"; check grep -q '^  thing *toolkit' <<< "$out"
out=$("$STACK" show thing); check grep -q "subtree: repos/thing from file://$TMP/srv/thing.git (main)" <<< "$out"
check not "$STACK" show nope
# private.root unset: refused with the reason, before anything reaches stdout
check bash -c "HOME='$TMP/nohome' '$STACK' show thing 2>&1 >/dev/null | grep -q 'private.root is unset'"
check test -z "$(HOME="$TMP/nohome" "$STACK" show thing 2>/dev/null)"

echo "== add refuses without a source commit / on a dirty tree"
echo x > dirty; git add dirty
check not "$STACK" add thing
git reset -q dirty && rm dirty

echo "== add thing (subtree + rule + skills from source)"
out=$("$STACK" add thing)
check test -f repos/thing/README.md
check test -f .claude/rules/thing.md
check test -f .claude/skills/run-thing/SKILL.md
check grep -q '\](../../../repos/thing/docs/grid.md)' .claude/skills/run-thing/SKILL.md
check grep -q '\](./notes.md)' .claude/skills/run-thing/SKILL.md
check grep -q '\](../../../\.hidden)' .claude/skills/run-thing/SKILL.md
check grep -q "^thing|repos/thing|.claude/rules/thing.md|run-thing$" .claude/stack.conf
check grep -q '<!-- stack:start -->' CLAUDE.md
# shellcheck disable=SC2016
check grep -q '^- \*\*thing\*\* (toolkit) — A thing, run as scripts. Reference `repos/thing`. Rule `.claude/rules/thing.md`. Skills `run-thing`.' CLAUDE.md
check grep -q '^# proj' CLAUDE.md
check grep -q 'Commit: .stack: add thing.' <<< "$out"
git add -A && git commit -qm "stack: add thing"

echo "== add is idempotent, subtree kept, block not duplicated"
"$STACK" add thing >/dev/null
check test "$(grep -c 'stack:start' CLAUDE.md)" = 1
check test "$(grep -c '^thing' .claude/stack.conf)" = 1
check test -z "$(git status --porcelain)"

echo "== add plain (skills only) and lib (dep, no ts-gate → no knip)"
cat > "$TMP/bin-npm" <<'N'
#!/usr/bin/env bash
echo "npm $*" >> "${NPM_LOG:?}"
N
chmod +x "$TMP/bin-npm"; mkdir -p "$TMP/bin"; cp "$TMP/bin-npm" "$TMP/bin/npm"
export NPM_LOG="$TMP/npm.log"; PATH="$TMP/bin:$PATH"
"$STACK" add plain lib >/dev/null
check test -f .claude/skills/plain-skill/SKILL.md
check grep -q '^plain|||plain-skill$' .claude/stack.conf
check grep -q '^npm i -E left-pad@1.3.0$' "$NPM_LOG"
check test -f .claude/rules/lib.md
check grep -q 'one = 1' src/core/lib.ts
check test "$(grep -c '^- \*\*' CLAUDE.md)" = 3
git add -A && git commit -qm "stack: add plain lib"

echo "== files/: the project's from the first copy; add and update keep an existing one"
echo "export const one = 2" > src/core/lib.ts; git commit -qam mine
"$STACK" add lib >/dev/null; check grep -q 'one = 2' src/core/lib.ts
"$STACK" update lib >/dev/null; check grep -q 'one = 2' src/core/lib.ts
"$STACK" show lib > "$TMP/show.txt"; check grep -q '^file:    src/core/lib.ts' "$TMP/show.txt"

echo "== eslint.mjs: copied to .claude/eslint/<name>.mjs, named in the block, status, update drops it with the registry, rm removes it"
mkdir -p "$STACK_REGISTRY/general/packages/linted"
printf 'KIND=lib\nNOTE="Linted."\n' > "$STACK_REGISTRY/general/packages/linted/package.conf"
echo 'export default [];' > "$STACK_REGISTRY/general/packages/linted/eslint.mjs"
"$STACK" show linted > "$TMP/show.txt"; check grep -q '^lint:    .claude/eslint/linted.mjs' "$TMP/show.txt"
"$STACK" add linted >/dev/null
check cmp -s "$STACK_REGISTRY/general/packages/linted/eslint.mjs" .claude/eslint/linted.mjs
check grep -q '^linted|||$' .claude/stack.conf
# shellcheck disable=SC2016
check grep -q '^- \*\*linted\*\* (lib) — Linted. Lint `.claude/eslint/linted.mjs`.$' CLAUDE.md
out=$("$STACK" status); check grep -q '^linted *ok' <<< "$out"
echo '// edited' >> .claude/eslint/linted.mjs
out=$("$STACK" status); check grep -q 'linted *.claude/eslint/linted.mjs differs' <<< "$out"
"$STACK" update linted >/dev/null
check cmp -s "$STACK_REGISTRY/general/packages/linted/eslint.mjs" .claude/eslint/linted.mjs
rm "$STACK_REGISTRY/general/packages/linted/eslint.mjs"
out=$("$STACK" status); check grep -q 'linted *.claude/eslint/linted.mjs has no source' <<< "$out"
"$STACK" update linted >/dev/null
check not test -e .claude/eslint
check not grep -q '^- \*\*linted\*\*.* Lint ' CLAUDE.md
echo 'export default [];' > "$STACK_REGISTRY/general/packages/linted/eslint.mjs"
"$STACK" update linted >/dev/null
check test -f .claude/eslint/linted.mjs
"$STACK" rm linted >/dev/null
check not test -e .claude/eslint
check not grep -q '\*\*linted\*\*' CLAUDE.md

echo "== add ui (skills.sh): flags answer every prompt, lock read back, setup printed not run"
out=$("$STACK" add ui)
check grep -q '^add acme/ui --agent claude-code --skill ui -y --copy$' "$SKILLS_LOG"
check test -f .claude/skills/ui/SKILL.md
check not test -d .claude/skills/ui-migrate
check grep -q '^ui|||ui$' .claude/stack.conf
check grep -q 'next    npx acme init' <<< "$out"
check grep -q '"ui"' skills-lock.json
out=$("$STACK" status); check grep -q '^ui *ok' <<< "$out"
git add -A && git commit -qm "stack: add ui"

echo "== update ui goes through 'skills update' and folds the symlink back into a copy"
"$STACK" update ui >/dev/null
check grep -q '^update ui -p -y$' "$SKILLS_LOG"
check not test -L .claude/skills/ui
check test -d .claude/skills/ui
check grep -q updated .claude/skills/ui/SKILL.md
check not test -e .agents
check test "$(grep -c '^add acme/ui' "$SKILLS_LOG")" = 1
git add -A && git commit -qm "stack: update ui"
"$STACK" rm ui >/dev/null
check not test -d .claude/skills/ui
check not grep -q '"ui"' skills-lock.json
check grep -q '^remove --skill ui -y$' "$SKILLS_LOG"
git add -A && git commit -qm "stack: rm ui"

echo "== dep goes into knip ignoreDependencies when ts-gate is present"
mkdir -p ts-gate && echo '{"ignoreDependencies":["effect"]}' > ts-gate/knip.json
git add -A && git commit -qm knip
"$STACK" add lib >/dev/null
check grep -q '"left-pad"' ts-gate/knip.json
check grep -q '"effect"' ts-gate/knip.json
check grep -q '"src/core/lib.ts"' ts-gate/knip.json   # the kept file's row too: the gate came after the package
echo '{"ignoreDependencies":["effect"]}' > ts-gate/knip.json
"$STACK" update lib >/dev/null
check grep -q '"left-pad"' ts-gate/knip.json
check grep -q '"src/core/lib.ts"' ts-gate/knip.json
rm src/core/lib.ts; git commit -qam "drop the file"
"$STACK" add lib >/dev/null
check grep -q 'one = 1' src/core/lib.ts
check grep -q '"src/core/lib.ts"' ts-gate/knip.json
git add -A && git commit -qm "knip lib"

echo "== NEEDS: child pulls base in first, dev dep with -D, both in knip; rm base refused while child is added"
mkdir -p "$STACK_REGISTRY/general/packages/base" "$STACK_REGISTRY/general/packages/child" "$STACK_REGISTRY/general/packages/presets/bundle" "$STACK_REGISTRY/general/packages/presets/empty"
printf 'KIND=lib\nDEP=base-pkg@1.0.0\nDEV_DEP="base-dev@2.0.0 base-dev2@2.0.0"\nNOTE="Base."\n' > "$STACK_REGISTRY/general/packages/base/package.conf"
echo "# base rule" > "$STACK_REGISTRY/general/packages/base/rule.md"
printf 'KIND=lib\nNEEDS=base\nNOTE="Child."\n' > "$STACK_REGISTRY/general/packages/child/package.conf"
echo "# child rule" > "$STACK_REGISTRY/general/packages/child/rule.md"
printf 'KIND=preset\nNEEDS="child plain"\nNOTE="Preset."\n' > "$STACK_REGISTRY/general/packages/presets/bundle/package.conf"
printf 'KIND=preset\nNOTE="Nothing."\n' > "$STACK_REGISTRY/general/packages/presets/empty/package.conf"
out=$("$STACK" show child); check grep -q '^needs:   base  (add order: base child)$' <<< "$out"
out=$("$STACK" show bundle); check grep -q '(add order: base child plain)$' <<< "$out"
out=$("$STACK" add child)
check grep -q '^base: needed, added first$' <<< "$out"
check test -f .claude/rules/base.md
check test -f .claude/rules/child.md
check grep -q '^npm i -E base-pkg@1.0.0$' "$NPM_LOG"
check grep -q '^npm i -D -E base-dev@2.0.0 base-dev2@2.0.0$' "$NPM_LOG"
check grep -q '"base-pkg"' ts-gate/knip.json
check grep -q '"base-dev2"' ts-gate/knip.json
check grep -q "Commit: 'stack: add base child'" <<< "$out"
git add -A && git commit -qm "stack: add child"
check not "$STACK" rm base
check test -f .claude/rules/base.md
"$STACK" rm child >/dev/null && "$STACK" rm base >/dev/null
check not test -f .claude/rules/base.md
git add -A && git commit -qm "stack: rm child base"

echo "== preset: expands, is not recorded; plain already added is kept"
out=$("$STACK" add bundle)
check grep -q '^child|' .claude/stack.conf
check grep -q '^base|' .claude/stack.conf
check not grep -q '^bundle' .claude/stack.conf
check not grep -q '\*\*bundle\*\*' CLAUDE.md
check test "$(grep -c '^plain|' .claude/stack.conf)" = 1
check grep -q "Commit: 'stack: add base child'" <<< "$out"
check not "$STACK" add empty
"$STACK" rm child >/dev/null && "$STACK" rm base >/dev/null
check test -z "$(git status --porcelain)"   # add then rm of both leaves the tree as committed

echo "== status: ok, then differs"
out=$("$STACK" status); check grep -q '^thing *ok' <<< "$out"; check grep -q '^plain *ok' <<< "$out"
echo "edited" >> .claude/rules/thing.md
echo "edited" >> .claude/skills/run-thing/SKILL.md
out=$("$STACK" status)
check grep -q 'thing *.claude/rules/thing.md differs' <<< "$out"
check grep -q 'thing *.claude/skills/run-thing differs' <<< "$out"
check not grep -q '^thing *ok' <<< "$out"
git checkout -q -- .claude

echo "== update pulls the subtree and re-copies"
echo "more grid facts" >> "$TMP/up/docs/grid.md"
git -C "$TMP/up" commit -qam more && git -C "$TMP/up" push -q "$TMP/srv/thing.git" main
echo "edited" >> .claude/rules/thing.md; git commit -qam edit
"$STACK" update thing >/dev/null
check grep -q "more grid facts" repos/thing/docs/grid.md
check not grep -q edited .claude/rules/thing.md
git add -A && git commit -qm "stack: update thing"

echo "== rm"
"$STACK" rm thing >/dev/null
check not test -d repos/thing
check not test -f .claude/rules/thing.md
check not test -d .claude/skills/run-thing
check not grep -q '^thing' .claude/stack.conf
check not grep -q '\*\*thing\*\*' CLAUDE.md
check grep -q '\*\*plain\*\*' CLAUDE.md
check not "$STACK" rm thing

echo "== add a b: a's manifest row dirties a tracked file, b's subtree still lands"
"$STACK" rm plain >/dev/null; git add -A && git commit -qm "rm plain"   # stack.conf is tracked now
check "$STACK" add plain thing
check test -f repos/thing/README.md
check test -f .claude/skills/plain-skill/SKILL.md
check grep -q '^thing|repos/thing|' .claude/stack.conf
check grep -q '^plain|||plain-skill$' .claude/stack.conf
"$STACK" rm thing >/dev/null   # the next section commits

echo "== a CLAUDE.md that is a symlink is edited in place"
git add -A && git commit -qm rm
mv CLAUDE.md AGENTS.md && ln -s AGENTS.md CLAUDE.md && git add -A && git commit -qm symlink
"$STACK" add thing >/dev/null
check test -L CLAUDE.md
check grep -q '\*\*thing\*\*' AGENTS.md

echo "== pins are exact and 'update' re-applies a bumped DEP (A7)"
sed -i 's/^DEP=left-pad@1.3.0/DEP=left-pad@1.3.1/' "$STACK_REGISTRY/general/packages/lib/package.conf"
: > "$NPM_LOG"
"$STACK" update lib >/dev/null
check grep -q '^npm i -E left-pad@1.3.1$' "$NPM_LOG"

echo "== a failed dependency install is named, visible in status, and the rerun completes (B3)"
git add -A && git commit -qm "stack: add thing"
mkdir -p "$STACK_REGISTRY/general/packages/half"
cat > "$STACK_REGISTRY/general/packages/half/package.conf" <<'C'
KIND=lib
REFERENCE=private:thing
REF=main
DEP=nope@1.0.0
NOTE="Half."
C
echo "# half rule" > "$STACK_REGISTRY/general/packages/half/rule.md"
cat > "$TMP/bin/npm" <<'N'
#!/usr/bin/env bash
echo "npm $*" >> "${NPM_LOG:?}"
[ -z "${NPM_FAIL:-}" ] || { echo "npm ERR! ERESOLVE" >&2; exit 1; }
N
: > "$NPM_LOG"
NPM_FAIL=1 "$STACK" add half > "$TMP/half.out" 2>&1 && echo "add returned 0" >> "$TMP/half.out"
check grep -q 'half-added' "$TMP/half.out"
check grep -q "rerun 'stack add half'" "$TMP/half.out"
check test -d repos/half
check not grep -q '^half|' .claude/stack.conf
"$STACK" status > "$TMP/status.out" 2>&1 || true
check grep -q 'repos/half has no manifest row' "$TMP/status.out"
"$STACK" add half thing > "$TMP/half2.out" 2>&1 || true
check grep -q '^half|repos/half|' .claude/stack.conf
check grep -q '^npm i -E nope@1.0.0$' "$NPM_LOG"
check grep -q "Commit: 'stack: add half'$" "$TMP/half2.out"
git add -A && git commit -qm "stack: add half"

echo "== add refuses a dirty tracked tree before it commits anything (B3)"
echo dirty >> AGENTS.md
check bash -c "'$STACK' add plain 2>&1 | grep -q 'uncommitted changes'"
check test -z "$(git log --oneline -1 | grep -v 'stack: add half')"
git checkout -q -- AGENTS.md

echo "== sections: NEEDS stay in the language, in the section or shared; a preset any section"
R="$STACK_REGISTRY"
mkdir -p "$R/lang/packages/shared/core" "$R/lang/packages/back/db" "$R/lang/packages/front/ui2" "$R/lang/packages/presets/app" "$R/lang/packages/back/bad" "$R/lang/packages/back/cross" "$R/general/packages/far"
printf 'KIND=lib\nNOTE="Core."\n' > "$R/lang/packages/shared/core/package.conf"
printf 'KIND=lib\nNEEDS=core\nNOTE="Db."\n' > "$R/lang/packages/back/db/package.conf"
printf 'KIND=lib\nNEEDS=core\nNOTE="Ui."\n' > "$R/lang/packages/front/ui2/package.conf"
printf 'KIND=preset\nNEEDS="db ui2"\nNOTE="App."\n' > "$R/lang/packages/presets/app/package.conf"
printf 'KIND=lib\nNEEDS=ui2\nNOTE="Bad."\n' > "$R/lang/packages/back/bad/package.conf"
printf 'KIND=lib\nNEEDS=plain\nNOTE="Cross."\n' > "$R/lang/packages/back/cross/package.conf"
printf 'KIND=lib\nNEEDS=core\nNOTE="Far."\n' > "$R/general/packages/far/package.conf"
out=$("$STACK" list)
check grep -q '^lang/back$' <<< "$out"
check grep -q '^  db  *lib  *Db.$' <<< "$out"
out=$("$STACK" show db); check grep -q '^in:      lang/back$' <<< "$out"; check grep -q '(add order: core db)$' <<< "$out"
out=$("$STACK" show app); check grep -q '(add order: core db ui2)$' <<< "$out"
check bash -c "'$STACK' show bad 2>&1 | grep -q 'bad (lang/back) needs ui2 (lang/front)'"
check bash -c "'$STACK' show cross 2>&1 | grep -q 'cross (lang/back) needs plain (general)'"
check bash -c "'$STACK' show far 2>&1 | grep -q 'far (general) needs core (lang/shared)'"
check not "$STACK" add bad
check test -z "$(git status --porcelain)"
# A preset outside presets/ would let a backend package reach frontend through it.
mkdir -p "$R/lang/packages/shared/bundle2" "$R/lang/packages/back/api" "$R/lang/packages/presets/notpreset"
printf 'KIND=preset\nNEEDS=ui2\nNOTE="Preset in shared."\n' > "$R/lang/packages/shared/bundle2/package.conf"
printf 'KIND=lib\nNEEDS=bundle2\nNOTE="Api."\n' > "$R/lang/packages/back/api/package.conf"
printf 'KIND=lib\nNOTE="Not a preset."\n' > "$R/lang/packages/presets/notpreset/package.conf"
check bash -c "'$STACK' show bundle2 2>&1 | grep -q 'bundle2 is KIND=preset in lang/shared'"
check bash -c "'$STACK' show api 2>&1 | grep -q 'bundle2 is KIND=preset in lang/shared'"
check not "$STACK" add api
check bash -c "'$STACK' show notpreset 2>&1 | grep -q 'notpreset is in lang/presets without KIND=preset'"
check test -z "$(git status --porcelain)"
rm -rf "$R/lang/packages/shared/bundle2" "$R/lang/packages/back/api" "$R/lang/packages/presets/notpreset"
# add, status and rm across groups: db (lang/back) needs core (lang/shared).
out=$("$STACK" add db)
check grep -q '^core: needed, added first$' <<< "$out"
out=$("$STACK" status); check grep -q '^core *ok' <<< "$out"; check grep -q '^db *ok' <<< "$out"
git add -A && git commit -qm "stack: add core db"
check bash -c "'$STACK' rm core 2>&1 | grep -q 'db needs core'"
check grep -q '^core|' .claude/stack.conf
"$STACK" rm db >/dev/null && "$STACK" rm core >/dev/null
check not grep -qE '^(core|db)\|' .claude/stack.conf
git add -A && git commit -qm "stack: rm db core"
mkdir -p "$R/lang/packages/front/plain" && printf 'KIND=lib\nNOTE="Twin."\n' > "$R/lang/packages/front/plain/package.conf"
check bash -c "'$STACK' show plain 2>&1 | grep -q 'in the registry twice'"
check bash -c "'$STACK' list 2>&1 | grep -q 'in the registry twice: plain'"
rm -rf "$R/lang" "$R/general/packages/far"

echo "== the shipped registry: every package found once, every NEEDS inside the section rule"
names=$(STACK_REGISTRY='' "$STACK" list | sed -n 's/^  \([^ ]*\).*/\1/p')
# Every package.conf is listed: one placed a level too deep would be missing.
WORKSHOP=$(readlink -f "$(dirname "$STACK")/../..")
check test "$(wc -w <<< "$names")" -eq "$(find "$WORKSHOP"/*/packages -name package.conf | wc -l)"
# No stack: error either; a die inside $(...) prints without failing show.
for n in $names; do check bash -c "STACK_REGISTRY='' '$STACK' show '$n' >/dev/null 2>'$TMP/show.err' && test ! -s '$TMP/show.err'"; done

echo "== rm drops the knip names it added and the block when nothing is left; modes survive (C6, C7)"
mkdir -p "$TMP/p3/src" && cd "$TMP/p3" && git init -q && echo '{"name":"p3"}' > package.json && mkdir -p ts-gate && echo '{"ignore":[],"ignoreDependencies":[]}' > ts-gate/knip.json && printf '# p3\n\nhand-written\n' > CLAUDE.md && git add -A && git commit -qm scaffold
"$STACK" add lib >/dev/null
check test "$(stat -c %a CLAUDE.md)" = 644
check test "$(stat -c %a .claude/stack.conf)" = 644
check grep -q '"left-pad"' ts-gate/knip.json
git add -A && git commit -qm "stack: add lib"
"$STACK" rm lib >/dev/null
check not grep -q '"left-pad"' ts-gate/knip.json
check not grep -q '## Stack' CLAUDE.md
check grep -q 'hand-written' CLAUDE.md

if [ "$fail" -eq 0 ]; then echo "all passed"; else echo "FAILURES"; exit 1; fi
