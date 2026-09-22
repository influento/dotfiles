#!/usr/bin/env bash
# End-to-end tests for the workbench CLI, run in a throwaway repository.
# Plain bash, no framework: each check is an exit code and a grep on output.
# Run: bash tests/workbench.sh
set -euo pipefail

SELF=$(readlink -f "$0")  # every check runs from a temp repo, so paths here must be absolute
# The suite lives inside the tool it tests, so every source is one hop up.
WB=$(readlink -f "$(dirname "$0")/../bin/workbench")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export HOME="$TMP/home"  # no user gitconfig, hooks or aliases
# The suite's own temp directory, not the machine's. Two checks below count
# 'tmp.*' entries before and after a command to prove it leaks nothing; against
# a shared /tmp any other process — an editor, a browser, a second run of this
# suite, whose own $TMP is itself a /tmp/tmp.* — creating or reaping one in that
# window flips the count and fails a check that has nothing to do with it.
# Isolated, the count measures only what workbench leaves behind.
export TMPDIR="$TMP/tmpdir"
mkdir -p "$HOME" "$TMP/bin" "$TMPDIR"
export PATH="$TMP/bin:$PATH"

# A PATH with neither python3 nor jq, for the JSON fallback legs. Shadowing
# does not work — 'command -v' walks the whole PATH and finds /usr/bin/python3
# behind any shim — so the only way to hide them is a PATH that holds nothing
# else. 'type -P' rather than 'command -v': the caller's shell may alias 'cat'
# or 'ls' to something else, and an alias is not a path to link.
NOJSON="$TMP/nojson"
mkdir -p "$NOJSON"
for _t in bash sh sed awk gawk grep head tail cut sort uniq comm wc tr find git \
          basename dirname date mktemp cat printf readlink sha256sum paste rm \
          rmdir mkdir mv cp touch env expr seq id tee xargs cmp; do
  _p=$(type -P "$_t" 2>/dev/null) && [ -n "$_p" ] && ln -sf "$_p" "$NOJSON/$_t"
done
unset _t _p
export NOJSON

fails=0 checks=0
pass() { checks=$((checks + 1)); echo "ok   $1"; }
fail() { checks=$((checks + 1)); fails=$((fails + 1)); echo "FAIL $1" >&2; }
# check <label> <cmd...> — passes when the command succeeds.
# Everything after the label is one command. 'check "l" [ a ] && [ b ]' does NOT
# pass both: the shell ends the check at [ a ] and runs [ b ] outside it, where
# a failure is invisible — set -e exempts a false && at the end of a list. Four
# checks were built that way and asserted half of what they read as. More than
# one condition goes in a 'bash -c'.
check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }
# run <label> <expected-rc> <pattern> <cmd...> — the pattern is grepped over
# combined stdout+stderr; an empty pattern skips the grep.
run() {
  local label="$1" want="$2" pat="$3"; shift 3
  local out rc=0
  out=$("$@" 2>&1) || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: rc=$rc, wanted $want"; printf '%s\n' "$out" | sed 's/^/     /' >&2; return
  fi
  # A herestring, not a pipe. 'set -o pipefail' is in effect, and grep -q exits
  # the moment it matches — on a first-line match against more than PIPE_BUF
  # (4096) bytes the write is still in flight, printf takes SIGPIPE, and the
  # pipeline reports 141. The check then fails BECAUSE the pattern matched, and
  # only sometimes: 'rules.sh serves adopt' (10,983 bytes, matching on line 1)
  # did it in 54 of 400 tries.
  if [ -n "$pat" ] && ! grep -qE -- "$pat" <<<"$out"; then
    fail "$label: output lacks /$pat/"; printf '%s\n' "$out" | sed 's/^/     /' >&2; return
  fi
  pass "$label"
}

