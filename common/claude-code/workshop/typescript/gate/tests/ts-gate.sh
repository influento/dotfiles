#!/usr/bin/env bash
# End-to-end tests for ts-gate in a scratch project. npm, npx and the tools are
# shimmed and logged: what install writes and what the gate *invokes* is the
# behaviour under test, not what tsc says about a file. Plain bash, no
# framework. Run: bash tests/ts-gate.sh
set -euo pipefail

SRC=$(readlink -f "$(dirname "$0")/..")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export HOME="$TMP/home" TMPDIR="$TMP/tmpdir"
mkdir -p "$HOME" "$TMP/bin" "$TMPDIR"
git config --global init.defaultBranch main
REAL_NPM=$(command -v npm)
export REAL_NPM TSGATE_TEST="$TMP" LOG="$TMP/calls.log"
export PATH="$TMP/bin:$PATH"
: > "$LOG"

fails=0 checks=0
pass() { checks=$((checks + 1)); echo "ok   $1"; }
fail() { checks=$((checks + 1)); fails=$((fails + 1)); echo "FAIL $1" >&2; }
check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }
# run <label> <rc> <pattern> <cmd...>: rc must match; pattern grepped over stdout+stderr.
run() {
  local label="$1" want="$2" pat="$3"; shift 3
  local out rc=0
  out=$("$@" 2>&1) || rc=$?
  if [ "$rc" -ne "$want" ]; then fail "$label: rc=$rc, wanted $want"; printf '%s\n' "$out" | sed 's/^/     /' >&2; return; fi
  if [ -n "$pat" ] && ! grep -qE -- "$pat" <<<"$out"; then fail "$label: output lacks /$pat/"; printf '%s\n' "$out" | sed 's/^/     /' >&2; return; fi
  pass "$label"
}
called() { grep -q "^$1" "$LOG"; }
not_called() { ! grep -q "^$1" "$LOG"; }
# lacks <text> <pattern>: no line of the text matches.
lacks() { ! grep -q -- "$2" <<< "$1"; }
json() { node -p "const j=require('$PWD/$1'); $2"; }
# same_json <file> <rev>: the file parses to what it held at that commit (npm
# pkg and the shim pretty-print, so bytes are not the measure).
same_json() { node -e 'const fs=require("fs"),a=JSON.parse(fs.readFileSync(process.argv[1],"utf8")),b=JSON.parse(process.argv[2]);process.exit(JSON.stringify(a)===JSON.stringify(b)?0:1)' "$1" "$(git show "$2:$1")"; }

# --- shims -------------------------------------------------------------------
# npm: 'i' and 'rm' edit package.json the way the real one would; everything
# else (pkg set, run) is the real npm, which needs no node_modules for those.
cat > "$TMP/bin/npm" <<'N'
#!/usr/bin/env bash
echo "npm $*" >> "$LOG"
case "${1:-}" in
  i|install|rm|uninstall)
    op=$1; shift; dev=0; specs=()
    for a in "$@"; do case "$a" in -D|--save-dev) dev=1 ;; -*) ;; *) specs+=("$a") ;; esac; done
    node -e '
const fs=require("fs"),p=JSON.parse(fs.readFileSync("package.json","utf8")),[op,dev,...specs]=process.argv.slice(1);
const k=dev==="1"?"devDependencies":"dependencies";p[k]??={};
for(const s of specs){const m=s.match(/^(@?[^@]+)(?:@(.*))?$/);if(op==="i"||op==="install")p[k][m[1]]="^"+(m[2]||"0.0.0");else{delete p.dependencies?.[m[1]];delete p.devDependencies?.[m[1]];}}
fs.writeFileSync("package.json",JSON.stringify(p,null,2)+"\n");' "$op" "$dev" "${specs[@]}" ;;
  ci) ;;
  *) exec "$REAL_NPM" "$@" ;;
esac
N
# npx: the tool by name from the same bin, logged as the tool.
cat > "$TMP/bin/npx" <<'N'
#!/usr/bin/env bash
exec "$(dirname "$0")/$1" "${@:2}"
N
# The tools: exit 0, except on the file verify.sh seeds, where each reports
# exactly the finding verify greps for. eslint --print-config prints the file
# the test points ESLINT_CONFIG at.
cat > "$TMP/bin/tool" <<'T'
#!/usr/bin/env bash
t=$(basename "$0"); echo "$t $*" >> "$LOG"
F=src/__gate_verify__.ts
case "$t" in
  eslint) case " $* " in *" --print-config "*) cat "$ESLINT_CONFIG"; exit 0 ;; esac
          [ -f "$F" ] && { echo "$F:3:9: 'dead' is assigned a value but never used [Error/@typescript-eslint/no-unused-vars]"; exit 1; } ;;
  tsc)    # --listFilesOnly: every .ts under tsconfig's first include, or the whole tree without one;
          # no dot-path, which tsc's default include skips.
          case " $* " in *" --listFilesOnly "*)
            inc=$(node -p 'const i=require("./tsconfig.json").include; i ? "/" + i[0] : ""')
            find "$PWD$inc" -name '*.ts' -not -path '*/node_modules/*' -not -path "$PWD/.*" -not -path "$PWD/*/.*"; exit 0 ;; esac
          [ -f "$F" ] && { echo "$F(2,9): error TS2322: Type 'string' is not assignable to type 'number'."; exit 1; } ;;
  knip)   [ -f "$F" ] && { echo "Unused exports (1)"; echo "add  $F"; exit 1; } ;;
