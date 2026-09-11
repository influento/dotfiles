#!/usr/bin/env bash
# End-to-end tests for the stack CLI, in a throwaway project against a
# throwaway registry and a local bare "private" repository.
# Plain bash, no framework. Run: bash tests/stack.sh
set -euo pipefail

STACK=$(readlink -f "$(dirname "$0")/../bin/stack")
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
export STACK_ROOT="$TMP/reg"
mkdir -p "$STACK_ROOT/packages/thing" "$STACK_ROOT/packages/plain/skills/plain-skill" "$STACK_ROOT/packages/lib"
cat > "$STACK_ROOT/packages/thing/package.conf" <<'C'
KIND=toolkit
REFERENCE=private:thing
REF=main
DEP=
SKILLS_FROM_REFERENCE=.claude/skills
NOTE="A thing, run as scripts."
C
echo "# thing rule" > "$STACK_ROOT/packages/thing/rule.md"
cat > "$STACK_ROOT/packages/plain/package.conf" <<'C'
KIND=cli
NOTE="Skills only, no source."
C
printf -- '---\nname: plain-skill\ndescription: x\n---\nbody\n' > "$STACK_ROOT/packages/plain/skills/plain-skill/SKILL.md"
cat > "$STACK_ROOT/packages/lib/package.conf" <<'C'
KIND=lib
DEP=left-pad@1.3.0
NOTE="A library."
C
echo "# lib rule" > "$STACK_ROOT/packages/lib/rule.md"
mkdir -p "$STACK_ROOT/packages/ui"
cat > "$STACK_ROOT/packages/ui/package.conf" <<'C'
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
out=$("$STACK" list); check grep -q '^thing *toolkit' <<< "$out"
out=$("$STACK" show thing); check grep -q "subtree: repos/thing from file://$TMP/srv/thing.git (main)" <<< "$out"
check not "$STACK" show nope

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
check grep -q '^npm i left-pad@1.3.0$' "$NPM_LOG"
check test -f .claude/rules/lib.md
check test "$(grep -c '^- \*\*' CLAUDE.md)" = 3
git add -A && git commit -qm "stack: add plain lib"

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
git add -A && git commit -qm "knip lib"

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

if [ "$fail" -eq 0 ]; then echo "all passed"; else echo "FAILURES"; exit 1; fi