# Evidence and status edits an agent would make by hand.
fill_evidence() {
  # shellcheck disable=SC2016
  printf '\n```\n$ %s\n%s\n```\n' "$2" "$3" >> "$1"
}
set_status() { sed -i "s/^status: .*/status: $2/" "$1"; }
# crit <path> — fill the criterion, and 'none' under Side effects, so start
# accepts it.
crit() { sed -i -e '/^## How to confirm/a\
\
agreed with the user' -e '/^## Side effects/a\
\
none' "$1"; }
# effects <path> <text> — replace what Side effects says.
effects() { sed -i '/^## Side effects/,/^## /{ /^## /!d }' "$1"; sed -i "/^## Side effects/a\\
\\
$2\\
" "$1"; }
mainroot() { git worktree list --porcelain | sed -n '1s/^worktree //p'; }
# conf <key> <value> sets one key in the main checkout's .claude/workshop.conf,
# uncommitted like a hand edit; unconf <key> removes it.
unconf() { local f; f="$(mainroot)/.claude/workshop.conf"; [ ! -f "$f" ] || sed -i "/^$1=/d" "$f"; }
conf() { unconf "$1"; mkdir -p "$(mainroot)/.claude"; printf '%s=%s\n' "$1" "$2" >> "$(mainroot)/.claude/workshop.conf"; }
# newc <class> <title> [opts] — new, with the criterion filled; prints the id.
# The file is on the main checkout wherever this runs, so it is found there.
newc() {
  local id
  id=$("$WB" new "$@" 2>/dev/null) || return 1
  crit "$(find "$(mainroot)/workbench/items" -name "$id-*.md" -print -quit)"
  printf '%s\n' "$id"
}
# ready <worktree> — evidence on the branch's own item, committed, so merge
# passes.
ready() {
  local f
  f=$(find "$1/workbench/items" -name "$(git -C "$1" symbolic-ref --short HEAD).md" -print -quit)
  fill_evidence "$f" "run" "ok"
  ( cd "$1" && git add -A && git commit -qm ready )
}

# Every repo starts with .claude/settings.local.json ignored, the way a real
# project ends up after 'init' — see ensure_gitignore. Tests whose subject is a
# path git treats specially cannot set this up for themselves and be trusted:
# without it the file is an ordinary untracked write, the assertion passes
# against a build that cannot see ignored files at all, and the test proves
# nothing. Two of them did exactly that. The invariant is checked here rather
# than asserted per repo, so it fails loudly for every caller at once.
new_repo() {
  local d="$TMP/$1"
  rm -rf "$d"; mkdir -p "$d"; cd "$d"
  git init -q -b main
  printf '.claude/settings.local.json\n' > .gitignore
  echo hello > README && git add -A && git commit -qm init
  git check-ignore -q .claude/settings.local.json \
    || { echo "fixture: $1 does not ignore .claude/settings.local.json" >&2; exit 1; }
}

# --- a repo whose default branch cannot be resolved -------------------------
# 'git init' then 'workbench init', or a repo on develop/trunk: default_branch
# dies, and a die inside a substitution exits before any '|| echo' in it runs.
# init and status must fall through, not exit 1 in silence.

new_repo trunk
git checkout -q -b trunk && git branch -q -D main
run "init on a trunk repo completes" 0 "workbench ready" "$WB" init
run "init on a trunk repo reports the branch unresolved" 0 "default branch    UNRESOLVED" "$WB" init
run "status on a trunk repo completes" 0 "nothing in flight" "$WB" status
rm -rf "$TMP/nocommit"; mkdir -p "$TMP/nocommit"; cd "$TMP/nocommit"; git init -q -b main
run "init on a repo with no commit completes" 0 "UNRESOLVED" "$WB" init

# --- the happy loop ---------------------------------------------------------

new_repo loop
run "init" 0 "workbench ready" "$WB" init
run "init outside ~ says to set the memory path by hand" 0 "not under ~" "$WB" init
for c in workbench bug feature idea wb; do
  check "init renders /$c as a copy" bash -c "[ -f '.claude/skills/$c/SKILL.md' ] && [ ! -L '.claude/skills/$c' ] && [ -f '.claude/skills/$c/GENERATED' ]"
done
check "init does not ignore the copies" bash -c "! grep -q '.claude/skills' .gitignore"
check "no /rename is rendered" [ ! -e .claude/skills/rename ]
# The CLI is in bin/, beside the skill sources rather than inside one, so
# render_skills' 'cp -RL' cannot vendor a 4000-line copy of it into every
# opted-in project and skill_hash cannot count it — which would report every
# project's copy stale on any CLI edit. Adding bin/ to skill_sources fails this.
check "init renders no copy of the CLI" [ ! -e .claude/skills/bin ]
# The source directory is named exactly as the skill it renders to: what is
# under .claude/skills/ is what Claude Code loads by name.
check "the skill renders under its own name" [ -f .claude/skills/workbench/SKILL.md ]
for a in wb-worker wb-reviewer; do check "init renders the $a agent" [ -f ".claude/agents/$a.md" ]; done
check "the stamp carries source and copy hashes" bash -c "sed -n 1,2p .claude/skills/wb/GENERATED | grep -cE '^[0-9a-f]{12}\$' | grep -qx 2"
check "init ignores .worktrees/" grep -qx '.worktrees/' .gitignore
check "init allows Bash(workbench:*)" grep -q 'Bash(workbench:\*)' .claude/settings.json
check "init writes the session hook" grep -q 'workbench status ||' .claude/settings.json
check "the hook is guarded on PATH" grep -q '"command -v workbench >/dev/null && workbench status || true"' .claude/settings.json
check "init does not set the agent-teams flag" bash -c "! grep -q AGENT_TEAMS .claude/settings.json"
check "init writes no status line and no signal or gate hook (W1)" bash -c "! grep -qE 'statusline|workbench signal|workbench gate' .claude/settings.json"
run "init is idempotent" 0 "workbench ready" "$WB" init
check "unchanged copies are not re-rendered" bash -c "! '$WB' init 2>&1 | grep -q 'rendered .claude'"
check "the hook is not duplicated" [ "$(grep -c 'workbench status ||' .claude/settings.json)" -eq 1 ]
run "status is quiet while the copies are current" 0 "" bash -c "! '$WB' status | grep -q 'behind their source'"
# A project wired by an older init carries the session layer's hooks and status
# line; a gate hook left behind would refuse every tool call it matched.
python3 - <<'PY'
import json
p='.claude/settings.json'; d=json.load(open(p))
d['hooks']['PreToolUse']=[{"matcher":"AskUserQuestion","hooks":[{"type":"command","command":"! command -v workbench >/dev/null || workbench gate ask"}]},
  {"hooks":[{"type":"command","command":"command -v workbench >/dev/null && workbench signal working || true"},{"type":"command","command":"echo mine"}]}]
d['statusLine']={"type":"command","command":"command -v workbench >/dev/null && workbench statusline || true"}
json.dump(d,open(p,'w'),indent=2)
PY
run "init strips the signal and gate hooks of an older workbench" 0 "hooks.PreToolUse -= the signal/gate hooks" "$WB" init
check "and the status line" bash -c "! grep -q statusline .claude/settings.json"
check "and keeps the project's own hook in the same group" grep -q '"echo mine"' .claude/settings.json
check "and drops the group that held only ours" bash -c "! grep -q AskUserQuestion .claude/settings.json"
git add -A && git commit -qm 'workbench init'

git checkout -q -b side
run "new refuses when the main checkout is off the default branch" 1 "has 'side' checked out, not main" "$WB" new bug "nope"
check "the refusal spent no id" [ -z "$(find workbench/items -name '*.md')" ]
git checkout -q main
id=$("$WB" new bug "crash on save" 2>/dev/null)
check "new allocates b-001" [ "$id" = b-001 ]
item=workbench/items/bugs/b-001-crash-on-save.md
check "new writes the item file" [ -f "$item" ]
check "new commits it on main" [ "$(git log -1 --format=%s)" = "new b-001: crash on save" ]
check "new leaves the tree clean" [ -z "$(git status --porcelain)" ]
run "archive refuses without evidence" 1 "no evidence recorded" "$WB" archive b-001
printf '\nTBD\n' >> "$item"
run "archive refuses prose-only evidence" 1 "no evidence recorded" "$WB" archive b-001
git checkout -q "$item"
# a repeated template heading is not a foreign one, so the set comparison
# collapsed it and a second '## Evidence' went into the archive unremarked
printf '\n## Evidence\n\nand again\n' >> "$item"
run "archive refuses a repeated heading" 1 "twice" "$WB" archive b-001
git checkout -q "$item"
# '~~~' opens a fence in markdown too, and it is what gets reached for when the
# pasted output itself holds backticks. Read as prose it is not evidence at all,
# so an item whose only evidence is fenced that way could never be archived.
idt=$(newc bug "tilde-fence")
printf '\n~~~\n$ make test\nok\n~~~\n' >> "workbench/items/bugs/$idt-tilde-fence.md"
run "archive takes evidence fenced with ~~~" 0 "archived $idt" "$WB" archive "$idt"
check "archive commits the move" [ -z "$(git status --porcelain workbench/items)" ]
check "as 'archive <id>'" [ "$(git log -1 --format=%s)" = "archive $idt" ]
# A fence closes only on its own character, in a run at least as long:
# pasted markdown holds the other kind, and its lines are output, not headings.
idm=$(newc bug "mixed-fence")
printf '\n~~~\n$ cat README.md\n```\n## Usage\n~~~\n' >> "workbench/items/bugs/$idm-mixed-fence.md"
run "archive takes a ~~~ block holding a \`\`\` line" 0 "archived $idm" "$WB" archive "$idm"
idq=$(newc bug "long-fence")
# shellcheck disable=SC2016  # the '$ cat' prompt is literal evidence text
printf '\n````\n$ cat notes.md\n```\n## Not a heading\n```\n````\n' >> "workbench/items/bugs/$idq-long-fence.md"
run "archive takes a \`\`\`\` block holding a '## ' line between \`\`\` lines" 0 "archived $idq" "$WB" archive "$idq"

run "start refuses an empty criterion" 1 "b-001's 'How to confirm' is empty" "$WB" start b-001
check "the refusal cut no branch" [ -z "$(git branch --list 'b-001-*')" ]
crit "$item"
printf '\n%s\nunclosed\n' '```' >> "$item"
run "start names an unclosed fence rather than an empty criterion" 1 "b-001 has an unclosed .* fence" "$WB" start b-001
git checkout -q "$item" && crit "$item"
run "start" 0 "started b-001-crash-on-save in" "$WB" start b-001
wt=.worktrees/b-001-crash-on-save
check "start lands the criterion on main first" [ "$(git log -1 --format=%s)" = "start b-001" ]
check "the branch carries the item" [ -f "$wt/$item" ]
check "main keeps its copy" [ -f "$item" ]
check "main is clean after start" [ -z "$(git status --porcelain)" ]
run "status marks a started item" 0 "b-001-crash-on-save +open +started" "$WB" status
for short in b-1 b-01 b-0001; do
  run "start reads $short as b-001" 1 "b-001 is already started; its worktree is .*/$wt$" "$WB" start "$short"
done
run "start refuses a bare letter" 1 "is not an item id" "$WB" start b
run "new validates the class" 1 "class must be" "$WB" new bogus "t"

( cd "$wt" && mkdir -p sub && echo fix > src.txt && echo x > sub/x.txt && git add -A && git commit -qm wip )
run "merge refuses an open item with no evidence on the branch" 1 "open with no evidence under '## Evidence' on b-001-crash-on-save" "$WB" merge b-001 "fix crash"
# pasted output holds '## ' lines: a heading to markdown, not to the item
fill_evidence "$wt/$item" "make test" $'## not a heading\nok'
( cd "$wt" && git commit -qam evidence )

echo note >> "$wt/$item"
run "merge names an edited, uncommitted item file" 1 "$item is edited and not committed on the branch" "$WB" merge b-001 "fix crash"
( cd "$wt" && git checkout -q "$item" )
run "merge" 0 "merged b-001" "$WB" merge b-001 "fix crash"
check "squash carries the trailer" grep -qx 'Item: b-001' <(git log -1 --format=%B)
check "the branch's copy overwrote main's" grep -q '^\$ make test' "$item"
check "worktree removed" [ ! -e "$wt" ]
run "status no longer marks it started" 0 "b-001-crash-on-save +open$" "$WB" status
run "status lists a merged item still open as a fault" 0 "b-001-crash-on-save +merged as [0-9a-f]+" bash -c "'$WB' status | sed -n '/merged, still open/,\$p'"

run "archive takes a short id, with a '## ' line inside the evidence fence" 0 "archived b-001" "$WB" archive b-01

# Line caps on the four documents: a 'cap:' line per file over, none under.
# Padding is appended to copies of the real files and undone after.
cp workbench/BACKLOG.md "$TMP/backlog.orig"; cp CLAUDE.md "$TMP/claude.orig"
check "status says nothing about caps while every file is under" bash -c "! '$WB' status | grep -q '^cap:'"
pad() { local i n; n=$(wc -l < "$1"); for ((i = n; i < $2; i++)); do printf '%s\n' "$3"; done >> "$1"; }  # 'yes | head' takes SIGPIPE under pipefail
pad workbench/BACKLOG.md 401 '- pad'
run "status names a file over its cap with its length" 0 '^cap: workbench/BACKLOG.md 401/400 — cut it' bash -c "'$WB' status | grep '^cap:'"
conf cap.backlog 500
check "cap.<name> in .claude/workshop.conf raises the cap" bash -c "! '$WB' status | grep -q '^cap:'"
conf cap.backlog many
run "a cap that is not a number falls back to the default" 0 '^cap: workbench/BACKLOG.md 401/400' bash -c "'$WB' status | grep '^cap:'"
run "and status names the invalid value" 0 "^config: .claude/workshop.conf: cap.backlog='many' is not a positive integer; the default applies" "$WB" status
unconf cap.backlog
pad CLAUDE.md 151 pad
check "one line per file over, CLAUDE.md first" bash -c "'$WB' status | grep '^cap:' | paste -sd'|' - | grep -qE '^cap: CLAUDE.md 151/150 — cut it; docs.md, Line caps\|cap: workbench/BACKLOG.md 401/400 — cut it; docs.md, Line caps$'"
check "the cap lines come before the items" bash -c "'$WB' status | grep -m1 -nE '^(cap:|open items)' | grep -q 'cap:'"
cp "$TMP/backlog.orig" workbench/BACKLOG.md; cp "$TMP/claude.orig" CLAUDE.md
check "status is silent again once the files are back under" bash -c "! '$WB' status | grep -q '^cap:'"

# The note on 'check' is advisory and this shape has already shipped twice in
# code neither review wrote, so the suite asserts it about itself: a check whose
# command is a bare test bracket followed by &&, ||, ; or a pipe ends at the
# bracket, and everything after it runs outside the check. Quoted patterns
# holding those operators are untouched — the bracket must be the argument.
check "no check call asserts only its first condition" \
  bash -c '! grep -nE "^\s*check \"[^\"]*\" \[[^]]*\] *(&&|\|\||;|\|)" "'"$SELF"'"'

# --- status, adopt ------------------------------------------------------------

idl=$(newc feature "later")          # unstarted, in main
"$WB" start "$idl" >/dev/null 2>&1
set_status ".worktrees/$idl-later/workbench/items/features/$idl-later.md" "awaiting — next deploy"
run "status keeps an awaiting item on its branch under branches" 0 "" bash -c "! '$WB' status | grep -q 'merged, still awaiting a trigger'"
( cd ".worktrees/$idl-later" && git add -A && git commit -qm later )
"$WB" merge "$idl" "later" >/dev/null 2>&1
run "status lists a merged awaiting item" 0 "$idl-later" bash -c "'$WB' status | sed -n '/awaiting a trigger/,\$p'"

# new from inside another item's worktree lands on main, and start cuts the
# new worktree under the main checkout
idi=$(newc bug "inner") && "$WB" start "$idi" >/dev/null 2>&1
idn=$(cd ".worktrees/$idi-inner" && newc bug "nested")
check "new from a worktree writes to the main checkout" [ -f "workbench/items/bugs/$idn-nested.md" ]
check "new from a worktree commits on main" [ "$(git log -1 --format=%s)" = "new $idn: nested" ]
check "the worktree it ran in has no copy" [ ! -e ".worktrees/$idi-inner/workbench/items/bugs/$idn-nested.md" ]
run "start from another worktree" 0 "started $idn-nested in" bash -c "cd .worktrees/$idi-inner && '$WB' start $idn"
check "the nested worktree sits under the main checkout" [ -d ".worktrees/$idn-nested" ]
check "the nested branch carries the item" [ -f ".worktrees/$idn-nested/workbench/items/bugs/$idn-nested.md" ]
# an item written by hand in a worktree, untracked: the criterion is checked
# before it moves, and start moves it to the main checkout when it passes
idw=$("$WB" new bug "in worktree" 2>/dev/null)
git rm -q --cached "workbench/items/bugs/$idw-in-worktree.md" && git commit -qm 'untracked'
mv "workbench/items/bugs/$idw-in-worktree.md" ".worktrees/$idi-inner/workbench/items/bugs/"
run "start refuses an empty criterion before moving a worktree file" 1 "'How to confirm' is empty" "$WB" start "$idw"
check "the file did not move" [ -f ".worktrees/$idi-inner/workbench/items/bugs/$idw-in-worktree.md" ]
crit ".worktrees/$idi-inner/workbench/items/bugs/$idw-in-worktree.md"
run "start moves a hand-written worktree file to main and lands it" 0 "moved workbench/items/bugs/$idw-in-worktree.md from $idi-inner to the main checkout" "$WB" start "$idw"
check "it is committed on main" git ls-files --error-unmatch "workbench/items/bugs/$idw-in-worktree.md"
# an item written by hand, untracked on main, is landed by start
idh=$(newc bug "by hand")
git rm -q --cached "workbench/items/bugs/$idh-by-hand.md" && git commit -qm 'untracked by hand'
run "status labels an uncommitted item" 0 "$idh-by-hand +open +\[not committed" "$WB" status
run "start lands an untracked item" 0 "committed workbench/items/bugs/$idh-by-hand.md on main" "$WB" start "$idh"
check "the hand-written item is tracked now" git ls-files --error-unmatch "workbench/items/bugs/$idh-by-hand.md"

# --- memory in the tree -------------------------------------------------------
# Under ~, init points autoMemoryDirectory into the checkout, and merge
# tolerates its unstaged edits on main.

new_repo home/memproj
run "init sets autoMemoryDirectory under ~" 0 'autoMemoryDirectory = ~/memproj/.claude/memory' "$WB" init
check "the setting is tilde-based" grep -q '"autoMemoryDirectory": "~/memproj/.claude/memory"' .claude/settings.json
run "init leaves the setting alone next time" 0 "" bash -c "! '$WB' init 2>&1 | grep -q 'autoMemoryDirectory ='"
check "under ~ the checklist says memory points into the tree (C4)" bash -c "'$WB' init | grep -q 'memory  .*points at .claude/memory'"
mkdir -p .claude/memory && echo '# Memory' > .claude/memory/MEMORY.md
git add -A && git commit -qm 'init + memory'
newc bug "one" >/dev/null; "$WB" start b-001 >/dev/null 2>&1
( cd .worktrees/b-001-one && echo fix > src.txt && git add -A && git commit -qm fix )
ready .worktrees/b-001-one
echo learned >> .claude/memory/MEMORY.md
run "merge tolerates unstaged memory edits on main" 0 "merged b-001" "$WB" merge b-001 "one"
check "the memory edit stayed out of the squash" bash -c "! git show --stat --format= HEAD | grep -q MEMORY.md"
check "the memory edit is still pending" [ -n "$(git status --porcelain .claude/memory)" ]
git add -A && git commit -qm memory
newc bug "two" >/dev/null; "$WB" start b-002 >/dev/null 2>&1
( cd .worktrees/b-002-two && echo fix2 > src2.txt && git add -A && git commit -qm fix2 )
ready .worktrees/b-002-two
echo staged >> .claude/memory/MEMORY.md && git add .claude/memory/MEMORY.md
run "merge refuses staged memory edits" 1 "staged changes" "$WB" merge b-002 "two"
git reset -q && git checkout -q .claude/memory/MEMORY.md
echo other >> README
run "merge tolerates any unstaged edit on main" 0 "merged b-002" "$WB" merge b-002 "two"
check "the README edit stayed out of the squash" bash -c "! git show --stat --format= HEAD | grep -q README"
check "the README edit is still pending" [ -n "$(git status --porcelain README)" ]
git checkout -q README
# an unstaged deletion is the one edit git would not protect from the squash
newc bug "three" >/dev/null; "$WB" start b-003 >/dev/null 2>&1
( cd .worktrees/b-003-three && echo touched >> README && git add -A && git commit -qm touch )
ready .worktrees/b-003-three
rm README
run "merge refuses an unstaged deletion on main" 1 "uncommitted deletion the squash would undo" "$WB" merge b-003 "three"
check "the refusal names the file" bash -c "'$WB' merge b-003 three 2>&1 | grep -q '^  README'"
git checkout -q README
run "merge goes through once the file is back" 0 "merged b-003" "$WB" merge b-003 "three"

# --- rendered copies: migration from links, staleness, templates ------------

new_repo copies
src_root=$(readlink -f "$(dirname "$WB")/..")  # the workbench root; the CLI sits in its bin/
# shellcheck disable=SC2016  # the backtick is the pattern, not an expansion
bang=$(grep -lE '!`|^```!' "$src_root"/commands/*/SKILL.md || true)
check "no command runs shell before the first turn: a quote or \$ in a title breaks the substituted command, and sizing belongs before an id exists${bang:+ — $bang}" [ -z "$bang" ]
"$WB" init >/dev/null 2>&1
rm -rf .claude/skills/wb && ln -s "$src_root/commands/wb" .claude/skills/wb
mkdir -p .claude/skills/rename && printf "x\nx\ngenerated by 'workbench init' from workbench/commands/rename\n" > .claude/skills/rename/GENERATED
mkdir -p .claude/skills/foreign && printf 'x\nx\nmade elsewhere\n' > .claude/skills/foreign/GENERATED
run "init replaces an old link with a copy" 0 "skills/wb: link replaced by a copy" "$WB" init
check "a foreign GENERATED file is not a workbench stamp" [ -f .claude/skills/foreign/GENERATED ]
rm -rf .claude/skills/foreign
check "the copy is no longer a link" bash -c "[ ! -L .claude/skills/wb ] && [ -f .claude/skills/wb/GENERATED ]"
check "init keeps settings.local.json ignored" grep -qx '.claude/settings.local.json' .gitignore
check "init keeps .worktrees/ ignored" grep -qx '.worktrees/' .gitignore
check "init removes a generated copy of a skill that is gone" [ ! -e .claude/skills/rename ]
# a dropped skill's copy that was edited by hand is refused like any other
cp -R .claude/skills/idea .claude/skills/gone && sed -i "s|from workbench/[^;]*|from workbench/gone|" .claude/skills/gone/GENERATED
echo tweak >> .claude/skills/gone/SKILL.md
run "init refuses to remove an edited copy of a dropped skill" 1 "no longer a workbench skill but was edited by hand" "$WB" init
run "init --force removes it" 0 "removed .claude/skills/gone" "$WB" init --force
# init has just edited the tracked .gitignore; adopt refuses a dirty tree by
# design (tested below), and the subject here is only that --force reaches init
git add -A && git commit -qm "init"
run "adopt takes --force too" 0 "workbench ready" "$WB" adopt --force
sed -i '1s/.*/000000000000/' .claude/skills/wb/GENERATED
run "status lists skills behind their source" 0 "skills behind their source" "$WB" status
run "init re-renders a stale copy" 0 "rendered .claude/skills/wb" "$WB" init
run "status is quiet again" 0 "" bash -c "! '$WB' status | grep -q 'behind their source'"
# a copy edited by hand is named as such, and only --force overwrites it
echo 'my tweak' >> .claude/skills/wb/SKILL.md
run "status names an edited copy" 0 "edited by hand.*init --force" "$WB" status
check "an edited copy is not listed as stale" bash -c "! '$WB' status | grep -q 'behind their source'"
run "init refuses to overwrite an edited copy" 1 "edited by hand since it was rendered" "$WB" init
check "the edit survives the refusal" grep -q 'my tweak' .claude/skills/wb/SKILL.md
run "init --force overwrites it" 0 "rendered .claude/skills/wb \(the hand edit is gone\)" "$WB" init --force
check "the edit is gone" bash -c "! grep -q 'my tweak' .claude/skills/wb/SKILL.md"
run "status is quiet after --force" 0 "" bash -c "! '$WB' status | grep -q 'edited by hand'"
# the stamp does not depend on the locale that rendered it
LC_ALL=en_US.UTF-8 "$WB" init >/dev/null 2>&1
run "status under C agrees with a copy rendered under en_US.UTF-8" 0 "" bash -c "! LC_ALL=C '$WB' status | grep -q 'behind their source'"
# init adds its ignore entry to a .gitignore that already has content
new_repo gi
printf 'node_modules/\n' > .gitignore
run "init writes into an existing .gitignore" 0 "workbench ready" "$WB" init
check ".worktrees/ is ignored" grep -qx '.worktrees/' .gitignore
check "the existing line survives" grep -qx 'node_modules/' .gitignore
cd "$TMP/copies"
mkdir -p .claude/skills/hand && echo x > .claude/skills/hand/SKILL.md
cp -R "$src_root/commands/idea" .claude/skills/idea-copy && rm -rf .claude/skills/idea && mv .claude/skills/idea-copy .claude/skills/idea
run "init refuses a skill dir it did not generate" 1 "was not generated by workbench" "$WB" init
rm -rf .claude/skills/idea
# an overridden source renders
cp -R "$src_root" "$TMP/src"
printf 'probe\n' > "$TMP/src/commands/wb/probe.md"
run "init renders from an overridden source" 0 "rendered .claude/skills/wb" env WORKBENCH_ROOT="$TMP/src" "$WB" init
check "the copy has the source's file" grep -qx 'probe' .claude/skills/wb/probe.md
# the hash sees paths, not just content: a rename in the source is a change
mv "$TMP/src/commands/wb/probe.md" "$TMP/src/commands/wb/probe2.md"
run "a renamed source file shows the copy as stale" 0 "behind their source" env WORKBENCH_ROOT="$TMP/src" "$WB" status
ln -s SKILL.md "$TMP/src/commands/wb/link.md"
run "init refuses a symlink in a source" 1 "is a symlink" env WORKBENCH_ROOT="$TMP/src" "$WB" init
rm "$TMP/src/commands/wb/link.md"

# Agents are named in WB_AGENTS rather than globbed out of agents/, so what
# ships as an agent is a decision and not whatever happens to sit there.
printf 'notes\n' > "$TMP/src/agents/NOTES.md"
env WORKBENCH_ROOT="$TMP/src" "$WB" init >/dev/null 2>&1
check "a stray file under agents/ is not rendered as an agent" [ ! -e .claude/agents/NOTES.md ]
rm "$TMP/src/agents/NOTES.md"
# The other half of naming them: a source that does not exist under its own
# name stops the init instead of leaving the project silently short an agent.
mv "$TMP/src/agents/wb-reviewer.md" "$TMP/src/agents/wb-reviewer.md.bak"
run "a renamed agent source fails the init" 1 "agent source not found" env WORKBENCH_ROOT="$TMP/src" "$WB" init
mv "$TMP/src/agents/wb-reviewer.md.bak" "$TMP/src/agents/wb-reviewer.md"
# An agent copy that no longer matches its source: skill_drift walks
# skill_sources, which is skills and commands, so agents need their own check.
env WORKBENCH_ROOT="$TMP/src" "$WB" init >/dev/null 2>&1
run "status is quiet while the agents match" 0 "" bash -c "! env WORKBENCH_ROOT='$TMP/src' '$WB' status | grep -q 'agents differ'"
printf '\nmoved on\n' >> "$TMP/src/agents/wb-reviewer.md"
run "status reports an agent whose source moved on" 0 "agents differ from their source" env WORKBENCH_ROOT="$TMP/src" "$WB" status
run "status names the agent" 0 "" bash -c "env WORKBENCH_ROOT='$TMP/src' '$WB' status | grep -A1 'agents differ' | grep -q wb-reviewer"
env WORKBENCH_ROOT="$TMP/src" "$WB" init >/dev/null 2>&1
run "init clears the agent drift" 0 "" bash -c "! env WORKBENCH_ROOT='$TMP/src' '$WB' status | grep -q 'agents differ'"

# An agent this tool no longer ships. Only reachable by the deliberate
# two-step: out of WB_AGENTS and deleted from agents/ — agent_sources dies on
# a name it lists but cannot find. Without the reap the copy would stay in the
# project for good, with nothing said by init or status.
printf -- '---\nname: my-own\ndescription: a project agent, nothing to do with workbench\n---\nmine\n' > .claude/agents/my-own.md
cp "$TMP/src/agents/wb-reviewer.md" "$TMP/src/agents/wb-spare.md"
sed -i 's/^name: wb-reviewer$/name: wb-spare/' "$TMP/src/agents/wb-spare.md"
WB_SPARE=$(sed 's/^WB_AGENTS="\(.*\)"$/WB_AGENTS="\1 wb-spare"/' "$WB")
printf '%s' "$WB_SPARE" > "$TMP/bin/wb-spare"; chmod +x "$TMP/bin/wb-spare"
env WORKBENCH_ROOT="$TMP/src" "$TMP/bin/wb-spare" init >/dev/null 2>&1
check "the spare agent is rendered while it is shipped" [ -f .claude/agents/wb-spare.md ]
# retire it: gone from the list, gone from the source
rm "$TMP/src/agents/wb-spare.md"
run "init reaps an agent that is no longer shipped" 0 "removed .claude/agents/wb-spare.md: no longer a workbench agent" env WORKBENCH_ROOT="$TMP/src" "$WB" init
check "the retired copy is gone" [ ! -e .claude/agents/wb-spare.md ]
# The assertion that matters: the reap is guarded by the marker, so a project's
# own agent in the same directory is not collateral.
check "a project's own agent survives the reap" [ -f .claude/agents/my-own.md ]
check "the shipped agents survive the reap" bash -c '[ -f .claude/agents/wb-worker.md ] && [ -f .claude/agents/wb-reviewer.md ]'
rm .claude/agents/my-own.md

# adopt on a symlinked CLAUDE.md edits the target, not the link
new_repo adopt
mkdir -p docs && echo '# adopt' > docs/CLAUDE.md && ln -s docs/CLAUDE.md CLAUDE.md && git add -A && git commit -qm claude
run "adopt" 0 "Now survey" "$WB" adopt
check "adopt keeps CLAUDE.md a symlink" [ -L CLAUDE.md ]
check "adopt writes the block through the link" grep -q 'workbench:start' docs/CLAUDE.md
run "adopt refuses with the first adopt uncommitted" 1 "commit them as the last pre-adoption commit" "$WB" adopt
git add -A && git commit -qm adopt
run "adopt is idempotent" 0 "refreshed the workbench block" "$WB" adopt
check "the block is not duplicated" [ "$(grep -c 'workbench:start' docs/CLAUDE.md)" -eq 1 ]

# --- failure paths ----------------------------------------------------------

new_repo fail
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'

# dirty main
newc bug "one" >/dev/null; "$WB" start b-001 >/dev/null 2>&1
( cd .worktrees/b-001-one && echo a >> README && git add -A && git commit -qm a )
ready .worktrees/b-001-one
echo dirty >> README
run "merge stops when the branch touches a file edited on main" 1 "an uncommitted edit on main is in the way of the branch" "$WB" merge b-001 "one"
check "the stopped squash left main clean" [ -z "$(git -C . status --porcelain --untracked-files=no | grep -v '^ M README')" ]
git checkout -q README
git add README 2>/dev/null; echo staged >> README && git add README
run "merge refuses staged dirt on main" 1 "staged changes; the squash commit would absorb them" "$WB" merge b-001 "one"
git reset -q && git checkout -q README

# generic dirt beyond the item file
( cd .worktrees/b-001-one && echo more >> README )
run "merge names generic dirt generically" 1 "has uncommitted changes; commit or discard" "$WB" merge b-001 "one"
( cd .worktrees/b-001-one && git checkout -q README )

# the item file plus a stray .md: not the item-only case
( cd .worktrees/b-001-one && echo n > notes.md && echo e >> workbench/items/bugs/b-001-one.md )
run "merge with item file and a stray .md is generic" 1 "has uncommitted changes; commit or discard" "$WB" merge b-001 "one"
( cd .worktrees/b-001-one && rm notes.md && git checkout -q workbench/items/bugs/b-001-one.md )

# main's copy edited after start, in a hunk the branch never touched: a
# three-way merge would take it silently, so it is refused before that
sed -i '1a\
edited on main' workbench/items/bugs/b-001-one.md && git commit -qm 'edited on main after start' -- workbench/items/bugs/b-001-one.md
run "merge refuses when main's copy of the item moved since the cut" 1 "main's copy of b-001 changed since b-001-one was cut" "$WB" merge b-001 "one"
check "the refusal touched nothing" [ -z "$(git log --grep='^Item:' --format=%h)" ]
git checkout -q HEAD~1 -- workbench/items/bugs/b-001-one.md && git commit -qm 'main back' -- workbench/items/bugs/b-001-one.md

# The branch copy of the item is the merge gate's only witness. Deleted, every
# check it feeds — fences, status, the trigger, evidence — was skipped silently,
# and the first sign was an archived item whose gate never ran.
( cd .worktrees/b-001-one && git rm -q workbench/items/bugs/b-001-one.md && git commit -qm "drop the item" )
run "merge refuses when the branch carries no item file" 1 "no item file on b-001-one" "$WB" merge b-001 "one"
( cd .worktrees/b-001-one && git checkout -q HEAD~1 -- workbench/items/bugs/b-001-one.md && git commit -qm "restore the item" )

# conflicting branch
echo b >> README && git commit -qam b
run "merge refuses a conflicting branch" 1 "conflicts with main" "$WB" merge b-001 "one"
check "conflict leaves main untouched" [ -z "$(git log --grep='^Item:' --format=%h)" ]

# unreproduced retire: nothing but the item on the branch
newc bug "ghost" >/dev/null; "$WB" start b-002 >/dev/null 2>&1
set_status .worktrees/b-002-ghost/workbench/items/bugs/b-002-ghost.md unreproduced
run "archive retires an unreproduced branch" 0 "retired b-002-ghost" "$WB" archive b-002
check "retire removes the worktree" [ ! -e .worktrees/b-002-ghost ]
check "retire deletes the branch" [ -z "$(git branch --list b-002-ghost)" ]
check "retired item is archived on main" [ -f workbench/items/archive/b-002-ghost.md ]

# unreproduced retire refuses when the branch carries work
newc bug "notghost" >/dev/null; "$WB" start b-003 >/dev/null 2>&1
( cd .worktrees/b-003-notghost && echo w > work.txt && git add -A && git commit -qm w )
set_status .worktrees/b-003-notghost/workbench/items/bugs/b-003-notghost.md unreproduced
run "archive refuses to retire a branch with work" 1 "carries work beyond the item file" "$WB" archive b-003

# retire overwrites main's copy, so a main-side edit since the cut is refused
# rather than lost
idr=$(newc bug "retire-guard"); "$WB" start "$idr" >/dev/null 2>&1
set_status ".worktrees/$idr-retire-guard/workbench/items/bugs/$idr-retire-guard.md" unreproduced
echo kept >> "workbench/items/bugs/$idr-retire-guard.md" && git commit -qm 'main moved' -- "workbench/items/bugs/$idr-retire-guard.md"
run "archive refuses to retire over a main copy that moved" 1 "main's copy of $idr changed since $idr-retire-guard was cut" "$WB" archive "$idr"
check "main's copy still holds its edit" grep -qx kept "workbench/items/bugs/$idr-retire-guard.md"
git checkout -q HEAD~1 -- "workbench/items/bugs/$idr-retire-guard.md" && git commit -qm 'main back' -- "workbench/items/bugs/$idr-retire-guard.md"
run "archive retires once main's copy is back" 0 "retired $idr-retire-guard" "$WB" archive "$idr"

# The squash is not transactional: cleanup after the commit can fail, and the
# commit is already on main when it does. Refused before the commit where the
# worktree cannot be removed, and a re-run of the half-finished state names what
# was left rather than refusing with nowhere to go.
idk=$(newc bug "locked"); "$WB" start "$idk" >/dev/null 2>&1
( cd ".worktrees/$idk-locked" && echo l > l.txt && git add -A && git commit -qm l ); ready ".worktrees/$idk-locked"
git worktree lock ".worktrees/$idk-locked"
run "merge refuses a locked worktree" 1 "worktree .* is locked" "$WB" merge "$idk" "locked"
check "and the refusal came before the commit" [ -z "$(git log --grep="^Item: $idk\$" --format=%h)" ]
git worktree unlock ".worktrees/$idk-locked"
run "merge takes it once unlocked" 0 "merged $idk" "$WB" merge "$idk" "locked"
# the half-finished shape: the trailer is on main, the branch never went away
git branch "$idk-locked" main
run "a re-run names what cleanup left behind" 1 "cleanup after that commit did not finish" "$WB" merge "$idk" "locked"
run "and gives the command that finishes it" 1 "branch -D $idk-locked" "$WB" merge "$idk" "locked"
git branch -D "$idk-locked" >/dev/null
run "with nothing left behind it is the plain refusal" 1 "already carries 'Item: $idk'" "$WB" merge "$idk" "locked"

# an item on its branch alone — never on main at the cut — with the worktree
# gone: archive reads the branch, the guard above does not fire, and no temp
# file is left behind on a refusal
# branch_only <id> <slug> <status> — an item file that exists on its branch
# and nowhere else, worktree already gone.
branch_only() {
  local f="workbench/items/bugs/$1-$2.md"
  git rm -q "$f" && git commit -qm "old-model shape for $1" -- "$f"
  git worktree add -q -b "$1-$2" ".worktrees/$1-$2" main
  git show "HEAD~1:$f" > ".worktrees/$1-$2/$f"
  crit ".worktrees/$1-$2/$f"; set_status ".worktrees/$1-$2/$f" "$3"
  ( cd ".worktrees/$1-$2" && git add -A && git commit -qm 'item on the branch alone' )
  git worktree remove ".worktrees/$1-$2"
}
ido=$("$WB" new bug "old-model" 2>/dev/null); branch_only "$ido" old-model unreproduced
idb=$("$WB" new bug "bogus-status" 2>/dev/null); branch_only "$idb" bogus-status nonsense
check "setup: neither item is in any checkout" [ -z "$(find . -name "$ido-*.md" -o -name "$idb-*.md")" ]
run "status lists a branch-only item, from its branch" 0 "$ido-old-model +unreproduced +started +\[on its branch only" "$WB" status
before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)
run "archive refuses a bogus status read from the branch" 1 "has 'status: nonsense', which is not a status" "$WB" archive "$idb"
check "the refusal left no temp file behind" [ "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)" -eq "$before" ]
git branch -qD "$idb-bogus-status"
run "archive reads a branch-only item when the worktree is gone" 0 "retired $ido-old-model" "$WB" archive "$ido"
check "the archived copy is the branch's" grep -q '^status: unreproduced' "workbench/items/archive/$ido-old-model.md"
check "the archive left no temp file behind" [ "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)" -eq "$before" ]

# duplicate ids
cp workbench/items/archive/b-002-ghost.md workbench/items/bugs/b-002-again.md
run "status flags duplicate ids" 0 "DUPLICATE IDS" "$WB" status
rm workbench/items/bugs/b-002-again.md

# the branch's item copied onto main by hand is main's copy moving since the
# cut, and is refused as such; the work copied by hand alone is tolerated,
# and the squash then carries the item file only
idd=$(newc bug "dup"); "$WB" start "$idd" >/dev/null 2>&1
( cd ".worktrees/$idd-dup" && echo same > same.txt && git add -A && git commit -qm same )
ready ".worktrees/$idd-dup"
cp ".worktrees/$idd-dup/same.txt" . && cp ".worktrees/$idd-dup/workbench/items/bugs/$idd-dup.md" workbench/items/bugs/
git add -A && git commit -qm 'same by hand' -- same.txt "workbench/items/bugs/$idd-dup.md"
run "merge refuses the branch's item copied onto main by hand" 1 "main's copy of $idd changed since $idd-dup was cut" "$WB" merge "$idd" "dup"
check "the refusal left main clean" [ -z "$(git status --porcelain --untracked-files=no)" ]
git checkout -q HEAD~1 -- "workbench/items/bugs/$idd-dup.md" && git commit -qm 'item back' -- "workbench/items/bugs/$idd-dup.md"
run "merge with the work already on main carries the item alone" 0 "merged $idd" "$WB" merge "$idd" "dup"
check "the squash holds only the item file" [ "$(git show --stat --format= HEAD | grep -c '|')" -eq 1 ]

# another item's file written on the branch would ride the squash under the
# wrong trailer; one landed on main since the cut is not on the branch
idh=$(newc bug "host"); "$WB" start "$idh" >/dev/null 2>&1
ready ".worktrees/$idh-host"
idg=$(newc feature "guest")
check "an item landed after the cut is not on the branch" [ -z "$(git diff --name-only "main...$idh-host" | grep guest)" ]
cp "workbench/items/features/$idg-guest.md" ".worktrees/$idh-host/workbench/items/features/"
( cd ".worktrees/$idh-host" && git add -A && git commit -qm 'guest by hand' )
run "merge refuses a branch carrying another item's file" 1 "carries another item's file" "$WB" merge "$idh" "host"
check "the refusal names the guest file" bash -c "'$WB' merge $idh host 2>&1 | grep -q '^  workbench/items/features/$idg-guest.md$'"
check "the refusal does not name the host's own file" bash -c "! '$WB' merge $idh host 2>&1 | grep -q '$idh-host.md'"
check "nothing landed on main" [ -z "$(git log --grep="^Item: $idh" --format=%h)" ]
( cd ".worktrees/$idh-host" && git rm -q "workbench/items/features/$idg-guest.md" && git commit -qm 'guest off' )
run "merge goes through once the file is off the branch" 0 "merged $idh" "$WB" merge "$idh" "host"
check "the squash carries only the host's item" bash -c "! git show --stat --format= HEAD | grep -q guest"

# --- lookups over every worktree --------------------------------------------
# A detached worktree with no workbench/, an item created in a sibling, a
# worktree removed by hand, and archive
# run from a sibling that inherited the merged copy.

new_repo roots
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
git worktree add -q --detach "$TMP/roots-plain" HEAD   # lacks workbench/ entirely
newc bug "one" >/dev/null
run "status with a detached worktree present" 0 "b-001-one" "$WB" status
run "archive with a detached worktree present reports, not dies" 1 "no evidence recorded" "$WB" archive b-001
"$WB" start b-001 >/dev/null 2>&1
ids=$(cd .worktrees/b-001-one && newc bug "from sibling")
run "start an item created from another worktree" 0 "started $ids-from-sibling in" "$WB" start "$ids"
check "the worktree it was created from has no copy" [ ! -e ".worktrees/b-001-one/workbench/items/bugs/$ids-from-sibling.md" ]

ready .worktrees/b-001-one
rm -rf .worktrees/b-001-one
run "status survives a worktree removed by hand" 0 "b-001-one +open +started" "$WB" status
run "merge names the unpruned worktree" 1 "git worktree prune" "$WB" merge b-001 "one"
git worktree prune
echo diverge >> README && git commit -qam diverge
run "merge after prune" 0 "merged b-001" "$WB" merge b-001 "one"
ready ".worktrees/$ids-from-sibling"
echo diverge >> README && git commit -qam diverge2
out=$("$WB" merge "$ids" "two" 2>&1)
check "merge prints nothing of git's own on success" [ "$(grep -c 'Automatic merge' <<< "$out")" -eq 0 ]

# archive from a sibling worktree: main's copy is the item's home
fill_evidence workbench/items/bugs/b-001-one.md "run" "ok"
idy=$(newc bug "sibling"); "$WB" start "$idy" >/dev/null 2>&1
check "setup: the sibling inherited b-001's merged copy" [ -f ".worktrees/$idy-sibling/workbench/items/bugs/b-001-one.md" ]
run "archive from a sibling worktree archives main's copy" 0 "archived b-001" bash -c "cd .worktrees/$idy-sibling && '$WB' archive b-001"
check "main's copy is in the archive" [ -f workbench/items/archive/b-001-one.md ]
check "the sibling's copy is untouched" [ -f ".worktrees/$idy-sibling/workbench/items/bugs/b-001-one.md" ]
run "status does not list the sibling's stale copy of an archived item" 0 "" bash -c "! '$WB' status | grep -q b-001-one"

# --- resume: a branch without a worktree ------------------------------------
# The item is edited on its branch, so once the worktree is gone main's copy
# is the item as it started and the ref holds the work; start must find the
# ref. Locally after a worktree remove, and on another machine where the
# branch is only fetched.

new_repo home/resume
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
newc bug "gone" >/dev/null; "$WB" start b-001 >/dev/null 2>&1
( cd .worktrees/b-001-gone && echo w > work.txt && git add -A && git commit -qm work )
run "start on a started item names its worktree" 1 "already started; its worktree is" "$WB" start b-001
( cd .worktrees/b-001-gone && sed -i '/^agreed with the user$/d' workbench/items/bugs/b-001-gone.md && git commit -qam 'criterion gone' )
git worktree remove .worktrees/b-001-gone
run "start resumes a branch whose worktree was removed" 0 "resumed b-001-gone" "$WB" start b-001
run "resume notes an empty criterion rather than refusing" 1 "already started" "$WB" start b-001
check "the resume printed the note" bash -c "git worktree remove .worktrees/b-001-gone && '$WB' start b-001 2>&1 | grep -q \"note: b-001's 'How to confirm' is empty\""
check "the resumed worktree holds the branch" [ "$(git -C .worktrees/b-001-gone symbolic-ref --short HEAD)" = b-001-gone ]
check "the item file is there, from the branch" [ -f .worktrees/b-001-gone/workbench/items/bugs/b-001-gone.md ]
check "the work is there" [ -f .worktrees/b-001-gone/work.txt ]
check "main's copy is the item as it started" grep -q '^agreed with the user$' workbench/items/bugs/b-001-gone.md
rm -rf .worktrees/b-001-gone
run "start on a worktree removed by hand says to prune" 1 "git worktree prune" "$WB" start b-001
git worktree prune
run "start resumes after the prune" 0 "resumed b-001-gone" "$WB" start b-001
git branch -q b-001-other main
run "start refuses when several branches match" 1 "several branches match b-001" "$WB" start b-001
# start reaches the check through item_branch; merge and archive call it
# directly, and those two call sites had no test of their own — sharing one
# implementation is not the same as covering the paths into it. A wrong id or
# a wrong root at either would fail silently otherwise.
run "merge refuses when several branches match" 1 "several branches match b-001" "$WB" merge b-001 "two branches"
run "archive refuses when several branches match" 1 "several branches match b-001" "$WB" archive b-001
git branch -qD b-001-other
# a second machine: the branch exists only on origin
git clone -q --bare . "$TMP/resume-origin"
git clone -q "$TMP/resume-origin" "$TMP/home/resume-clone" 2>/dev/null
cd "$TMP/home/resume-clone"
check "setup: the clone has no local item branch" [ -z "$(git branch --list 'b-001-*')" ]
run "status in a clone at another path warns about the memory setting" 0 "autoMemoryDirectory points at .*resume/.claude/memory, not this checkout" "$WB" status
run "start resumes a branch only on origin" 0 "resumed b-001-gone" "$WB" start b-001
check "the branch now exists locally" [ -n "$(git branch --list b-001-gone)" ]
check "it tracks origin" [ "$(git -C .worktrees/b-001-gone rev-parse --abbrev-ref '@{upstream}')" = origin/b-001-gone ]
check "the item file came with it" [ -f .worktrees/b-001-gone/workbench/items/bugs/b-001-gone.md ]
run "status at the same path as init is quiet about memory" 0 "" bash -c "cd '$TMP/home/resume' && ! '$WB' status | grep -q autoMemoryDirectory"
# the local override status suggests is not nagged about; a redundant one is
echo '{"autoMemoryDirectory":"~/resume-clone/.claude/memory"}' > .claude/settings.local.json
run "status is quiet once the clone overrides the memory path" 0 "" bash -c "! '$WB' status | grep -q autoMemoryDirectory"
check "init does not nag about a differing local override" bash -c "! '$WB' init 2>&1 | grep -q 'the local one is redundant'"
echo '{"autoMemoryDirectory":"~/resume/.claude/memory"}' > .claude/settings.local.json
run "init names a local override that repeats the project value" 0 "the local one is redundant" "$WB" init
rm .claude/settings.local.json
# The no-python3 leg reads the setting by scanning text, and a compact
# settings.json puts every key on one line. A greedy 's/.*"key".*/\1/' takes
# the LAST match on that line, so a nested copy under any other object wins
# over the top-level setting; the scan must take the first. Written in the
# direction the file is actually written — top-level key first, decoy after —
# because reversed, first-match is wrong too and the check would pass for the
# wrong reason. Run under $NOJSON: with python3 present this leg never runs.
printf '{"autoMemoryDirectory":"~/resume/.claude/memory","hooks":{"autoMemoryDirectory":"~/DECOY/.claude/memory"}}' > .claude/settings.local.json
run "the no-python3 memory scan takes the top-level key, not a nested one" 0 "resume/.claude/memory" \
  bash -c "PATH=\"\$NOJSON\" '$WB' status"
check "and does not report the nested decoy" bash -c "! PATH=\"\$NOJSON\" '$WB' status | grep -q DECOY"
rm .claude/settings.local.json
# origin's ref outlives the merge and the archive; neither may be resumed
ready .worktrees/b-001-gone
"$WB" merge b-001 "gone" >/dev/null 2>&1
check "setup: b-001 merged in the clone" [ -n "$(git log --grep='^Item: b-001$' --format=%h)" ]
check "setup: origin still has the branch after the merge" [ -n "$(git branch -r --list origin/b-001-gone)" ]
run "start refuses a merged item whose ref is left on origin" 1 "already merged as [0-9a-f]+; origin/b-001-gone is a leftover" "$WB" start b-001
check "no worktree was cut for it" [ ! -e .worktrees/b-001-gone ]
fill_evidence workbench/items/bugs/b-001-gone.md "run" "ok"
"$WB" archive b-001 >/dev/null 2>&1
run "start refuses an archived item whose ref is left on origin" 1 "already archived" "$WB" start b-001

# --- gates: calls, rounds ---------------------------------------------------

new_repo gates
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
echo "stray" > stray.txt
run "call on an unknown item refuses" 1 "no item matching" "$WB" call b-001 "criterion: is the count right?"
cid=$(newc bug "count")
citem=workbench/items/bugs/$cid-count.md
run "call parks a question in the item's Decisions" 0 "$citem$" "$WB" call "$cid" "criterion: is the count right?"
check "the call is one bullet under ## Decisions" bash -c "sed -n '/^## Decisions/,\$p' $citem | grep -qx -- '- criterion: is the count right?'"
check "call committed the item on main, so a gate that reads git sees it (C10)" bash -c "[ \"\$(git log -1 --format=%s)\" = 'call $cid' ] && git diff --quiet -- $citem"
check "and committed nothing else" bash -c "git status --porcelain | grep -q '^?? stray.txt'"
rm stray.txt
check "the template has the section" grep -q '^## Decisions' "$citem"
run "call takes - for no item" 0 "" "$WB" call - "which realm first?"
check "the id-less call is a bullet in DECISIONS.md" grep -qx -- '- which realm first?' workbench/DECISIONS.md
run "call refuses a newline" 1 "a call is one line" "$WB" call - $'a\nb'
run "call refuses an essay" 1 "one question under" "$WB" call - "$(printf 'x%.0s' $(seq 1 301))"
run "status lists decisions waiting in items" 0 "decisions waiting on the user" "$WB" status
check "status prints the item's decision line" bash -c "'$WB' status | grep -q '^  $cid-count  *criterion: is the count right?$'"
run "status lists id-less calls too" 0 "calls waiting on the user" "$WB" status
"$WB" start "$cid" >/dev/null 2>&1
cwt=.worktrees/$cid-count
run "call on a started item goes to the worktree copy" 0 "$cwt/$citem$" "$WB" call "$cid" "greeting: move or drop?"
check "and is committed on the branch, not main" bash -c "[ \"\$(git -C $cwt log -1 --format=%s)\" = 'call $cid' ] && ! grep -q 'greeting' $citem"
check "status reads the branch's copy" bash -c "'$WB' status | grep -q 'greeting: move or drop?'"
git rm -q workbench/DECISIONS.md && git commit -qm "answered"
# the worker's own call and a new item on main do not put the branch behind main
conf premerge true
newc bug "found meanwhile" >/dev/null
fill_evidence "$cwt/$citem" "run" "ok"
( cd "$cwt" && git commit -qam evidence )
run "merge is not behind main when only workbench/ landed since" 0 "merged $cid" "$WB" merge "$cid" "count"
check "the branch's decision line survived the squash" bash -c "sed -n '/^## Decisions/,\$p' $citem | grep -q 'greeting: move or drop?'"
run "archive refuses an item with a decision waiting" 1 "has a decision waiting under '## Decisions'" "$WB" archive "$cid"
sed -i '/^- greeting: move or drop?$/d; /^- criterion: is the count right?$/d' "$citem" && git commit -qam answered
run "archive takes it once the lines are gone" 0 "" "$WB" archive "$cid"
cid2=$(newc bug "behind")
"$WB" start "$cid2" >/dev/null 2>&1
mkdir -p src && echo code > src/landed.ts && git add -A && git commit -qm "code landed on main"
fill_evidence ".worktrees/$cid2-behind/workbench/items/bugs/$cid2-behind.md" "run" "ok"
( cd ".worktrees/$cid2-behind" && git commit -qam evidence )
run "merge is behind main when code landed since" 1 "is behind main" "$WB" merge "$cid2" "behind"
unconf premerge

uid=$(newc bug "awaiting"); "$WB" start "$uid" >/dev/null 2>&1
wt=.worktrees/$uid-awaiting
( cd "$wt" && echo w > w.txt && git add -A && git commit -qm w )
set_status "$wt/workbench/items/bugs/$uid-awaiting.md" 'awaiting — the next deploy'
( cd "$wt" && git commit -qam awaiting )
run "merge accepts an awaiting status" 0 "merged $uid" "$WB" merge "$uid" "awaiting"
run "status lists it merged and still awaiting" 0 "$uid-awaiting  *awaiting — the next deploy" "$WB" status
set_status "workbench/items/bugs/$uid-awaiting.md" 'unverified — the next deploy'
run "archive takes it" 0 "archived $uid" "$WB" archive "$uid"

# --- round: the review dialog's accountant ------------------------------------
# Round 2 always runs; after that the count decides, and the cap parks it.
rd=$(newc bug "rounds"); rdf=workbench/items/bugs/$rd-rounds.md
run "round 1 always asks for round 2" 0 "next: review again" "$WB" round "$rd" 0 0
check "round writes the rounds line under the status line" bash -c "sed -n '/^status: /{n;p}' $rdf | grep -qx 'rounds: r1 0/0 · again'"
run "a second round with one fix after a clean one stops" 0 "next: ready — report the item to the user" "$WB" round "$rd" 1 0
check "the line records both rounds and the decision" grep -qx 'rounds: r1 0/0 · r2 1/0 · stop' "$rdf"
run "round refuses a count that is not a number" 1 "fixed and stands are counts" "$WB" round "$rd" x 0
rd2=$(newc bug "rounds on"); rdf2=workbench/items/bugs/$rd2-rounds-on.md
"$WB" round "$rd2" 5 1 >/dev/null
run "three fixes keep the dialog going" 0 "next: review again" "$WB" round "$rd2" 3 0
"$WB" round "$rd2" 3 0 >/dev/null; "$WB" round "$rd2" 3 0 >/dev/null
run "the fifth round parks it" 0 "next: call" "$WB" round "$rd2" 3 0
check "the cap is recorded on the item" grep -qx 'rounds: r1 5/1 · r2 3/0 · r3 3/0 · r4 3/0 · r5 3/0 · call' "$rdf2"
git add -A && git commit -qm rounds

# --- abandoned: the one exit for work the user drops --------------------------

new_repo drop
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
# an unproved item naming the path, older than the abandoned one below
idu=$(newc bug "unproved"); printf '\nsee src/realm.ts\n' >> "workbench/items/bugs/$idu-unproved.md"
set_status "workbench/items/bugs/$idu-unproved.md" 'unverified — a third party'
"$WB" archive "$idu" >/dev/null 2>&1
# never started: on main only
idn=$(newc feature "never started"); fn=workbench/items/features/$idn-never-started.md
set_status "$fn" abandoned
run "archive refuses abandoned without a why" 1 "'abandoned' must say why" "$WB" archive "$idn"
set_status "$fn" 'abandoned — superseded by the realm rewrite'
run "archive takes an abandoned item never started" 0 "archived $idn at none" "$WB" archive "$idn"
check "it records no commit" grep -qx 'commit: none' "workbench/items/archive/$idn-never-started.md"
# started, with half-built work on the branch
idh=$(newc feature "half built"); "$WB" start "$idh" >/dev/null 2>&1
wt=.worktrees/$idh-half-built; fh=$wt/workbench/items/features/$idh-half-built.md
( cd "$wt" && echo half > half.txt && git add -A && git commit -qm half )
printf '\ntouches src/realm.ts\n' >> "$fh"
set_status "$fh" 'abandoned — not worth finishing'
( cd "$wt" && git commit -qam abandon && echo more > scratch.txt )
run "merge refuses an abandoned item" 1 "abandoned and never merges" "$WB" merge "$idh" "half"
run "archive refuses to drop the work unasked" 1 "archive $idh --discard" "$WB" archive "$idh"
check "the refusal names the uncommitted scratch" bash -c "'$WB' archive $idh 2>&1 | grep -q scratch.txt"
( cd "$wt" && rm scratch.txt )
check "the refusal names the committed work once the scratch is gone" bash -c "'$WB' archive $idh 2>&1 | grep -q half.txt"
( cd "$wt" && echo more > scratch.txt )
rc=0; out=$("$WB" archive "$idh" --discard 2>&1) || rc=$?
check "--discard retires an abandoned branch" [ "$rc" -eq 0 ]
check "--discard names the committed work" grep -q half.txt <<< "$out"
check "--discard names the uncommitted scratch" grep -q scratch.txt <<< "$out"
check "the worktree and branch are gone" bash -c "[ ! -e '$wt' ] && [ -z \"\$(git branch --list '$idh-half-built')\" ]"
check "the archived copy carries the why" grep -q '^status: abandoned — not worth finishing' "workbench/items/archive/$idh-half-built.md"
# --discard stays refused where nothing is ever dropped
idg=$(newc bug "ghost"); "$WB" start "$idg" >/dev/null 2>&1
set_status ".worktrees/$idg-ghost/workbench/items/bugs/$idg-ghost.md" unreproduced
run "--discard is refused for an unreproduced bug" 1 "for abandoned items" "$WB" archive "$idg" --discard
"$WB" archive "$idg" >/dev/null 2>&1
# shipped work is not abandoned
ids=$(newc bug "shipped"); "$WB" start "$ids" >/dev/null 2>&1
( cd ".worktrees/$ids-shipped" && echo s > s.txt && git add -A && git commit -qm s ); ready ".worktrees/$ids-shipped"
"$WB" merge "$ids" "shipped" >/dev/null 2>&1
set_status "workbench/items/bugs/$ids-shipped.md" 'abandoned — changed my mind'
run "archive refuses abandoned on merged work" 1 "shipped work is not abandoned" "$WB" archive "$ids"
run "status lists merged-then-abandoned as a fault, not silence" 0 "$ids-shipped +merged as [0-9a-f]+, yet 'abandoned — changed my mind' — archive will refuse" \
  bash -c "'$WB' status | sed -n '/merged, still open/,\$p'"
# A path named for the default branch makes 'git log main' ambiguous. Swallowed,
# the fatal reads as "no commit carries the trailer", so the refusal above turns
# into a no-op and shipped work archives as abandoned with no trace.
touch main && git add main && git commit -qm "a file named for the branch"
run "and refuses it with a file named 'main' in the tree" 1 "shipped work is not abandoned" "$WB" archive "$ids"
git rm -q main && git commit -qm "drop the file named for the branch"

# --- ideas land on the main checkout --------------------------------------

new_repo idea
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
run "idea appends a bullet to the backlog" 0 "workbench/BACKLOG.md$" "$WB" idea "batch the saves"
check "the line is there, as a bullet" grep -qx -- '- batch the saves' workbench/BACKLOG.md
run "idea refuses a newline" 1 "one line" "$WB" idea $'two\nlines'
run "idea takes one argument" 2 "usage" "$WB" idea two words
newc bug "host" >/dev/null; "$WB" start b-001 >/dev/null 2>&1
run "idea from a worktree writes to the main checkout" 0 "^$PWD/workbench/BACKLOG.md$" bash -c "cd .worktrees/b-001-host && '$WB' idea 'from the worktree'"
check "the worktree's backlog is untouched" bash -c "! grep -q 'from the worktree' .worktrees/b-001-host/workbench/BACKLOG.md"
check "main's backlog has both lines" [ "$(grep -c '^- ' workbench/BACKLOG.md)" -eq 2 ]

# --- worktree cut before the init commit ------------------------------------

new_repo early
"$WB" init >/dev/null           # left uncommitted: main has no workbench/
newc bug "early" >/dev/null
run "start notes an uncommitted .claude" 0 "lacks the workbench commands" "$WB" start b-001
# The worktree's workbench/ holds nothing tracked but the item; the item must
# still be seen as the one file it is, not as the directory.
set_status .worktrees/b-001-early/workbench/items/bugs/b-001-early.md unreproduced
run "archive retires a branch whose workbench/ is untracked" 0 "retired b-001-early" "$WB" archive b-001

# --- premerge: the project's own gate, run in the worktree before the squash --
new_repo "premerge"
"$WB" init >/dev/null
printf '%s\n' '{"name":"p","scripts":{"gate":"node -e \"require(\\\"left-pad\\\")\""}}' > package.json
git add -A && git commit -qm wb
pid=$(newc bug "premerge")
"$WB" start "$pid" >/dev/null 2>&1
pwt=.worktrees/$pid-premerge
ready "$pwt"
conf premerge "npm run -s gate"
run "a premerge that fails names the branch and the worktree's missing dependencies, not a toolchain (C9)" 1 "premerge check failed.*install them there" "$WB" merge "$pid" "gated"
check "and never tells the user to npm ci" bash -c "! '$WB' merge '$pid' gated 2>&1 | grep -q 'npm ci'"
conf premerge "pwd >> '$TMP/premerge.log' && test -e '$TMP/premerge-pass'"
run "merge refuses when the premerge command fails" 1 "premerge check failed" "$WB" merge "$pid" "gated"
check "and the branch is still there" git show-ref -q --verify "refs/heads/$pid-premerge"
check "and the command ran in the worktree" bash -c "[ \"\$(readlink -f \"\$(tail -1 '$TMP/premerge.log')\")\" = \"\$(readlink -f '$pwt')\" ]"
touch "$TMP/premerge-pass"
run "merge proceeds when it passes" 0 "merged $pid" "$WB" merge "$pid" "gated"
pid2=$(newc bug "premerge gone")
"$WB" start "$pid2" >/dev/null 2>&1
ready ".worktrees/$pid2-premerge-gone"
git worktree remove ".worktrees/$pid2-premerge-gone"
run "merge refuses a branch with no worktree to run the command in" 1 "no worktree to run it in" "$WB" merge "$pid2" "gone"
unconf premerge
run "and merges once the key is gone" 0 "merged $pid2" "$WB" merge "$pid2" "gone"

# --- premerge unset is said at status; a branch behind main is refused (A6, A2)
new_repo "stale"
"$WB" init >/dev/null
printf 'export const foo = () => 1;\n' > a.mjs
git add -A && git commit -qm wb
run "status says when premerge is unset" 0 "premerge: unset" "$WB" status
conf premerge true
run "status is quiet about premerge once set" 0 "" bash -c "! '$WB' status | grep -q 'premerge: unset'"
sa=$(newc feature "use foo")
"$WB" start "$sa" >/dev/null 2>&1
sb=$(newc feature "rename foo")
"$WB" start "$sb" >/dev/null 2>&1
( cd ".worktrees/$sb-rename-foo" && sed -i 's/foo/bar/g' a.mjs && git commit -qam rename )
ready ".worktrees/$sb-rename-foo"
run "the later branch merges" 0 "merged $sb" "$WB" merge "$sb" "rename"
( cd ".worktrees/$sa-use-foo" && printf 'import { foo } from "./a.mjs";\nexport const y = foo();\n' > c.mjs && git add c.mjs && git commit -qm use )
ready ".worktrees/$sa-use-foo"
run "merge refuses a branch cut before that merge while premerge is set" 1 "is behind main" "$WB" merge "$sa" "use"
( cd ".worktrees/$sa-use-foo" && git rebase -q main >/dev/null 2>&1 )
run "and merges once rebased" 0 "merged $sa" "$WB" merge "$sa" "use"
unconf premerge

# --- a criterion step that only says the gate exits 0 is refused at start (C11)
# Workbench knows no toolchain: the tool's own commands are refused only once
# 'git config workbench.guards' names them; "behaviour unchanged" always is.
sc=$(newc feature "guarded")
scf=$(find workbench/items -name "$sc-*.md" -print -quit)
# shellcheck disable=SC2016  # literal backticks for the item file
sed -i '/^## How to confirm/a\
\
2. `npm run gate` exits 0 on the branch' "$scf"
git commit -qam guard
git config workbench.guards 'npm run (gate|lint|build|typecheck)'
run "start refuses a gate-only criterion step once workbench.guards names it (C11)" 1 "guard, not a check" "$WB" start "$sc"
git config --unset workbench.guards
sed -i '/^2\. .*gate.*/a\
3. behaviour is unchanged' "$scf"
git commit -qam builtin
run "start refuses a built-in guard with workbench.guards unset" 1 "guard, not a check: 3. behaviour is unchanged" "$WB" start "$sc"
sed -i '/^3\. behaviour is unchanged/d' "$scf"
git commit -qam unbuiltin
run "start accepts a project's tool run as a step while workbench.guards is unset — the toolchain's words are the tool's to set" 0 "" "$WB" start "$sc"

# --- side effects: agreed before start --------------------------------------
new_repo "effects"
"$WB" init >/dev/null
git add -A && git commit -qm wb
se=$("$WB" new feature "rename foo" 2>/dev/null)
sef=$(find workbench/items -name "$se-*.md" -print -quit)
sed -i '/^## How to confirm/a\
\
agreed' "$sef"
git commit -qam crit
run "start refuses an empty Side effects" 1 "'Side effects' is empty" "$WB" start "$se"
effects "$sef" "none"
git commit -qam none
run "start accepts 'none'" 0 "" "$WB" start "$se"
# an old item without the section: the resume path notes it, the fresh path refuses
so=$("$WB" new bug "old shape" 2>/dev/null)
sof=$(find workbench/items -name "$so-*.md" -print -quit)
sed -i '/^## Side effects/,/^## How to confirm/{ /^## How to confirm/!d }' "$sof"
sed -i '/^## How to confirm/a\
\
agreed' "$sof"
git commit -qam old
run "start refuses an item with no Side effects section" 1 "'Side effects' is empty" "$WB" start "$so"

# --- .claude/workshop.conf: settings, rendered copies, migration -------------

new_repo conf
src_root=$(readlink -f "$(dirname "$WB")/..")
run "init with no settings file" 0 "workbench ready" "$WB" init
check "init writes every workbench key at its default, premerge and main commented out" bash -c "[ \"\$(grep -Ec '^(# )?[a-z_.]+=' .claude/workshop.conf)\" -eq 12 ] && grep -qx 'review.round_cap=5' .claude/workshop.conf && grep -qx '# premerge=<command>' .claude/workshop.conf && grep -qx '# main=main' .claude/workshop.conf"
check "and no ts-gate key without ts-gate" bash -c "! grep -qE '^(gate|lint)\.' .claude/workshop.conf"
run "at the defaults status has nothing to say about the file" 0 "" bash -c "! '$WB' status | grep -q '^config:'"
cp .claude/workshop.conf "$TMP/conf.fresh"
"$WB" init >/dev/null
check "a second init leaves the file as it was" cmp -s .claude/workshop.conf "$TMP/conf.fresh"
run "config list shows a workbench key from the file" 0 "^review.round_cap +file +5$" "$WB" config list
check "config with no subcommand lists" bash -c "[ \"\$('$WB' config)\" = \"\$('$WB' config list)\" ]"
check "config list names the twelve workbench keys and no ts-gate key without ts-gate" bash -c "[ \"\$('$WB' config list | wc -l)\" -eq 12 ] && ! '$WB' config list | grep -qE '^(gate|lint)\.'"
run "config list shows premerge unset" 0 "^premerge +default +\(none\)$" "$WB" config list
run "config list shows main auto-detected" 0 "^main +default +main \(auto-detect\)$" "$WB" config list
run "config get prints the default" 0 "^6$" "$WB" config get review.exchange_cap
run "config get main resolves the branch" 0 "^main$" "$WB" config get main
run "config get refuses an unknown key" 1 "no key 'nope'" "$WB" config get nope
check "no rendered copy carries a token" bash -c "! grep -rqE '@@[A-Z_]+@@' .claude/agents .claude/skills"
check "at the defaults neither agent carries model: or effort:" bash -c "! grep -qE '^(effort|model):' .claude/agents/wb-reviewer.md .claude/agents/wb-worker.md"
check "at the defaults an agent copy is its source with the token filled" bash -c "diff <(sed 's/@@REVIEW_EXCHANGE_CAP@@/6/g' '$src_root/agents/wb-reviewer.md') .claude/agents/wb-reviewer.md && diff <(sed 's/@@REVIEW_EXCHANGE_CAP@@/6/g' '$src_root/agents/wb-worker.md') .claude/agents/wb-worker.md"
check "the skill copy states the default caps" bash -c "grep -q 'at round 5 parks it' .claude/skills/workbench/SKILL.md && grep -qF '| root \`CLAUDE.md\` | 150 |' .claude/skills/workbench/references/docs.md"
run "status says nothing about config with no file" 0 "" bash -c "! '$WB' status | grep -q '^config:'"

# The hooks that apply a settings change: watch at session start, render on change.
WATCH_HOOK='command -v workbench >/dev/null && workbench config watch || true'
RENDER_HOOK='command -v workbench >/dev/null && workbench config render || true'
check "init adds the watch hook as its own SessionStart entry" python3 -c "
import json, sys; g = json.load(open('.claude/settings.json'))['hooks']['SessionStart']
w = [x for x in g if any(h['command'] == sys.argv[1] for h in x['hooks'])]
assert len(w) == 1 and len(w[0]['hooks']) == 1" "$WATCH_HOOK"
check "init adds the FileChanged render hook on workshop.conf" python3 -c "
import json, sys; g = json.load(open('.claude/settings.json'))['hooks']['FileChanged']
assert [x.get('matcher') for x in g] == ['workshop.conf'] and [h['command'] for h in g[0]['hooks']] == [sys.argv[1]]" "$RENDER_HOOK"
"$WB" init >/dev/null 2>&1
check "a second init duplicates neither hook" bash -c "[ \"\$(grep -c 'workbench config watch' .claude/settings.json)\" -eq 1 ] && [ \"\$(grep -c 'workbench config render' .claude/settings.json)\" -eq 1 ]"
run "config watch hands Claude Code the file's absolute path" 0 "^\{\"hookSpecificOutput\":\{\"hookEventName\":\"SessionStart\",\"watchPaths\":\[\"$PWD/.claude/workshop.conf\"\]\}\}$" "$WB" config watch
run "config watch says nothing outside a repository" 0 "" bash -c "cd / && [ -z \"\$('$WB' config watch)\" ]"
for h in "$WATCH_HOOK" "$RENDER_HOOK"; do
  run "without workbench on PATH the hook exits 0 and says nothing: ${h#*&& }" 0 "" bash -c "[ -z \"\$(PATH=\"\$NOJSON\" bash -c '$h' 2>&1)\" ]"
done
git add -A && git commit -qm 'workbench init'

# Each workbench key reaches its consumer.
conf worker.model sonnet
conf worker.effort high
conf reviewer.model claude-haiku-4-5
conf reviewer.effort low
conf review.exchange_cap 4
conf review.round_cap 3
conf cap.claude 7
out=$("$WB" config render 2>&1)
check "config render re-renders the agents and the workbench skill" bash -c "grep -q 'rendered .claude/agents/wb-worker.md' <<< '$out' && grep -q 'rendered .claude/agents/wb-reviewer.md' <<< '$out' && grep -q 'rendered .claude/skills/workbench$' <<< '$out'"
check "and not the commands, which carry no setting" bash -c "! grep -qE 'skills/(bug|feature|idea|wb)$' <<< '$out'"
check "the worker's frontmatter ends model:, effort:" bash -c "sed -n '2,/^---\$/p' .claude/agents/wb-worker.md | tail -3 | paste -sd'|' | grep -qx 'model: sonnet|effort: high|---'"
check "the reviewer's too" bash -c "sed -n '2,/^---\$/p' .claude/agents/wb-reviewer.md | tail -3 | paste -sd'|' | grep -qx 'model: claude-haiku-4-5|effort: low|---'"
check "every other line of an agent passes through" bash -c "diff <(grep -vE '^(model|effort):' .claude/agents/wb-reviewer.md) <(sed 's/@@REVIEW_EXCHANGE_CAP@@/4/g' '$src_root/agents/wb-reviewer.md')"
check "both bodies state the exchange cap" bash -c "grep -q 'After 4 exchanges' .claude/agents/wb-reviewer.md && grep -q '4 exchanges on one finding' .claude/agents/wb-worker.md"
check "the skill states the round cap and the line cap" bash -c "grep -q 'at round 3 parks it' .claude/skills/workbench/SKILL.md && grep -qF '| root \`CLAUDE.md\` | 7 |' .claude/skills/workbench/references/docs.md"
run "the skill stamp is coherent after the render" 0 "" bash -c "! '$WB' status | grep -qE 'edited by hand|behind their source|out of date|agents differ'"
snap() { find .claude -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum; }
before=$(snap)
run "a second config render changes nothing" 0 "^copies match .claude/workshop.conf$" "$WB" config render
check "not a byte" [ "$(snap)" = "$before" ]
conf worker.effort inherit
"$WB" config render >/dev/null
check "inherit takes the line out again" bash -c "! grep -q '^effort:' .claude/agents/wb-worker.md && grep -q '^model: sonnet' .claude/agents/wb-worker.md"
rc3=$(newc bug "round cap")
"$WB" round "$rc3" 5 1 >/dev/null; "$WB" round "$rc3" 3 0 >/dev/null
run "round parks at review.round_cap" 0 "next: call — 3 rounds" "$WB" round "$rc3" 3 0
run "cap.claude is the cap status reports" 0 "^cap: CLAUDE.md [0-9]+/7 — cut it" "$WB" status
git add -A && git commit -qm settings

# A settings edit with no render: out of date, never stale, never a hand edit.
conf reviewer.effort max
run "a settings edit without a render: status says the copies are out of date" 0 "^config: copies out of date with .claude/workshop.conf — workbench config render, then restart$" "$WB" status
run "and names the agent" 0 "" bash -c "'$WB' status | grep -A1 '^config: copies out of date' | grep -q wb-reviewer"
check "not as an agent differing from its source" bash -c "! '$WB' status | grep -q 'agents differ'"
conf review.round_cap 4
run "a token in the skill is named as well" 0 "" bash -c "'$WB' status | grep -A1 '^config: copies out of date' | grep -q workbench"
check "never as a hand edit or a stale skill" bash -c "! '$WB' status | grep -qE 'edited by hand|behind their source'"
"$WB" config render >/dev/null
run "after the render status is clean" 0 "" bash -c "! '$WB' status | grep -qE 'out of date|agents differ|edited by hand|behind their source'"
echo 'my note' >> .claude/agents/wb-reviewer.md
run "a hand edit of an agent copy is 'differs', not config" 0 "agents differ from their source" "$WB" status
check "and not out of date" bash -c "! '$WB' status | grep -q 'out of date'"
"$WB" config render >/dev/null
echo tweak >> .claude/skills/workbench/SKILL.md
conf review.round_cap 2
run "config render skips a skill copy edited by hand" 0 "edited by hand; not rendered" "$WB" config render
check "the hand edit survives it" grep -q tweak .claude/skills/workbench/SKILL.md
run "status still calls it a hand edit" 0 "edited by hand" "$WB" status
"$WB" init --force >/dev/null 2>&1
git add -A && git commit -qm resettled

# Nothing but the shipped copies: a project's own skill, a retired agent init would reap.
mkdir -p .claude/skills/hand && echo mine > .claude/skills/hand/SKILL.md
printf -- '---\nname: wb-retired\nx-workbench: true\n---\n' > .claude/agents/wb-retired.md
conf review.exchange_cap 9
"$WB" config render >/dev/null
check "config render touches only the shipped copies" bash -c "[ \"\$(git status --porcelain | sed 's/^...//' | LC_ALL=C sort | paste -sd' ')\" = '.claude/agents/wb-retired.md .claude/agents/wb-reviewer.md .claude/agents/wb-worker.md .claude/skills/hand/ .claude/workshop.conf' ]"
rm -rf .claude/skills/hand .claude/agents/wb-retired.md

# main=
git branch -q trunk
conf main trunk
run "main= is the default branch" 1 "has 'main' checked out, not trunk" "$WB" new bug "on trunk"
run "config get main prints it" 0 "^trunk$" "$WB" config get main
conf main nosuch
run "a main naming no branch is warned about, and status completes" 0 "config: .claude/workshop.conf: main='nosuch' names no branch" "$WB" status
conf main "bad name"
run "an invalid branch name is warned about" 0 "main='bad name' is not a branch name" "$WB" status
run "and the branch is auto-detected" 0 "^main$" "$WB" config get main
unconf main

# Invalid and unknown: the default, a warning, no crash.
printf 'no equals sign here\nfoo.bar=1\nworker.effort=huge\n# worker.model=commented\n\n   review.exchange_cap  =  5  \n' >> .claude/workshop.conf
run "status warns about a line that is not key=value" 0 "^config: .claude/workshop.conf line [0-9]+: no equals sign here is not key=value$" "$WB" status
run "status warns about an unknown key" 0 "^config: .claude/workshop.conf: unknown key 'foo.bar', ignored$" "$WB" status
run "status warns about an invalid effort" 0 "worker.effort='huge' is not inherit, low, medium, high, xhigh or max; the default applies" "$WB" status
run "config get gives the default for it" 0 "^inherit$" "$WB" config get worker.effort
run "config list marks it invalid" 0 "^worker.effort +invalid +inherit$" "$WB" config list
run "a comment line is not read" 0 "^sonnet$" "$WB" config get worker.model
run "spaces around key and value are trimmed, the last occurrence wins" 0 "^5$" "$WB" config get review.exchange_cap
conf review.round_cap 0
run "zero is not a count" 0 "^5$" "$WB" config get review.round_cap
conf worker.model "two words"
run "a model with a space is the default" 0 "^inherit$" "$WB" config get worker.model
run "and the render still runs" 0 "" "$WB" config render
check "rendering no model: line for it" bash -c "! grep -q '^model:' .claude/agents/wb-worker.md"

# ts-gate's keys: listed and checked only where ts-gate is installed.
mkdir ts-gate
run "with ts-gate installed config list shows its keys" 0 "^gate.repeat_cap +default +3$" "$WB" config list
conf lint.max_lines lots
run "and status checks them" 0 "lint.max_lines='lots' is not a positive integer" "$WB" status
"$WB" config list | sed -E 's/ +(file|default|invalid) +/ /' > "$TMP/values.before"
run "init with ts-gate adds its keys" 0 "added: gate.repeat_cap gate.output_lines lint.complexity" "$WB" init
check "at their defaults" bash -c "grep -qx 'gate.repeat_cap=3' .claude/workshop.conf && grep -qx 'lint.max_depth=4' .claude/workshop.conf"
check "the values the file had stay, one line per key" bash -c "[ \"\$(grep -c '^lint.max_lines=' .claude/workshop.conf)\" -eq 1 ] && grep -qx 'lint.max_lines=lots' .claude/workshop.conf && grep -qx 'review.exchange_cap=5' .claude/workshop.conf && grep -qx 'worker.model=two words' .claude/workshop.conf"
check "lines that are not its keys move to the end" bash -c "sed -n '/^# Kept from the file as it was:\$/,\$p' .claude/workshop.conf | grep -qx 'no equals sign here' && sed -n '/^# Kept/,\$p' .claude/workshop.conf | grep -qx 'foo.bar=1' && sed -n '/^# Kept/,\$p' .claude/workshop.conf | grep -qx '# worker.model=commented'"
check "every effective value is unchanged" bash -c "'$WB' config list | sed -E 's/ +(file|default|invalid) +/ /' | cmp -s - '$TMP/values.before'"
cp .claude/workshop.conf "$TMP/conf.filled"
"$WB" init >/dev/null
check "a second init keeps the file, kept lines not repeated" cmp -s .claude/workshop.conf "$TMP/conf.filled"
rmdir ts-gate
run "without ts-gate they are neither listed nor warned about" 0 "" bash -c "! '$WB' config list | grep -q '^lint' && ! '$WB' status | grep -qE 'lint.max_lines|unknown key .lint'"

# --- git config keys move into the file --------------------------------------
new_repo migrate
git config workbench.cap.claude 90
git config workbench.main main
git config workbench.premerge "npm run gate"
git config workbench.guards 'npm run gate'
run "init moves the git config keys into the file" 0 "moved git config workbench.premerge to .claude/workshop.conf: premerge=npm run gate" "$WB" init
check "the file holds all three" bash -c "grep -qx 'cap.claude=90' .claude/workshop.conf && grep -qx 'main=main' .claude/workshop.conf && grep -qx 'premerge=npm run gate' .claude/workshop.conf"
check "git config holds none of them" bash -c "! git config --get-regexp '^workbench\.(cap|main|premerge)'"
check "guards stay in git config" [ "$(git config workbench.guards)" = 'npm run gate' ]
# shellcheck disable=SC2016  # the backticks are the markdown being matched
check "the rendered copy took the moved cap" grep -qF '| root `CLAUDE.md` | 90 |' .claude/skills/workbench/references/docs.md
cp .claude/workshop.conf "$TMP/conf.before"
run "a second init moves nothing" 0 "" bash -c "! '$WB' init 2>&1 | grep -q 'git config workbench'"
check "and leaves the file as it was" cmp -s .claude/workshop.conf "$TMP/conf.before"
git config workbench.premerge "npm run gate"
run "a git value the file already holds is unset" 0 "unset git config workbench.premerge" "$WB" init
check "unset" bash -c "! git config --get workbench.premerge"
git config workbench.premerge other
run "a git value the file contradicts is named, the file applies" 0 "git config workbench.premerge is 'other', .claude/workshop.conf has premerge=npm run gate" "$WB" init
check "and left for the user to settle" [ "$(git config workbench.premerge)" = other ]
check "bin/workbench reads none of the moved git config keys" bash -c "! grep -nE 'config (--local )?--get \"?workbench\.(cap|main|premerge)' '$WB'"

echo
echo "$checks checks, $fails failed"
[ "$fails" -eq 0 ]