esac
[ -f "$TSGATE_TEST/exit.$t" ] && exit "$(cat "$TSGATE_TEST/exit.$t")"
exit 0
T
# claude, for verify.sh step 4: the hook blocked, the model removed the file.
cat > "$TMP/bin/claude" <<'C'
#!/usr/bin/env bash
echo "claude $*" >> "$LOG"
echo '{"type":"user","content":"Gate failed. Fix before finishing:"}'
rm -f src/__gate_verify__.ts
C
chmod +x "$TMP"/bin/*
for t in tsc eslint biome knip depcruise vitest; do ln -s "$TMP/bin/tool" "$TMP/bin/$t"; done
export ESLINT_CONFIG="$TMP/eslint-config.json"
echo '{"rules":{"no-unused-vars":["error"],"gate/no-unknown-signature":["error"]}}' > "$ESLINT_CONFIG"

# --- a scratch project --------------------------------------------------------
# mkproj <dir> [devDependencies-json]
mkproj() {
  mkdir -p "$1/src" "$1/node_modules"
  cd "$1"
  git init -q
  printf '{"name":"p","version":"1.0.0","engines":{"node":">=26"},"devDependencies":%s}\n' "${2:-{\}}" > package.json
  echo '{"compilerOptions":{"strict":true,"noUncheckedIndexedAccess":true,"noEmit":true,"target":"es2024","module":"nodenext"},"include":["src"]}' > tsconfig.json
  echo 'export const x = 1;' > src/index.ts
  echo 'node_modules/' > .gitignore
  git add -A && git commit -qm scaffold
}

echo "== install: greenfield with no test runner"
mkproj "$TMP/p1"
run "install succeeds" 0 "installed. runner: none" bash "$SRC/install.sh" .
run "install warns that the gate will run no tests" 0 "WARNING: no test runner" bash "$SRC/install.sh" .
check "the gate script is in the project" test -f ts-gate/scripts/gate.sh
check "the manifest records no runner" [ "$(json ts-gate/.install.json 'j.runner')" = "" ]
check "the manifest lists the deps install added" [ "$(json ts-gate/.install.json 'j.deps.includes("knip")')" = true ]
check "knip ignores repos/** and .worktrees/**" bash -c "grep -q 'repos/\*\*' ts-gate/knip.json && grep -q '\.worktrees/\*\*' ts-gate/knip.json"
check "no runner: knip.json has no vitest key" [ "$(json ts-gate/knip.json '"vitest" in j')" = false ]
check "allow rules name the gate scripts a worker may run" bash -c "grep -q 'Bash(npm run gate:local)' .claude/settings.json && grep -q 'Bash(npm run gate:fix)' .claude/settings.json"
check "allow rules do not cover gate:verify, which runs a model" bash -c "! grep -q 'npm run gate:\*' .claude/settings.json"
check "premerge is written to .claude/workshop.conf" grep -qx 'premerge=npm run gate' .claude/workshop.conf
check "and not to git config" bash -c "! git config --get workbench.premerge"
check "the Stop hook is added with a 600 s timeout" [ "$(json .claude/settings.json 'j.hooks.Stop.flatMap(e=>e.hooks).find(h=>h.command==="bash ts-gate/scripts/stop-hook.sh").timeout')" = 600 ]
check "guards name the gate and tsc" bash -c "git config workbench.guards | grep -q 'npm run (gate' && git config workbench.guards | grep -q tsc"
git add -A && git commit -qm "ts-gate: install"

echo "== the installer, the rules and the tests stay in the source; a copy left by an older install refuses to run"
for f in install.sh uninstall.sh biome.template.json knip.vitest.json rules tests CLAUDE.md; do check "ts-gate/$f is not copied into the project" test ! -e "ts-gate/$f"; done
check "the rules landed in .claude/rules" test -f .claude/rules/ts-lean-code.md
cp "$SRC/install.sh" ts-gate/install.sh
run "the project copy refuses to run" 1 "dotfiles source" bash ts-gate/install.sh .
check "the project copy is intact" test -f ts-gate/scripts/gate.sh
rm ts-gate/install.sh
check "the tree is clean" [ -z "$(git status --porcelain)" ]
git checkout -q -- . && git clean -fdq

echo "== gate in CI mode on a branch that changes no .ts file"
git checkout -qb cfg
sed -i 's/"es2024"/"ES9999"/' tsconfig.json && git commit -qam "break tsconfig"
: > "$LOG"
run "gate in CI mode still runs" 0 "" bash ts-gate/scripts/gate.sh
check "tsc ran repo-wide" called tsc
check "knip ran" called knip
check "depcruise ran" called depcruise
check "eslint did not run on zero files" not_called eslint
check "biome did not run on zero files" not_called biome
: > "$LOG"
run "gate --local on the same branch runs tsc: a config changed" 0 "" bash ts-gate/scripts/gate.sh --local
check "tsc ran under --local for the config change" called tsc
git checkout -q main
: > "$LOG"
run "gate --local on a clean tree exits fast" 0 "no TS" bash ts-gate/scripts/gate.sh --local
check "nothing ran on the clean tree" [ ! -s "$LOG" ]
git checkout -qb docs && echo x > README.md && git add README.md && git commit -qm docs
: > "$LOG"
run "gate --local on a docs-only branch exits fast" 0 "no TS" bash ts-gate/scripts/gate.sh --local
check "nothing ran for docs" [ ! -s "$LOG" ]
: > "$LOG"
run "gate in CI mode on a docs-only branch runs the repo-wide tools" 0 "" bash ts-gate/scripts/gate.sh
check "tsc ran for CI on docs" called tsc
git checkout -q main
git checkout -qb lintcfg && mkdir -p .claude/eslint && echo 'export default [];' > .claude/eslint/x.mjs && git add .claude/eslint && git commit -qm lint
: > "$LOG"
run "gate --local on a branch that changes only a stack lint file runs the repo-wide tools" 0 "" bash ts-gate/scripts/gate.sh --local
check "tsc ran for the lint file" called tsc
git checkout -q main
# A workbench spike's prototypes live in its folder: never the project's code.
git checkout -qb spike && mkdir -p workbench/items/spikes/s-001-x && echo 'export const x = 1' > workbench/items/spikes/s-001-x/proto.ts \
  && git add workbench && git commit -qm spike
run "gate --list leaves out a spike's code" 0 "^$" bash -c "bash ts-gate/scripts/gate.sh --list; echo"
: > "$LOG"
run "gate --local on a spike-only branch exits fast" 0 "no TS" bash ts-gate/scripts/gate.sh --local
: > "$LOG"
run "gate in CI mode lints none of it" 0 "" bash ts-gate/scripts/gate.sh
check "eslint did not run on the spike's code" not_called eslint
check "knip, biome and the live tier ignore workbench/**" bash -c "grep -q '\"workbench/\*\*\"' ts-gate/knip.json && grep -q '\"!workbench/\*\*\"' biome.json && grep -q '\"workbench/\*\*\"' ts-gate/vitest.live.mjs"
check "the eslint config install writes ignores it" grep -q '"workbench/\*\*"' eslint.config.mjs
echo 'export const y = 1' > src/y.ts && git add src/y.ts && git commit -qm 'code beside it'
run "while code beside it is still listed" 0 "^src/y.ts$" bash ts-gate/scripts/gate.sh --list
git checkout -q main && git branch -q -D spike

git checkout -qb vitecfg && echo 'export default {};' > vite.config.mjs && git add vite.config.mjs && git commit -qm vite
: > "$LOG"
run "gate --local on a branch that changes only vite.config.mjs runs the repo-wide tools" 0 "" bash ts-gate/scripts/gate.sh --local
check "tsc ran for the vite config" called tsc
git checkout -q main

echo "== re-install keeps a project's premerge and a hand-set Stop hook timeout"
sed -i 's|^premerge=.*|premerge=bash scripts/premerge.sh|' .claude/workshop.conf
set_timeout() { node -e 'const fs=require("fs"),p=".claude/settings.json",s=JSON.parse(fs.readFileSync(p));for(const e of s.hooks.Stop)for(const h of e.hooks)if(h.command==="bash ts-gate/scripts/stop-hook.sh")h.timeout=Number(process.argv[1]);fs.writeFileSync(p,JSON.stringify(s,null,2)+"\n")' "$1"; }
stop_timeouts() { json .claude/settings.json 'j.hooks.Stop.flatMap(e=>e.hooks).filter(h=>h.command==="bash ts-gate/scripts/stop-hook.sh").map(h=>h.timeout).join(",")'; }
set_timeout 900
git add -A && git commit -qm "project premerge, longer stop timeout"

echo "== re-install after vitest arrives"
node -e 'const fs=require("fs"),p=JSON.parse(fs.readFileSync("package.json"));p.devDependencies["@effect/vitest"]="^4.0.0";fs.writeFileSync("package.json",JSON.stringify(p,null,2)+"\n")'
run "@effect/vitest alone is not a runner" 0 "runner: none" bash "$SRC/install.sh" .
node -e 'const fs=require("fs"),p=JSON.parse(fs.readFileSync("package.json"));p.devDependencies.vitest="^5.0.0";fs.writeFileSync("package.json",JSON.stringify(p,null,2)+"\n")'
run "re-install sees vitest" 0 "runner: vitest" bash "$SRC/install.sh" .
check "re-install leaves the project's premerge" bash -c "[ \"\$(grep -c '^premerge=' .claude/workshop.conf)\" -eq 1 ] && grep -qx 'premerge=bash scripts/premerge.sh' .claude/workshop.conf"
run "and says it does not run the gate by itself" 0 "NOTE: premerge is 'bash scripts/premerge.sh'" bash "$SRC/install.sh" .
check "re-install keeps the hand-set timeout, one entry" [ "$(stop_timeouts)" = 900 ]
check "the manifest now records the runner" [ "$(json ts-gate/.install.json 'j.runner')" = vitest ]
check "the vitest block comes before the gate's spread" bash -c "[ \"\$(grep -n 'vitest.configs.recommended' eslint.config.mjs | cut -d: -f1)\" -lt \"\$(grep -n '\.\.\.gate(' eslint.config.mjs | cut -d: -f1)\" ]"
check "the manifest lists the plugin the re-install added" [ "$(json ts-gate/.install.json 'j.deps.includes("@vitest/eslint-plugin")')" = true ]
check "vitest.config.mjs is written and owned" bash -c "test -f vitest.config.mjs && [ \"$(json ts-gate/.install.json 'j.vitest.file')\" = vitest.config.mjs ]"
check "and ignores workbench/**" grep -q '"workbench/\*\*"' vitest.config.mjs
# vitest_key: the entry install writes for vitest into ts-gate/knip.json.
vitest_key() { node -p "JSON.stringify({entry:[...require('$SRC/knip.vitest.json').entry,'!workbench/**']})"; }
check "knip's vitest entry is its defaults plus !workbench/**" [ "$(json ts-gate/knip.json 'JSON.stringify(j.vitest)')" = "$(vitest_key)" ]
check "no npx runner rule: one --config flag from the live tier; npm test -- <file> is the way to one file" bash -c "! grep -q 'npx vitest' .claude/settings.json"
node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(".claude/settings.json"));s.permissions.allow.push("Bash(npx vitest:*)");fs.writeFileSync(".claude/settings.json",JSON.stringify(s,null,2)+"\n");const m=JSON.parse(fs.readFileSync("ts-gate/.install.json"));m.allow.push("Bash(npx vitest:*)");fs.writeFileSync("ts-gate/.install.json",JSON.stringify(m,null,2)+"\n")'
run "re-install over a rule an earlier install wrote and this one does not" 0 "runner: vitest" bash "$SRC/install.sh" .
check "drops it from settings" bash -c "! grep -q 'npx vitest' .claude/settings.json"
check "and from the manifest" [ "$(json ts-gate/.install.json 'j.allow.includes("Bash(npx vitest:*)")')" = false ]
check "test:live is set" grep -q '"test:live"' package.json
git add -A && git commit -qm "vitest"

echo "== re-install keeps knip entry and ignores"
node -e 'const fs=require("fs"),p="ts-gate/knip.json",j=JSON.parse(fs.readFileSync(p));j.entry=["src/main.ts"];j.ignore.push("src/legacy/**");j.ignoreDependencies.push("effect");fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n")'
run "re-install" 0 "" bash "$SRC/install.sh" .
check "entry survives the re-install" [ "$(json ts-gate/knip.json 'j.entry[0]')" = src/main.ts ]
check "ignore survives" [ "$(json ts-gate/knip.json 'j.ignore.includes("src/legacy/**")')" = true ]
check "ignoreDependencies survives" [ "$(json ts-gate/knip.json 'j.ignoreDependencies.includes("effect")')" = true ]
check "the vitest key is written again, once" [ "$(json ts-gate/knip.json 'JSON.stringify(j.vitest)')" = "$(vitest_key)" ]
git add -A && git commit -qm "knip entry"

echo "== re-install warns when a config it wrote was edited to take workbench/** back in"
sed -i 's|, "workbench/\*\*"\]|]|' vitest.config.mjs
sed -i '/"!workbench\/\*\*",/d' biome.json
out=$(bash "$SRC/install.sh" . 2>&1)
check "the edited vitest config is kept" grep -q 'vitest.config.mjs edited since install, kept' <<< "$out"
check "and warned about, naming test.exclude" grep -qF 'WARNING: vitest.config.mjs does not leave workbench/** out; add "workbench/**" to its test.exclude' <<< "$out"
check "the edited biome config is warned about, naming files.includes" grep -qF 'WARNING: biome.json does not leave workbench/** alone; add "!workbench/**" to its files.includes' <<< "$out"
git checkout -q -- vitest.config.mjs biome.json

echo "== verify.sh proves eslint.config.mjs spreads gate()"
echo '{"rules":{"no-unused-vars":["error"]}}' > "$ESLINT_CONFIG"
run "verify refuses an eslint config without gate()" 1 "does not load" bash ts-gate/scripts/verify.sh
check "verify removed its seed" [ ! -e src/__gate_verify__.ts ]
echo '{"rules":{"no-unused-vars":["error"],"gate/no-unknown-signature":["error"]}}' > "$ESLINT_CONFIG"
run "verify passes with the gate loaded" 0 "verified" bash ts-gate/scripts/verify.sh
check "the tree is clean after verify" [ -z "$(git status --porcelain)" ]

echo "== stop hook releases after three identical failures despite timing lines"
export FAKE_OUT="$TMP/fake-out"
cat > ts-gate/scripts/gate.sh <<'G'
#!/usr/bin/env bash
cat "$FAKE_OUT"; echo "Checked 2 files in ${RANDOM}µs. No fixes applied."; echo "   Start at  $(date +%s%N)"; exit 1
G
hook() { echo "{\"session_id\":\"$1\"}" | bash ts-gate/scripts/stop-hook.sh; }
echo "src/a.ts(1,1): error TS2322: no" > "$FAKE_OUT"
run "stop 1 blocks" 2 "Gate failed" hook s1
run "stop 2 blocks" 2 "Gate failed" hook s1
run "stop 3 blocks and says to park it" 2 "same way 3 times" hook s1
run "stop 4 is allowed" 0 "allowed" hook s1
echo "src/a.ts(1,1): error TS2345: different" > "$FAKE_OUT"
run "a different failure blocks again" 2 "Gate failed" hook s1
echo "zzz one" > "$FAKE_OUT"
run "output with no finding words, stop 1" 2 "" hook s2
run "stop 2" 2 "" hook s2
echo "yyy two" > "$FAKE_OUT"
run "a different wordless output resets the count" 2 "Gate failed" hook s2
run "and does not release on its second stop" 2 "" hook s2

echo "== the stop hook reads gate.repeat_cap and gate.output_lines from .claude/workshop.conf"
echo "src/a.ts(1,1): error TS1111: capped" > "$FAKE_OUT"
printf '# gate.repeat_cap=1\nfoo=bar\nnot a setting\n\ngate.repeat_cap=9\n  gate.repeat_cap = 2  \n' >> .claude/workshop.conf
run "repeat_cap 2 (the last line; comment, unknown key and junk ignored): stop 1 blocks" 2 "Gate failed. Fix" hook s3
run "stop 2 says to park it, naming 2" 2 "same way 2 times" hook s3
run "stop 3 is allowed" 0 "the same failure 2 stops running; this stop is allowed" hook s3
seq 1 50 | sed 's/^/error line /' > "$FAKE_OUT"
out=$(hook s4 2>&1) || true
check "at the default 80 lines, 52 lines are fed back whole" bash -c "! grep -q 'more lines' <<< '$out'"
printf 'gate.output_lines=10\n' >> .claude/workshop.conf
run "output_lines 10 truncates after ten lines" 2 "… 42 more lines; run npm run gate:local" hook s5
check "and feeds back exactly ten" [ "$(hook s6 2>&1 | grep -c '^error line ')" -eq 10 ]
printf 'gate.output_lines=0\ngate.repeat_cap=two\n' >> .claude/workshop.conf
out=$(hook s7 2>&1) || true
check "an invalid output_lines is the default" bash -c "! grep -q 'more lines' <<< '$out'"
echo "src/a.ts(1,1): error TS1112: default cap" > "$FAKE_OUT"
hook s8 >/dev/null 2>&1 || true; hook s8 >/dev/null 2>&1 || true
run "an invalid repeat_cap is the default 3" 2 "same way 3 times" hook s8
git checkout -q -- ts-gate/scripts/gate.sh .claude/workshop.conf

echo "== eslint.gate.mjs reads the lint thresholds from .claude/workshop.conf"
# The two plugins stubbed: what is under test is the numbers gate() hands eslint.
for m in typescript-eslint eslint-plugin-sonarjs; do
  mkdir -p "node_modules/$m"
  printf '{"name":"%s","type":"module","main":"index.js"}\n' "$m" > "node_modules/$m/package.json"
  echo 'export default { plugin: {}, parser: {} };' > "node_modules/$m/index.js"
done
# shellcheck disable=SC2016  # the ${} is JavaScript's
limits() { node --input-type=module -e '
const { default: gate } = await import(`${process.cwd()}/ts-gate/eslint.gate.mjs`);
const r = gate({ tsconfigRootDir: process.cwd() })[0].rules;
const pick = ["sonarjs/cognitive-complexity", "sonarjs/no-nested-functions", "max-lines", "max-lines-per-function", "max-statements", "max-params", "max-depth"];
console.log(pick.map((k) => JSON.stringify(r[k])).join(" "));'; }
O='"skipBlankLines":true,"skipComments":true'
run "no settings: the shipped thresholds" 0 "^\[\"error\",15\] \[\"error\",\{\"threshold\":3\}\] \[\"warn\",\{\"max\":1000,$O\}\] \[\"warn\",\{\"max\":100,$O\}\] \[\"warn\",30\] \[\"warn\",6\] \[\"warn\",4\]$" limits
printf 'lint.complexity=20\nlint.max_nesting=4\nlint.max_lines=500\nlint.max_lines_per_function=50\nlint.max_statements=12\nlint.max_params=3\nlint.max_depth=2\n' >> .claude/workshop.conf
run "every lint key changes its threshold and nothing else" 0 "^\[\"error\",20\] \[\"error\",\{\"threshold\":4\}\] \[\"warn\",\{\"max\":500,$O\}\] \[\"warn\",\{\"max\":50,$O\}\] \[\"warn\",12\] \[\"warn\",3\] \[\"warn\",2\]$" limits
git checkout -q -- .claude/workshop.conf
printf 'lint.complexity=007\nlint.max_nesting=\nlint.max_params=0\nlint.max_depth=deep\nlint.nope=1\ngarbage\n# lint.max_statements=1\nlint.max_lines=10\n  lint.max_lines = 700  \n' >> .claude/workshop.conf
run "invalid values are the default, the last occurrence wins, a comment is not read" 0 "^\[\"error\",15\] \[\"error\",\{\"threshold\":3\}\] \[\"warn\",\{\"max\":700,$O\}\] \[\"warn\",\{\"max\":100,$O\}\] \[\"warn\",30\] \[\"warn\",6\] \[\"warn\",4\]$" limits
git checkout -q -- .claude/workshop.conf

echo "== eslint.gate.mjs reads the glossary's Never column as a substring rejection"
# shellcheck disable=SC2016  # the ${} is JavaScript's
never() { node --input-type=module -e '
const { default: gate } = await import(`${process.cwd()}/ts-gate/eslint.gate.mjs`);
const r = gate({ tsconfigRootDir: process.cwd() }).map((b) => b.rules?.["id-match"]).find(Boolean);
if (!r) { console.log("unset"); process.exit(0); }
const re = new RegExp(r[1]);
console.log(process.argv.slice(1).map((id) => id + ":" + (re.test(id) ? "ok" : "no")).join(" "));' "$@"; }
mkdir -p workbench
printf '## Use, never\n\n| Use | Never | Because |\n|---|---|---|\n| customer | account | the login record |\n' > workbench/GLOSSARY.md
run "a rejected word is refused inside any declared identifier" 0 "^accountId:no getAccount:no ACCOUNT_ID:no total:ok$" never accountId getAccount ACCOUNT_ID total
printf '## Use, never\n\n| Use | Never | Because |\n|---|---|---|\n| customer | never account or acct | prose |\n' > workbench/GLOSSARY.md
run "function words in a cell written as prose are not rejections" 0 "^accountId:no acctNo:no error:ok color:ok sort:ok$" never accountId acctNo error color sort
# shellcheck disable=SC2016  # $amount is the glossary word under test
printf '## Use, never\n\n| Use | Never | Because |\n|---|---|---|\n| amount | $amount, `total` | x |\n' > workbench/GLOSSARY.md
# shellcheck disable=SC2016  # as above
run "a \$ word and a backticked word are literal" 0 '^\$amount:no subtotal:no price:ok$' never '$amount' subtotal price
printf '## Use, never\n\n| Term | Use | Never |\n|---|---|---|\n| x | customer | account |\n' > workbench/GLOSSARY.md
run "the Never column is found by its header, wherever it sits" 0 "^accountId:no total:ok$" never accountId total
rm -rf workbench

echo "== eslint.gate.mjs appends .claude/eslint/*.mjs after its own blocks, in file-name order"
mkdir -p .claude/eslint
echo 'export default [{ files: ["**/*.tsx"], rules: { "b/rule": "error" } }];' > .claude/eslint/b.mjs
echo 'export default [{ rules: { "a/one": "warn" } }, { rules: { "a/two": "off" } }];' > .claude/eslint/a.mjs
echo 'export default "not read";' > .claude/eslint/notes.js
# shellcheck disable=SC2016  # the ${} is JavaScript's
blocks() { node --input-type=module -e '
const { default: gate } = await import(`${process.cwd()}/ts-gate/eslint.gate.mjs`);
const c = gate({ tsconfigRootDir: process.cwd() });
console.log(c.length, c.slice(-3).map((b) => Object.keys(b.rules).join()).join(" "));' 2>&1; }
run "the gate's two blocks, then a.mjs's two, then b.mjs's one" 0 "^5 a/one a/two b/rule$" blocks
echo 'export default ({ severity, tsconfigRootDir }) => [{ rules: { "d/sev": [severity, tsconfigRootDir === process.cwd()] } }];' > .claude/eslint/d.mjs
# shellcheck disable=SC2016  # the ${} is JavaScript's
sev() { node --input-type=module -e '
const { default: gate } = await import(`${process.cwd()}/ts-gate/eslint.gate.mjs`);
console.log(JSON.stringify(gate({ tsconfigRootDir: process.cwd(), severity: "warn" }).at(-1).rules["d/sev"]));' 2>&1; }
run "a function export gets the gate's severity and root" 0 '^\["warn",true\]$' sev
echo 'export default { rules: {} };' > .claude/eslint/c.mjs
run "a default export that is not an array fails the load, naming the file" 1 "\.claude/eslint/c\.mjs: the default export must be an array" blocks
rm -rf .claude/eslint
run "no .claude/eslint: the gate's two blocks alone" 0 "^2 " blocks
rm -rf node_modules/typescript-eslint node_modules/eslint-plugin-sonarjs

echo "== no-network.mjs refuses TCP, UDP and fetch off loopback (192.0.2.1 is TEST-NET, unroutable)"
mkdir -p node_modules/vitest && printf '{"name":"vitest","type":"module","main":"index.js"}\n' > node_modules/vitest/package.json
echo 'export const expect = { getState: () => ({ currentTestName: "t" }) };' > node_modules/vitest/index.js
# shellcheck disable=SC2016  # the ${} is JavaScript's
guard() { node --input-type=module -e '
import net from "node:net"; import dgram from "node:dgram";
await import(`${process.cwd()}/ts-gate/no-network.mjs`);
const out = [];
const attempt = (label, f) => { try { f(); out.push(label + ":open"); } catch (e) { out.push(label + (/^no-network/.test(e.message) ? ":refused" : ":" + e.message)); } };
attempt("tcp", () => net.connect(80, "192.0.2.1"));
attempt("udp-send", () => dgram.createSocket("udp4").send(Buffer.from("x"), 53, "192.0.2.1"));
attempt("udp-connect", () => dgram.createSocket("udp4").connect(53, "192.0.2.1"));
attempt("udp-loopback", () => { const s = dgram.createSocket("udp4"); s.send(Buffer.from("x"), 9, "127.0.0.1"); s.close(); });
try { await fetch("http://192.0.2.1/"); out.push("fetch:open"); } catch (e) { out.push("fetch" + (/^no-network/.test(e.message) ? ":refused" : ":" + e.message)); }
console.log(out.join(" ")); process.exit(0);' 2>&1; }
run "off loopback refused on every door, loopback UDP open" 0 "^tcp:refused udp-send:refused udp-connect:refused udp-loopback:open fetch:refused$" guard
rm -rf node_modules/vitest

echo "== gate:fix runs the formatter even when eslint --fix leaves an error"
echo 1 > "$TSGATE_TEST/exit.eslint"; : > "$LOG"
run "gate:fix exits non-zero on an unfixable eslint error" 1 "" npm run -s gate:fix
check "biome still ran" called "biome format --write"
rm -f "$TSGATE_TEST/exit.eslint"; : > "$LOG"
run "gate:fix exits 0 when both pass" 0 "" npm run -s gate:fix

echo "== uninstall keeps an edited architecture record and names hand-merged lines"
echo "// project rule" >> ts-gate/.dependency-cruiser.cjs; git commit -qam "dc rule"
run "uninstall says where the edited record went" 0 "kept as dependency-cruiser.kept.cjs" bash "$SRC/uninstall.sh" .
check "uninstall leaves a premerge that is not the gate's" grep -qx 'premerge=bash scripts/premerge.sh' .claude/workshop.conf
check "and removes the Stop hook whatever its timeout" bash -c "! grep -q stop-hook .claude/settings.json 2>/dev/null"
check "the edited .dependency-cruiser.cjs was moved aside, not deleted" grep -q "project rule" dependency-cruiser.kept.cjs
rm -f dependency-cruiser.kept.cjs
git add -A && git commit -qm "uninstalled" >/dev/null
run "re-install for the next checks" 0 "" bash "$SRC/install.sh" .
check "a fresh Stop hook entry gets 600 again" [ "$(stop_timeouts)" = 600 ]
sed -i 's|^premerge=.*|premerge=npm run gate|' .claude/workshop.conf
printf 'lint.max_lines=900\n' >> .claude/workshop.conf
git add -A && git commit -qm "ts-gate: install again" >/dev/null

echo "== uninstall removes exactly the rules install wrote"
run "uninstall" 0 "uninstalled" bash "$SRC/uninstall.sh" .
check "gate allow rules are gone" bash -c "! grep -q 'npm run gate' .claude/settings.json 2>/dev/null"
check "the runner rule is gone" bash -c "! grep -q 'npx vitest' .claude/settings.json 2>/dev/null"
check "ts-gate/ is gone" [ ! -d ts-gate ]
check "uninstall removes premerge when it is the gate's own" bash -c "! grep -q '^premerge=' .claude/workshop.conf"
check "and keeps the project's other settings" grep -qx 'lint.max_lines=900' .claude/workshop.conf
printf 'cap.claude=150\n# premerge=<command>\nmain=main\n' > .claude/workshop.conf
git add -A && git commit -qm "uninstalled again" >/dev/null
run "install over workbench's commented-out premerge" 0 "set premerge=npm run gate" bash "$SRC/install.sh" .
check "fills that line in place" [ "$(cat .claude/workshop.conf)" = "$(printf 'cap.claude=150\npremerge=npm run gate\nmain=main')" ]
printf 'cap.claude=150\npremerge=\nmain=main\npremerge =  \n' > .claude/workshop.conf
run "install over an empty premerge=, which workbench reads as unset" 0 "set premerge=npm run gate" bash "$SRC/install.sh" .
check "fills the last empty line in place and drops the other" [ "$(cat .claude/workshop.conf)" = "$(printf 'cap.claude=150\nmain=main\npremerge=npm run gate')" ]

echo "== brownfield: a foreign biome config that formats repos/**"
mkproj "$TMP/p2"
echo '{"formatter":{"indentStyle":"tab"}}' > biome.json && git add -A && git commit -qm biome
run "install warns with the includes block" 0 'WARNING: biome.json.*!repos/\*\*' bash "$SRC/install.sh" .
check "biome.json was not touched" [ "$(cat biome.json)" = '{"formatter":{"indentStyle":"tab"}}' ]
echo '{"files":{"includes":["**","!repos/**","!ts-gate/**","!.worktrees/**"]},"formatter":{"indentStyle":"tab"}}' > biome.json
run "a config from the earlier advice is told about workbench/**" 0 'WARNING: biome.json.*!workbench/\*\*' bash "$SRC/install.sh" .
echo '{"files":{"includes":["**","!repos/**","!ts-gate/**","!.worktrees/**","!workbench/**"]},"formatter":{"indentStyle":"tab"}}' > biome.json
check "the excluding config prints no biome warning" bash -c "! bash '$SRC/install.sh' . 2>&1 | grep -q 'WARNING: biome'"

echo "== install asks tsc about a spike's code before any spike exists, and warns where a kept config would check it"
check "no workbench/ to begin with" [ ! -e workbench ]
check "include [src] keeps tsc out: no warning" bash -c "! bash '$SRC/install.sh' . 2>&1 | grep -q 'WARNING: tsc'"
cp tsconfig.json "$TMP/tsconfig.keep" && node -e 'const f="tsconfig.json",j=require("./"+f);delete j.include;j.exclude=["dist"];require("fs").writeFileSync(f,JSON.stringify(j))'
out=$(bash "$SRC/install.sh" . 2>&1)
check "exclude only: tsc would compile workbench/, warned with no spike there yet" grep -q 'WARNING: tsc would compile files under workbench/' <<< "$out"
check "which the include/exclude check alone misses" lacks "$out" "has no include/exclude"
check "the made-up spike is gone, and the workbench/ made for it" [ ! -e workbench ]
mkdir -p workbench/items/spikes/s-001-x && echo 'export const p = 1;' > workbench/items/spikes/s-001-x/proto.ts
run "with a spike there, the same warning" 0 "WARNING: tsc would compile files under workbench/" bash "$SRC/install.sh" .
check "only the made-up spike went" bash -c "[ -f workbench/items/spikes/s-001-x/proto.ts ] && [ ! -e workbench/items/spikes/s-000-ts-gate-probe ]"
cp "$TMP/tsconfig.keep" tsconfig.json && rm -rf workbench
echo 'export default [{ ignores: ["repos/**"] }];' > eslint.config.js
run "a project's eslint config without workbench/** is warned" 0 "WARNING: eslint.config.js does not leave workbench/\*\* out" bash "$SRC/install.sh" .
rm eslint.config.js
sed -i 's|"\^workbench/"|"^elsewhere/"|' ts-gate/.dependency-cruiser.cjs
run "a kept architecture record without no-workbench is warned" 0 "WARNING: ts-gate/.dependency-cruiser.cjs has no no-workbench rule" bash "$SRC/install.sh" .

echo "== no runner: an app's vite.config left alone"
mkproj "$TMP/p5"
echo 'export default {};' > vite.config.ts && git add -A && git commit -qm vite
out=$(bash "$SRC/install.sh" . 2>&1)
check "a vite.config.ts that is not a test config is not warned about" lacks "$out" "vite.config"

echo "== vitest with the project's own vite.config: the lines to add, once"
mkproj "$TMP/p6" '{"vitest":"^5.0.0"}'
echo 'export default {};' > vite.config.ts && git add -A && git commit -qm vite
out=$(bash "$SRC/install.sh" . 2>&1)
check "install prints the lines to add, workbench/** among them" grep -q 'vitest config exists, not touched. Add to it: .*"workbench/\*\*"' <<< "$out"
check "and no second warning about the same file" lacks "$out" "WARNING: vite.config.ts"

echo "== uninstall names the lines merged by hand into configs that predate install"
mkproj "$TMP/p4"
echo 'export default [];' > eslint.config.mjs
echo 'export default {};' > vitest.config.mjs
git add -A && git commit -qm "own configs" >/dev/null
run "install prints the blocks to merge" 0 "" bash "$SRC/install.sh" .
git add -A && git commit -qm "ts-gate" >/dev/null
run "uninstall names the eslint lines it cannot remove" 0 "eslint.config.mjs: remove the ts-gate lines" bash "$SRC/uninstall.sh" .
check "the project's eslint config is left in place" test -f eslint.config.mjs
check "the project's vitest config is left in place" test -f vitest.config.mjs
check "an unedited default record is deleted with the tree, not kept" test ! -e dependency-cruiser.kept.cjs

echo "== uninstall puts back what the project had before install"
mkproj "$TMP/p5" '{"vitest":"^5.0.0"}'
npm pkg set scripts.gate="echo project-gate" scripts.test:live="echo project-live"
mkdir -p .claude
node -e 'require("fs").writeFileSync(".claude/settings.json",JSON.stringify({permissions:{allow:["Bash(npm ci)","Bash(npx vitest:*)","Bash(ls:*)"]}},null,2)+"\n")'
git add -A && git commit -qm "own scripts and rules" >/dev/null
run "install over the project's own gate script" 0 "installed" bash "$SRC/install.sh" .
check "install's gate script replaces the project's" [ "$(json package.json 'j.scripts.gate')" = "bash ts-gate/scripts/gate.sh" ]
check "the manifest records what the project had under the names" [ "$(json ts-gate/.install.json 'j.scripts.gate+" / "+j.scripts["test:live"]+" / "+j.scripts["gate:local"]')" = "echo project-gate / echo project-live / null" ]
check "and only the allow rules install added" [ "$(json ts-gate/.install.json 'j.allow.join(" ")')" = "Bash(npm run gate) Bash(npm run gate:local) Bash(npm run gate:full) Bash(npm run gate:fix) Bash(npm test:*)" ]
check "and the rule files it copied" [ "$(json ts-gate/.install.json 'j.rules.includes("ts-gate.md")')" = true ]
run "re-install" 0 "installed" bash "$SRC/install.sh" .
check "a re-run keeps the recorded scripts" [ "$(json ts-gate/.install.json 'j.scripts.gate')" = "echo project-gate" ]
git add -A && git commit -qm "ts-gate: install" >/dev/null
run "uninstall" 0 "uninstalled" bash "$SRC/uninstall.sh" .
check "the project's gate and test:live scripts are back" [ "$(json package.json 'j.scripts.gate+" / "+j.scripts["test:live"]')" = "echo project-gate / echo project-live" ]
check "install's other scripts are gone" [ "$(json package.json 'j.scripts["gate:local"]')" = undefined ]
check "the project's own allow rules stay" [ "$(json .claude/settings.json 'j.permissions.allow.join(" ")')" = "Bash(npm ci) Bash(npx vitest:*) Bash(ls:*)" ]
check "package.json holds what it held before install" same_json package.json HEAD~1
check "settings.json holds what it held before install" same_json .claude/settings.json HEAD~1
check "a manifest from before the entries still strips every rule install writes" bash -c "
  echo '{\"runner\":\"vitest\",\"deps\":[],\"config\":null,\"biome\":null,\"vitest\":null}' > x.json
  node -e 'const m=require(\"./x.json\");if(m.allow||m.scripts||m.rules)process.exit(1)'"
rm -f x.json

echo "== real eslint reports at the configured threshold and not below it"
# Borrows the node_modules of a project where install ran for real (npm, the
# network); the gate itself is copied from this source. Unset, the leg says so.
if [ -z "${TSGATE_REAL_PROJECT:-}" ]; then
  echo "skip: set TSGATE_REAL_PROJECT to a project with a real ts-gate install to run this leg"
else
  mkproj "$TMP/real" '{"vitest":"^5.0.0"}'
  rm -rf node_modules && ln -s "$TSGATE_REAL_PROJECT/node_modules" node_modules
  bash "$SRC/install.sh" . >/dev/null
  ESL="$TSGATE_REAL_PROJECT/node_modules/.bin/eslint"
  # fn <name> <body lines...>: one exported function, a line per statement.
  fn() { local n=$1; shift; { printf 'export function %s(a: boolean, b: boolean, c: boolean, d: boolean): number {\n' "$n"; printf '  %s\n' "$@"; printf '}\n'; } > "src/$n.ts"; }
  fn five 'let n = Number(a);' 'n += Number(b);' 'n += Number(c);' 'n += Number(d);' 'return n;'
  fn six 'let n = Number(a);' 'n += Number(b);' 'n += Number(c);' 'n += Number(d);' 'n += 1;' 'return n;'
  fn three 'let n = 0;' 'if (a) n += 1;' 'if (b) n += 1;' 'if (c) n += 1;' 'return n + Number(d);'
  fn four 'let n = 0;' 'if (a) n += 1;' 'if (b) n += 1;' 'if (c) n += 1;' 'if (d) n += 1;' 'return n;'
  reports() { local out; out=$("$ESL" "src/$1.ts" 2>&1 || true); grep -q -- "$2" <<< "$out"; }
  check "real eslint runs the gate here" bash -c "'$ESL' --print-config src/five.ts | grep -q 'gate/no-unknown-signature'"
  check "no settings: six statements are under the default 30" bash -c "$(declare -f reports); ESL='$ESL'; ! reports six max-statements"
  check "no settings: complexity 4 is under the default 15" bash -c "$(declare -f reports); ESL='$ESL'; ! reports four cognitive-complexity"
  printf 'lint.max_statements=5\nlint.complexity=3\n' >> .claude/workshop.conf
  check "lint.max_statements=5: five statements pass" bash -c "$(declare -f reports); ESL='$ESL'; ! reports five max-statements"
  check "and six are reported" reports six "too many statements (6). Maximum allowed is 5"
  check "lint.complexity=3: complexity 3 passes" bash -c "$(declare -f reports); ESL='$ESL'; ! reports three cognitive-complexity"
  check "and 4 is reported" reports four "from 4 to the 3 allowed"

  # knip.vitest.json repeats knip's own entry defaults; a knip that moves
  # them fails here (knip@6 floats).
  check "knip.vitest.json's list is the installed knip's" [ "$(node --input-type=module -e "const m = await import('$TSGATE_REAL_PROJECT/node_modules/knip/dist/plugins/vitest/index.js'); console.log(JSON.stringify(m.default.entry))")" = "$(node -p "JSON.stringify(require('$SRC/knip.vitest.json').entry)")" ]
  # A spike's test is no use of the project's code.
  printf 'export const used = 1;\nexport const onlySpikeUses = 2;\n' > src/lib.ts
  printf 'import { used } from "./lib.ts";\nexport const x = used;\n' > src/index.ts
  mkdir -p workbench/items/spikes/s-001-x
  printf 'import { test } from "vitest";\nimport { onlySpikeUses } from "../../../../src/lib.ts";\ntest("p", () => { void onlySpikeUses; });\n' > workbench/items/spikes/s-001-x/proto.test.ts
  check "real knip reports an export only a spike's test imports" bash -c "'$TSGATE_REAL_PROJECT/node_modules/.bin/knip' --config ts-gate/knip.json 2>&1 | grep -q onlySpikeUses"
fi

echo
echo "$checks checks, $fails failed"
[ "$fails" -eq 0 ]
