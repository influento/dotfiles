#!/usr/bin/env bash
# End-to-end tests for the workbench CLI, run in a throwaway repository.
# Plain bash, no framework: each check is an exit code and a grep on output.
# Run: bash tests/workbench.sh
set -euo pipefail

SELF=$(readlink -f "$0")  # every check runs from a temp repo, so paths here must be absolute
# The suite lives inside the tool it tests, so every source is one hop up.
WB=$(readlink -f "$(dirname "$0")/../bin/workbench")
OPEN=$(readlink -f "$(dirname "$0")/../workbench-review/scripts/open.sh")
RULES=$(readlink -f "$(dirname "$0")/../workbench-review/scripts/rules.sh")
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
# tmux, shimmed: every call is logged, windows live in a state directory, and
# 'claude' is only ever a string inside a window's command. TMUX_SHIM_STATE
# names the directory; the shim refuses to run without it.
export TMUX_SHIM_STATE="$TMP/tmux"
cat > "$TMP/bin/tmux" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
S=${TMUX_SHIM_STATE:?}
mkdir -p "$S"; touch "$S/windows" "$S/sessions" "$S/log"
printf '%s\n' "$*" >> "$S/log"
cmd=$1; shift
t='' n='' s='' F='' c=''; rest=()
while [ $# -gt 0 ]; do
  case "$1" in
    -t) t=${2#=}; shift 2 ;; -n) n=$2; shift 2 ;; -s) s=$2; shift 2 ;; -F) F=$2; shift 2 ;; -c) c=$2; shift 2 ;;
    -d|-P|-dP|-p|';') shift ;;
    *) rest+=("$1"); shift ;;
  esac
done
next() { local k; k=$(( $(cat "$S/counter" 2>/dev/null || echo 0) + 1 )); echo "$k" > "$S/counter"; echo "$k"; }
win_by_pane() { grep -P "^@${1#%}\t" "$S/windows" | cut -f1; }
case "$cmd" in
  -V) echo "tmux shim" ;;
  has-session) grep -qx "$t" "$S/sessions" ;;
  new-session) echo "$s" >> "$S/sessions"; k=$(next); printf '@%s\t%s\t%s\n' "$k" "$s" "$n" >> "$S/windows"; echo "@$k" ;;
  new-window) grep -qx "$t" "$S/sessions" || { echo "no session $t" >&2; exit 1; }
    k=$(next); printf '@%s\t%s\t%s\n' "$k" "$t" "$n" >> "$S/windows"; echo "@$k" ;;
  list-windows) grep -P "\t$t\t" "$S/windows" | cut -f1 || true ;;
  kill-window) grep -vP "^$t\t" "$S/windows" > "$S/windows.tmp" || true; mv "$S/windows.tmp" "$S/windows" ;;
  rename-window) awk -F'\t' -v w="$t" -v name="${rest[0]}" 'BEGIN{OFS="\t"} $1==w {$3=name} {print}' "$S/windows" > "$S/windows.tmp"; mv "$S/windows.tmp" "$S/windows" ;;
  display-message) case "$t" in %*) w=$(win_by_pane "$t") ;; *) w=$t ;; esac
    case "${rest[0]}" in '#{window_id}') [ -n "$w" ] && echo "$w" ;; '#{window_name}') grep -P "^$w\t" "$S/windows" | cut -f3 ;; esac ;;
  switch-client|select-window|attach) ;;
  *) echo "shim: unhandled $cmd" >&2; exit 1 ;;
esac
SHIM
chmod +x "$TMP/bin/tmux"

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
# not_listed <id> <find-args...> — the index must not carry the id.
# The grep reads a herestring, never a pipe: see the note on 'run' below. Here
# the pipe was the dangerous direction — grep -q exits early on a match, so a
# regression that DID list the id could be reported as a SIGPIPE and read as
# "not listed", passing the check it was supposed to fail.
not_listed() {
  local id="$1" out
  shift
  out=$("$WB" find "$@" 2>/dev/null) || true
  ! grep -q -- "$id" <<<"$out"
}

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
# crit <path> — fill the criterion (a research item's Scope) so start accepts it.
crit() { sed -i '/^## \(How to confirm\|Scope\)/a\
\
agreed with the user' "$1"; }
mainroot() { git worktree list --porcelain | sed -n '1s/^worktree //p'; }
# newc <class> <title> [opts] — new, with the criterion filled; prints the id.
# The file is on the main checkout wherever this runs, so it is found there.
newc() {
  local id
  id=$("$WB" new "$@" 2>/dev/null) || return 1
  crit "$(find "$(mainroot)/workbench/items" -name "$id-*.md" -print -quit)"
  printf '%s\n' "$id"
}
# ready <worktree> — evidence on the branch's own item, committed, so merge's
# gate passes; the review gate is skipped with --no-review where it is not
# the subject.
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

# --- the happy loop ---------------------------------------------------------

new_repo loop
run "init" 0 "workbench ready" "$WB" init
run "init outside ~ says to set the memory path by hand" 0 "not under ~" "$WB" init
for c in workbench workbench-review bug feature research idea wb; do
  check "init renders /$c as a copy" bash -c "[ -f '.claude/skills/$c/SKILL.md' ] && [ ! -L '.claude/skills/$c' ] && [ -f '.claude/skills/$c/GENERATED' ]"
done
check "init does not ignore the copies" bash -c "! grep -q '.claude/skills' .gitignore"
check "no /rename is rendered" [ ! -e .claude/skills/rename ]
# The CLI is in bin/, beside the skill sources rather than inside one, so
# render_skills' 'cp -RL' cannot vendor a 4000-line copy of it into every
# opted-in project and skill_hash cannot count it — which would report every
# project's copy stale on any CLI edit. Adding bin/ to skill_sources fails this.
check "init renders no copy of the CLI" [ ! -e .claude/skills/bin ]
# The source directories are named exactly as the skills they render to, so
# this is the whole mapping: what is under .claude/skills/ is what Claude Code
# loads by name, and the CLI's own messages ('/workbench-review pre-merge')
# and its staleness regex both spell these two out.
check "the two skills render under their own names" bash -c \
  "[ -f .claude/skills/workbench/SKILL.md ] && [ -f .claude/skills/workbench-review/SKILL.md ]"
for a in wb-worker wb-reviewer wb-gate; do check "init renders the $a agent" [ -f ".claude/agents/$a.md" ]; done
check "the review skill runs as the gate" grep -qx 'agent: wb-gate' .claude/skills/workbench-review/SKILL.md
check "the gate's tools are the sweep's contract" grep -qx 'tools: Read, Glob, Grep, Bash, Write' .claude/agents/wb-gate.md
check "the reviewer edits nothing" grep -qx 'tools: Read, Glob, Grep, Bash' .claude/agents/wb-reviewer.md
check "the worker can spawn its reviewer, ask, and message the lead" bash -c "grep '^tools: ' .claude/agents/wb-worker.md | grep -q 'Agent,' && grep '^tools: ' .claude/agents/wb-worker.md | grep -q AskUserQuestion"
check "the stamp carries source and copy hashes" bash -c "sed -n 1,2p .claude/skills/wb/GENERATED | grep -cE '^[0-9a-f]{12}\$' | grep -qx 2"
check "init ignores .worktrees/" grep -qx '.worktrees/' .gitignore
check "init allows Bash(workbench:*)" grep -q 'Bash(workbench:\*)' .claude/settings.json
check "init writes the session hook" grep -q 'workbench status ||' .claude/settings.json
check "the hook is guarded on PATH" grep -q '"command -v workbench >/dev/null && workbench status || true"' .claude/settings.json
check "init writes the status line" grep -q '"command -v workbench >/dev/null && workbench statusline || true"' .claude/settings.json
check "init does not set the agent-teams flag" bash -c "! grep -q AGENT_TEAMS .claude/settings.json"
check "init writes the signal hooks" grep -q 'workbench signal working || true' .claude/settings.json
check "init writes the gate hooks unguarded by || true" grep -q '"! command -v workbench >/dev/null || workbench gate ask"' .claude/settings.json
check "the ask gate matches AskUserQuestion" bash -c "python3 -c \"import json;d=json.load(open('.claude/settings.json'));print([g.get('matcher') for g in d['hooks']['PreToolUse']])\" | grep -q AskUserQuestion"
run "init is idempotent" 0 "workbench ready" "$WB" init
check "unchanged copies are not re-rendered" bash -c "! '$WB' init 2>&1 | grep -q 'rendered .claude'"
check "the hook is not duplicated" [ "$(grep -c 'workbench status ||' .claude/settings.json)" -eq 1 ]
check "the status line is not reported as foreign" bash -c "! '$WB' init 2>&1 | grep -q 'statusLine is already set'"
run "status is quiet while the copies are current" 0 "" bash -c "! '$WB' status | grep -q 'behind their source'"
check "the signal hooks are not duplicated" [ "$(grep -c 'workbench signal working' .claude/settings.json)" -eq 3 ]
session() { printf '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"%s"}}' "$1"; }
run "statusline with nothing in flight" 0 '^\[Opus\] wb: nothing in flight$' bash -c "$(declare -f session); session '$PWD' | '$WB' statusline"
run "statusline outside a workbench project is silent" 0 "" bash -c "$(declare -f session); session '$HOME' | '$WB' statusline"
check "statusline outside a workbench project prints nothing" [ -z "$(session "$HOME" | "$WB" statusline)" ]
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
git add -A && git commit -qm "archive $idt"

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
run "statusline names the worktree's item" 0 '^\[Opus\] wb: on b-001 · 1 open$' bash -c "$(declare -f session); session '$PWD/$wt' | '$WB' statusline"
for short in b-1 b-01 b-0001; do
  run "start reads $short as b-001" 1 "b-001 is already started; its worktree is .*/$wt$" "$WB" start "$short"
done
run "start refuses a bare letter" 1 "is not an item id" "$WB" start b
run "new validates the class before --milestone" 1 "class must be" "$WB" new bogus "t" --milestone nope

( cd "$wt" && mkdir -p sub && echo fix > src.txt && echo x > sub/x.txt && git add -A && git commit -qm wip )
run "merge refuses an open item with no evidence on the branch" 1 "open with no evidence under '## Evidence' on b-001-crash-on-save" "$WB" merge b-001 "fix crash"
report=$("$WB" review pre-merge b-001)
check "pre-merge notes an item file the branch never touched" grep -q 'the item file is not among them' "$report"
run "review pre-merge refuses while a report stands" 1 "still holds a review report" "$WB" review pre-merge b-001
check "the refusal names the report" bash -c "'$WB' review pre-merge b-001 2>&1 | grep -q '^  $(basename "$report")\$'"
"$WB" review-drop --force "$report" >/dev/null 2>&1
# pasted output holds '## ' lines: a heading to markdown, not to the item
fill_evidence "$wt/$item" "make test" $'## not a heading\nok'
run "review pre-merge refuses a dirty worktree" 1 "uncommitted changes; the review records the branch commit" "$WB" review pre-merge b-001
check "the refusal names the file" bash -c "'$WB' review pre-merge b-001 2>&1 | grep -q '^   M $item'"
( cd "$wt" && git commit -qam evidence )
run "merge refuses without a passed pre-merge review" 1 "no passed pre-merge review" "$WB" merge b-001 "fix crash"

report=$("$WB" review pre-merge b-001)
check "review pre-merge writes the skeleton in the worktree" [ -f "$report" ]
check "pre-merge manifest names the item file" grep -q 'changed on the branch: 3 files, the item file among them' "$report"
run "review-check fails on unstated coverage" 1 "never named in the report" "$WB" review-check "$report"
printf '\ncovered: src.txt, sub/, %s\nno findings\n' "$item" >> "$report"
run "review-check refuses a pre-merge without a verdict" 1 "no 'verdict:' line" "$WB" review-check "$report"
printf 'verdict: merge\n' >> "$report"
# 'the last line, and nothing after it': taking the last matching line instead
# let a verdict be buried under prose that qualifies or contradicts it.
printf '\nthough the caching is still worth a look before release.\n' >> "$report"
run "review-check refuses a verdict that is not the last line" 1 "must be the last line" "$WB" review-check "$report"
sed -i '/though the caching/d' "$report"
run "review-check passes once coverage and verdict are in" 0 "^verdict: merge — recorded" "$WB" review-check "$report"
run "merge refuses while a report stands" 1 "still holds a review report" "$WB" merge b-001 "fix crash"
run "review-drop" 0 "deleted" "$WB" review-drop "$report"
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
git add -A && git commit -qm 'archive b-001'

run "find by path" 0 "b-001" "$WB" find src.txt
run "find is cwd-relative" 0 "b-001" bash -c "cd sub && '$WB' find x.txt"
run "find unrelated path is empty" 0 "" "$WB" find README
check "find README does not list b-001" not_listed b-001 README

# Text match: an unproved item names a path in prose; a bare word inside a
# longer one must not hit.
id2=$(newc bug "handler lost")
item2=workbench/items/bugs/$id2-handler-lost.md
# shellcheck disable=SC2016
printf '\nthe handler lives in resources/api and is unreproduced; see `lib/util.go`,\nthe loop at lib/loop.go:12, and cfg/main.toml.\n' >> "$item2"
set_status "$item2" unreproduced
run "archive unreproduced" 0 "archived $id2" "$WB" archive "$id2"
git add -A && git commit -qm "archive $id2"
run "find matches a path named in prose" 0 "$id2" "$WB" find resources
check "find 'src' skips 'resources'" not_listed "$id2" src
check "find 'sources' skips 'resources'" not_listed "$id2" sources
run "find matches a backticked path" 0 "$id2" "$WB" find lib/util.go
run "find matches a path:line citation" 0 "$id2" "$WB" find lib/loop.go
run "find matches a path before a sentence period" 0 "$id2" "$WB" find cfg/main.toml
check "find 'lib/util' skips 'lib/util.go'" not_listed "$id2" lib/util
check "find 'cfg/main' skips 'cfg/main.toml'" not_listed "$id2" cfg/main
run "find strips a leading ./" 0 "$id2" "$WB" find ./lib/util.go
run "find --grep takes one word, a path may follow" 0 "b-001" "$WB" find --grep crash src.txt
run "find --grep repeats" 0 "b-001" "$WB" find --grep crash --grep save
check "find --grep with a wrong word narrows to nothing" not_listed b-001 --grep crash --grep nosuchword
run "find --grep without a word is usage" 2 "usage" "$WB" find --grep

"$WB" milestone "Big goal" >/dev/null 2>&1
id3=$("$WB" new feature "under goal" --milestone big-goal 2>/dev/null)
check "new --milestone writes the line after status" grep -qx 'milestone: big-goal' "workbench/items/features/$id3-under-goal.md"
git rm -q "workbench/items/features/$id3-under-goal.md" && git commit -qm "drop $id3"

run "status" 0 "" "$WB" status

# The skill's preprocessed block is fail-closed, so the wrapper must turn a
# refusal into output with a zero exit.
run "open.sh folds a refusal into stdout" 0 "^workbench: reason must be" env PATH="$(dirname "$WB"):$PATH" bash "$OPEN" bogus ""
report=$("$WB" review docs 2>/dev/null)
check "review docs opens a report" bash -c "[ -f '$report' ] && [[ '$report' == *-docs.md ]]"
# The leftover refusal above is pre-merge's alone — it sits inside the item-and-
# branch guard. Every other reason opens a numbered sibling beside the standing
# report rather than refusing, which is easy to misread as a global rule from
# either side. Pin the asymmetry so neither half moves unnoticed.
second=$("$WB" review docs 2>/dev/null)
check "a second docs review opens a sibling, not a refusal" bash -c "[ -f '$second' ] && [[ '$second' == *-docs.2.md ]]"
# The note on 'check' is advisory and this shape has already shipped twice in
# code neither review wrote, so the suite asserts it about itself: a check whose
# command is a bare test bracket followed by &&, ||, ; or a pipe ends at the
# bracket, and everything after it runs outside the check. Quoted patterns
# holding those operators are untouched — the bracket must be the argument.
check "no check call asserts only its first condition" \
  bash -c '! grep -nE "^\s*check \"[^\"]*\" \[[^]]*\] *(&&|\|\||;|\|)" "'"$SELF"'"'

"$WB" review-drop "$second" >/dev/null 2>&1
"$WB" review-drop "$report" >/dev/null 2>&1
run "open.sh returns the path on success" 0 "/workbench/reviews/.*-sweep\.md$" env PATH="$(dirname "$WB"):$PATH" bash "$OPEN" sweep ""
"$WB" review-drop "$(command ls workbench/reviews/*-sweep.md)" >/dev/null 2>&1
report=$(env PATH="$(dirname "$WB"):$PATH" bash "$OPEN" sweep "resize")
check "open.sh with a topic scope returns the path alone" [ -f "$report" ]
check "the topic warning is in the skeleton" grep -q "scope 'resize' is not all paths" "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

# rules.sh feeds the same fail-closed block, so a reason it cannot serve aborts
# the sweep rather than sweeping without rules. The reason is already validated
# by 'review' before it gets here, which is what makes that exit unreachable in
# the real flow — and what makes the two lists drifting apart the actual risk:
# a reason added to 'review' with no rules/ file would abort every sweep for it.
# 'review bogus' exits non-zero and pipefail carries that to the assignment,
# which under set -e would end the run here rather than fail a check.
reasons=$("$WB" review bogus 2>&1 | sed -n 's/.*reason must be one of: //p' | tr -d ',' || true)
# Non-empty, not a fixed count: a seventh reason with rules behind it is
# growth, not drift, and should not fail here. What this guards is the loop
# below going vacuous when the parse breaks — six checks would vanish and the
# suite would still say it passed.
check "the reason list is readable from review's refusal" [ -n "$reasons" ]
for r in $reasons; do
  run "rules.sh serves $r" 0 "^# " bash "$RULES" "$r"
done
# docs and memory audit against the documentation reference; adopt against both
# that and the adoption one. The others must not carry them, or the sweep reads
# rules it was never given.
for r in docs memory; do
  check "rules.sh appends the docs reference for $r" bash -c "bash '$RULES' $r | grep -qx '# Documentation'"
done
check "rules.sh appends both references for adopt" bash -c \
  "bash '$RULES' adopt | grep -qx '# Adopting an existing project' && bash '$RULES' adopt | grep -qx '# Documentation'"
for r in sweep pre-merge watch; do
  check "rules.sh appends no reference for $r" bash -c "! bash '$RULES' $r | grep -qx '# Documentation'"
done
run "rules.sh refuses a reason it has no rules for" 2 "no rules for reason 'nope'" bash "$RULES" nope
run "rules.sh refuses no reason at all" 2 "usage: rules.sh" bash "$RULES"

# --- review-check catches what the sweep did --------------------------------
# Each case opens a fresh report on a clean main, does what a sweep must not,
# and expects the named refusal; the tree is put back and the report dropped.

sweep() { "$WB" review sweep 2>/dev/null; }
report=$(sweep)
echo edited >> README
run "review-check catches a tracked edit" 1 "unexpected change:  M README" "$WB" review-check "$report"
check "a fresh edit is reported once" [ "$("$WB" review-check "$report" 2>&1 | grep -c README)" -eq 1 ]
git checkout -q README
run "review-check passes once the edit is reverted" 0 "^clean:" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

report=$(sweep)
echo stray > stray.txt
run "review-check catches a new untracked file" 1 "the sweep wrote: stray.txt" "$WB" review-check "$report"
rm stray.txt; "$WB" review-drop "$report" >/dev/null 2>&1

echo stray > stray.txt
report=$(sweep)
rm stray.txt
run "review-check catches a removed untracked file" 1 "the sweep removed: stray.txt" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

report=$(sweep)
git commit -q --allow-empty -m moved
run "review-check catches HEAD moving" 1 "the sweep moved HEAD" "$WB" review-check "$report"
git reset -q HEAD~1; "$WB" review-drop "$report" >/dev/null 2>&1

# settings.local.json is ignored by design, so 'git status' and 'ls-files
# --others --exclude-standard' both look straight past it — and it is where a
# permission allow-list lives. A sweep with Bash could widen its own permissions
# and pass.
mkdir -p .claude
echo '{"permissions":{"allow":[]}}' > .claude/settings.local.json
check "the local settings really are ignored here" git check-ignore -q .claude/settings.local.json
report=$(sweep)
echo '{"permissions":{"allow":["Bash"]}}' > .claude/settings.local.json
run "review-check catches an edit to the local settings" 1 "the sweep changed: .claude/settings.local.json" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1
report=$(sweep)
rm .claude/settings.local.json
run "review-check catches the local settings being removed" 1 "the sweep removed: .claude/settings.local.json" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

# a skip-worktree or assume-unchanged bit hides a tracked file from both
# 'status' and 'diff HEAD', so the baseline cannot see it change at all
report=$(sweep)
git update-index --skip-worktree README
run "review-check refuses a skip-worktree bit" 1 "hidden from git by a skip-worktree" "$WB" review-check "$report"
git update-index --no-skip-worktree README
run "review-check passes once the bit is cleared" 0 "^clean:" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

report=$(sweep)
printf '\nsee src.txt:999 and nowhere/at/all.go:3\n' >> "$report"
run "review-check catches a citation past the end" 1 "cites src.txt:999, and no src.txt has 999 lines" "$WB" review-check "$report"
run "review-check catches a citation to a missing file" 1 "cites nowhere/at/all.go:3, and nowhere/at/all.go is not in the tree" "$WB" review-check "$report"
"$WB" review-drop --force "$report" >/dev/null 2>&1

# a file already modified before the sweep, modified again by it
echo before >> README
report=$(sweep)
echo during >> README
run "review-check names a re-edited tracked file" 1 "the sweep changed: README" "$WB" review-check "$report"
git checkout -q README
run "review-check names a reverted tracked file" 1 "the sweep reverted: README" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

# dotless citations resolve against the tree
printf 'all:\n\ttrue\n' > Makefile && git add Makefile && git commit -qm makefile
report=$(sweep)
printf '\nsee Makefile:2, exit:1 and localhost:5432\n' >> "$report"
run "review-check accepts a dotless citation in range" 0 "^clean:" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1
report=$(sweep)
printf '\nsee Makefile:99\n' >> "$report"
run "review-check catches a dotless citation past the end" 1 "cites Makefile:99, and no Makefile has 99 lines" "$WB" review-check "$report"
"$WB" review-drop --force "$report" >/dev/null 2>&1
git rm -q Makefile && git commit -qm 'no makefile'
report=$(sweep)
printf '\nsee Makefile:99\n' >> "$report"
run "a dotless citation with no such file is a word" 0 "^clean:" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

# reviews/ holding nothing tracked: the report must still be its own line
git rm -q workbench/reviews/.gitkeep && git commit -qm 'drop placeholder'
report=$(sweep)
run "review-check passes with no placeholder in reviews/" 0 "^clean:" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1
git revert --no-edit HEAD >/dev/null

# a memory sweep: the store outside the tree is in the baseline too
mem="$HOME/.claude/projects/$(pwd | sed 's/[^A-Za-z0-9]/-/g')/memory"
mkdir -p "$mem" && echo fact > "$mem/fact.md"
report=$("$WB" review memory 2>/dev/null)
echo changed >> "$mem/fact.md"
run "review-check catches a memory edit" 1 "the sweep wrote: $mem/fact.md" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1
report=$("$WB" review memory 2>/dev/null)
echo new > "$mem/new.md"
run "review-check catches a new memory file" 1 "the sweep wrote: $mem/new.md" "$WB" review-check "$report"
rm "$mem/new.md"; "$WB" review-drop "$report" >/dev/null 2>&1
report=$(sweep)
echo new > "$mem/new.md"
run "a plain sweep ignores the memory store" 0 "^clean:" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

# --- watch shifts -------------------------------------------------------------

"$WB" watch "db" >/dev/null 2>&1
"$WB" watch "db 2" >/dev/null 2>&1
w1=$("$WB" review watch db 2>/dev/null)
w2=$("$WB" review watch db-2 2>/dev/null)
check "watch db-2 gets its own report" [ "$w2" != "$w1" ]
check "watch db resumes db, not db-2" [ "$("$WB" review watch db 2>/dev/null)" = "$w1" ]
check "watch db-2 resumes db-2" [ "$("$WB" review watch db-2 2>/dev/null)" = "$w2" ]
echo edited >> README
run "review-check tolerates changes during a watch" 0 "verify these are yours" "$WB" review-check "$w1"
git checkout -q README
run "a checked watch shift stays open" 0 "" test -f "$w1"
rm "$w1"                                   # the report gone by hand: baseline orphaned
w1b=$("$WB" review watch db 2>/dev/null)
check "an orphaned watch baseline yields a .2 report" [ "$(basename "$w1b")" = "$(basename "$w1" .md).2.md" ]
check "the .2 shift is the one resumed" [ "$("$WB" review watch db 2>/dev/null)" = "$w1b" ]
run "review watch refuses a slug without a contract" 1 "no contract" "$WB" review watch nope
run "review watch refuses a non-slug" 1 "not a contract slug" "$WB" review watch 'Db 2'
check "watch skeleton seeds the liveness line" grep -qx 'checked: 0 ticks, last —' "$w2"
for r in "$w1" "$w1b" "$w2"; do "$WB" review-drop --force "$r" >/dev/null 2>&1 || true; done

# --- status, find, milestones, adopt ------------------------------------------

idl=$(newc feature "later")          # unstarted, in main
printf '\ntouches src.txt when it lands\n' >> "workbench/items/features/$idl-later.md"
run "find lists an open unstarted item by text, as open" 0 "$idl .*open" "$WB" find src.txt
"$WB" start "$idl" >/dev/null 2>&1
set_status ".worktrees/$idl-later/workbench/items/features/$idl-later.md" "awaiting — next deploy"
run "status keeps an awaiting item on its branch under branches" 0 "" bash -c "'$WB' status | sed -n '/awaiting a trigger/,\$p' | grep -q '(none)'"
( cd ".worktrees/$idl-later" && git add -A && git commit -qm later )
"$WB" merge "$idl" "later" --no-review >/dev/null 2>&1
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

# status report labels
r1=$(sweep); r2=$(sweep); rm "$r2"
r3=$(sweep); "$WB" review-check "$r3" >/dev/null 2>&1
run "status labels an unchecked report" 0 "$(basename "$r1") *unchecked" "$WB" status
run "status labels a stale marker" 0 "$(basename "$r2") *stale marker" "$WB" status
run "status labels a checked report" 0 "$(basename "$r3") *awaiting triage" "$WB" status
for r in "$r1" "$r2" "$r3"; do "$WB" review-drop "$r" >/dev/null 2>&1 || true; done

# milestone archive
id5=$("$WB" new feature "under goal too" --milestone big-goal 2>/dev/null)
run "milestone archive refuses with open items" 1 "still has open items" "$WB" milestone archive big-goal
git rm -q "workbench/items/features/$id5-under-goal-too.md" && git commit -qm "drop $id5"
run "milestone archive refuses without evidence" 1 "no evidence recorded" "$WB" milestone archive big-goal
fill_evidence workbench/milestones/big-goal.md "make release" "ok"
run "milestone archive" 0 "archived milestone big-goal" "$WB" milestone archive big-goal
check "milestone lands in its archive" [ -f workbench/milestones/archive/big-goal.md ]

# --- research -----------------------------------------------------------------
# A scope that ends by decomposing: never merges, archives once every concept
# is terminal and names something real, drops its prototypes only when told.

# research_item <path> <id> <outcome> <state>... — one concept per state; an
# empty state omits the line.
research_item() {
  local path="$1" id="$2" outcome="$3" n=0 st; shift 3
  {
    printf '# %s — netcode\n\nstatus: open\n\n## Scope\n\nlockstep or rollback\n\n## Concepts\n' "$id"
    for st in "$@"; do
      n=$((n + 1))
      printf '\n### concept %s\n\nwords\n' "$n"
      [ -z "$st" ] || printf 'state: %s\n' "$st"
    done
    printf '\n## Next\n\n## Outcome\n\n%s\n' "$outcome"
  } > "$path"
}

idx=$("$WB" new research "netcode" 2>/dev/null)
check "new research allocates x-" [ "${idx%%-*}" = x ]
ritem=workbench/items/research/$idx-netcode.md
check "new research writes under items/research" [ -f "$ritem" ]
check "the research template carries the state grammar" grep -q 'state: -> milestone <slug>' "$ritem"
run "archive --discard refuses an item that merges" 1 "for research and abandoned items" "$WB" archive "$idl" --discard
run "start refuses research with an empty Scope" 1 "$idx's 'Scope' is empty" "$WB" start "$idx"
crit "$ritem"
"$WB" start "$idx" >/dev/null 2>&1
rwt=.worktrees/$idx-netcode
ritem=$rwt/$ritem
run "merge refuses research" 1 "never merges" "$WB" merge "$idx" "netcode"
run "status shows a research item with no concepts" 0 "$idx-netcode +open +started +no concepts yet" "$WB" status
research_item "$ritem" "$idx" "" "open" "-> backlog"
run "status counts open concepts" 0 "$idx-netcode +open +started +1 of 2 concepts open" "$WB" status
run "statusline counts open concepts" 0 "wb: .* · $idx 1 / 2" bash -c "$(declare -f session); session '$PWD' | '$WB' statusline"
run "archive refuses with an open concept" 1 "still has open concepts" "$WB" archive "$idx"
research_item "$ritem" "$idx" "" "" "-> backlog"
run "archive names a concept without a state" 1 "concepts without a state line" "$WB" archive "$idx"
research_item "$ritem" "$idx" "" "-> f-999"
run "archive refuses a state naming a missing item" 1 "names 'f-999', which is not an item" "$WB" archive "$idx"
research_item "$ritem" "$idx" "" "-> b-1"
run "archive refuses a state naming a short id" 1 "names 'b-1'; write it as b-001" "$WB" archive "$idx"
research_item "$ritem" "$idx" "" "-> milestone nope"
run "archive refuses a state naming a missing milestone" 1 "names milestone 'nope', which does not exist" "$WB" archive "$idx"
research_item "$ritem" "$idx" "" "later"
run "archive refuses an unknown state" 1 "known states" "$WB" archive "$idx"
set_status "$ritem" "awaiting — next deploy"
run "archive refuses a research status other than open" 1 "stays 'open' until archived" "$WB" archive "$idx"
# every terminal form, pointing at things that exist — an archived item and an
# archived milestone among them
research_item "$ritem" "$idx" "" "-> backlog" "-> b-001" "-> milestone big-goal" "dropped — too slow"
run "archive refuses a spawned item that does not cite the research" 1 "whose first section does not cite $idx" "$WB" archive "$idx"
sed -i "/^## What was seen/a\\
\\
spawned by $idx" workbench/items/archive/b-001-crash-on-save.md
sed -i "/^## Root cause/a\\
\\
see also $idx-in-the-wrong-place" workbench/items/archive/b-001-crash-on-save.md
run "archive refuses without an outcome" 1 "no outcome recorded" "$WB" archive "$idx"
research_item "$ritem" "$idx" "became b-001 and a backlog line" "-> backlog" "-> b-001" "-> milestone big-goal" "dropped — too slow"
printf '\n%s\n### pasted heading\n## pasted section\nstate: open\n%s\n' '```' '```' >> "$ritem"
run "status ignores headings and states inside a fence" 0 "$idx-netcode +open +started +0 of 4 concepts open" "$WB" status
( cd "$rwt" && echo proto > proto.txt && git add -A && git commit -qm prototype )
run "archive refuses to drop prototypes unasked" 1 "archive $idx --discard" "$WB" archive "$idx"
check "the refusal names the prototype" bash -c "'$WB' archive $idx 2>&1 | grep -q proto.txt"
( cd "$rwt" && echo more > scratch.txt )
rc=0; out=$("$WB" archive "$idx" --discard 2>&1) || rc=$?
check "archive --discard retires the research branch" [ "$rc" -eq 0 ]
check "--discard says the prototypes are gone" grep -q 'its prototypes are gone' <<< "$out"
check "--discard names the committed prototype" grep -q 'proto.txt' <<< "$out"
check "--discard names the uncommitted scratch" grep -q 'scratch.txt' <<< "$out"
check "research worktree removed" [ ! -e "$rwt" ]
check "research branch deleted" [ -z "$(git branch --list "$idx-netcode")" ]
check "research archived on main" [ -f "workbench/items/archive/$idx-netcode.md" ]
check "research records no commit" grep -qx 'commit: none' "workbench/items/archive/$idx-netcode.md"
git add -A && git commit -qm "archive $idx"
run "find --grep lists archived research" 0 "^$idx .*archived" "$WB" find --grep lockstep
run "status no longer lists it" 0 "" bash -c "! '$WB' status | grep -q $idx-netcode"

# a statusLine the user already set is never overridden
new_repo settings
mkdir -p .claude && echo '{"statusLine":{"type":"command","command":"echo mine"}}' > .claude/settings.json
run "init leaves a user statusLine alone" 0 "statusLine is already set" "$WB" init
python3 -c "import json;p='.claude/settings.json';d=json.load(open(p));d['env']={'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS':'0'};json.dump(d,open(p,'w'))"
run "init leaves a teams opt-out alone" 0 "" bash -c "! '$WB' init | grep -q AGENT_TEAMS"
check "the opt-out survives" grep -q '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"' .claude/settings.json
python3 -c "import json;p='.claude/settings.json';d=json.load(open(p));d['env']={'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS':'1','KEEP':'x'};json.dump(d,open(p,'w'))"
run "init removes the teams flag it once set" 0 "AGENT_TEAMS removed" "$WB" init
check "the flag is gone and the rest of env stays" bash -c "! grep -q AGENT_TEAMS .claude/settings.json && grep -q '\"KEEP\"' .claude/settings.json"
check "the user statusLine survives" grep -q '"echo mine"' .claude/settings.json
check "the hook is still added beside it" grep -q 'workbench status ||' .claude/settings.json
echo 'not json' > .claude/settings.json
run "init leaves invalid settings alone" 0 "not valid JSON; left alone" "$WB" init
check "invalid settings are untouched" grep -qx 'not json' .claude/settings.json
# a statusLine that is not an object is left alone, and init still finishes
echo '{"statusLine":"echo hi","hooks":{"SessionStart":["odd"]}}' > .claude/settings.json
run "init survives a non-object statusLine" 0 "statusLine is already set" "$WB" init
check "the string statusLine survives" grep -q '"echo hi"' .claude/settings.json
check "the hook is added beside a non-object SessionStart entry" grep -q 'workbench status ||' .claude/settings.json
echo '{"permissions":[],"hooks":"odd"}' > .claude/settings.json
run "init survives odd permissions and hooks shapes" 0 "permissions.allow is not a list" "$WB" init
check "init still reached the checklist" bash -c "'$WB' init | grep -q 'decide these with the user'"
check "the odd permissions were left alone" grep -q '"permissions": \[\]' .claude/settings.json
# a bare command from an earlier init is upgraded in place, once
echo '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"workbench status"}]}]},"statusLine":{"type":"command","command":"workbench statusline"}}' > .claude/settings.json
run "init guards a bare hook from an earlier init" 0 "workbench status now guarded on PATH" "$WB" init
check "the bare hook is gone" bash -c "! grep -q '\"workbench status\"' .claude/settings.json"
check "the bare status line is gone" bash -c "! grep -q '\"workbench statusline\"' .claude/settings.json"
check "the upgraded hook is the only one" [ "$(grep -c 'workbench status ||' .claude/settings.json)" -eq 1 ]
check "init reached the checklist" bash -c "'$WB' init | grep -q 'decide these with the user'"

# --- memory in the tree -------------------------------------------------------
# Under ~, init points autoMemoryDirectory into the checkout; the memory sweep
# baselines that store, and merge tolerates its unstaged edits on main.

new_repo home/memproj
run "init sets autoMemoryDirectory under ~" 0 'autoMemoryDirectory = ~/memproj/.claude/memory' "$WB" init
check "the setting is tilde-based" grep -q '"autoMemoryDirectory": "~/memproj/.claude/memory"' .claude/settings.json
run "init leaves the setting alone next time" 0 "" bash -c "! '$WB' init 2>&1 | grep -q 'autoMemoryDirectory ='"
mkdir -p .claude/memory && echo '# Memory' > .claude/memory/MEMORY.md
git add -A && git commit -qm 'init + memory'
report=$("$WB" review memory 2>/dev/null)
echo new > .claude/memory/new.md
run "a memory sweep baselines the in-tree store" 1 "new.md" "$WB" review-check "$report"
rm .claude/memory/new.md; "$WB" review-drop "$report" >/dev/null 2>&1
newc bug "one" >/dev/null; "$WB" start b-001 >/dev/null 2>&1
( cd .worktrees/b-001-one && echo fix > src.txt && git add -A && git commit -qm fix )
ready .worktrees/b-001-one
echo learned >> .claude/memory/MEMORY.md
run "merge tolerates unstaged memory edits on main" 0 "merged b-001" "$WB" merge b-001 "one" --no-review
check "the memory edit stayed out of the squash" bash -c "! git show --stat --format= HEAD | grep -q MEMORY.md"
check "the memory edit is still pending" [ -n "$(git status --porcelain .claude/memory)" ]
git add -A && git commit -qm memory
newc bug "two" >/dev/null; "$WB" start b-002 >/dev/null 2>&1
( cd .worktrees/b-002-two && echo fix2 > src2.txt && git add -A && git commit -qm fix2 )
ready .worktrees/b-002-two
echo staged >> .claude/memory/MEMORY.md && git add .claude/memory/MEMORY.md
run "merge refuses staged memory edits" 1 "staged changes" "$WB" merge b-002 "two" --no-review
git reset -q && git checkout -q .claude/memory/MEMORY.md
echo other >> README
run "merge tolerates any unstaged edit on main" 0 "merged b-002" "$WB" merge b-002 "two" --no-review
check "the README edit stayed out of the squash" bash -c "! git show --stat --format= HEAD | grep -q README"
check "the README edit is still pending" [ -n "$(git status --porcelain README)" ]
git checkout -q README
# an unstaged deletion is the one edit git would not protect from the squash
newc bug "three" >/dev/null; "$WB" start b-003 >/dev/null 2>&1
( cd .worktrees/b-003-three && echo touched >> README && git add -A && git commit -qm touch )
ready .worktrees/b-003-three
rm README
run "merge refuses an unstaged deletion on main" 1 "uncommitted deletion the squash would undo" "$WB" merge b-003 "three" --no-review
check "the refusal names the file" bash -c "'$WB' merge b-003 three --no-review 2>&1 | grep -q '^  README'"
git checkout -q README
run "merge goes through once the file is back" 0 "merged b-003" "$WB" merge b-003 "three" --no-review

# --- rendered copies: migration from links, staleness, templates ------------

new_repo copies
src_root=$(readlink -f "$(dirname "$WB")/..")  # the workbench root; the CLI sits in its bin/
"$WB" init >/dev/null 2>&1
rm -rf .claude/skills/wb && ln -s "$src_root/commands/wb" .claude/skills/wb
printf '.claude/skills/workbench\n.claude/skills/wb\n.claude/skills/rename\n' >> .gitignore
mkdir -p .claude/skills/rename && printf "x\nx\ngenerated by 'workbench init' from workbench/commands/rename\n" > .claude/skills/rename/GENERATED
mkdir -p .claude/skills/foreign && printf 'x\nx\nmade elsewhere\n' > .claude/skills/foreign/GENERATED
run "init replaces an old link with a copy" 0 "skills/wb: link replaced by a copy" "$WB" init
check "a foreign GENERATED file is not a workbench stamp" [ -f .claude/skills/foreign/GENERATED ]
rm -rf .claude/skills/foreign
check "the copy is no longer a link" bash -c "[ ! -L .claude/skills/wb ] && [ -f .claude/skills/wb/GENERATED ]"
check "init drops the old ignore lines" bash -c "! grep -q 'claude/skills' .gitignore"
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
# a .gitignore holding nothing but a stale line empties cleanly
new_repo gi
printf '.claude/skills/workbench\n' > .gitignore
run "init strips the only line of a .gitignore" 0 "workbench ready" "$WB" init
check "no .gitignore.tmp is left behind" [ ! -e .gitignore.tmp ]
check "the stale line is gone" bash -c "! grep -q 'claude/skills' .gitignore"
check ".worktrees/ is ignored" grep -qx '.worktrees/' .gitignore
cd "$TMP/copies"
mkdir -p .claude/skills/hand && echo x > .claude/skills/hand/SKILL.md
cp -R "$src_root/commands/idea" .claude/skills/idea-copy && rm -rf .claude/skills/idea && mv .claude/skills/idea-copy .claude/skills/idea
run "init refuses a skill dir it did not generate" 1 "was not generated by workbench" "$WB" init
rm -rf .claude/skills/idea
# a .tpl in a source renders with the project's own values
cp -R "$src_root" "$TMP/src"
printf '@@PROJECT@@ on @@DEFAULT_BRANCH@@\n' > "$TMP/src/commands/wb/probe.md.tpl"
run "init renders a template from an overridden source" 0 "rendered .claude/skills/wb" env WORKBENCH_ROOT="$TMP/src" "$WB" init
check "the template is substituted" grep -qx 'copies on main' .claude/skills/wb/probe.md
check "the .tpl itself is not copied" [ ! -e .claude/skills/wb/probe.md.tpl ]
# the hash sees paths, not just content: a rename in the source is a change
mv "$TMP/src/commands/wb/probe.md.tpl" "$TMP/src/commands/wb/probe2.md.tpl"
run "a renamed source file shows the copy as stale" 0 "behind their source" env WORKBENCH_ROOT="$TMP/src" "$WB" status
ln -s SKILL.md "$TMP/src/commands/wb/link.md"
run "init refuses a symlink in a source" 1 "is a symlink" env WORKBENCH_ROOT="$TMP/src" "$WB" init
rm "$TMP/src/commands/wb/link.md"

# adopt on a symlinked CLAUDE.md edits the target, not the link
new_repo adopt
mkdir -p docs && echo '# adopt' > docs/CLAUDE.md && ln -s docs/CLAUDE.md CLAUDE.md && git add -A && git commit -qm claude
run "adopt" 0 "/workbench-review adopt" "$WB" adopt
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
run "merge stops when the branch touches a file edited on main" 1 "an uncommitted edit on main is in the way of the branch" "$WB" merge b-001 "one" --no-review
check "the stopped squash left main clean" [ -z "$(git -C . status --porcelain --untracked-files=no | grep -v '^ M README')" ]
git checkout -q README
git add README 2>/dev/null; echo staged >> README && git add README
run "merge refuses staged dirt on main" 1 "staged changes; the squash commit would absorb them" "$WB" merge b-001 "one" --no-review
git reset -q && git checkout -q README

# generic dirt beyond the item file
( cd .worktrees/b-001-one && echo more >> README )
run "merge names generic dirt generically" 1 "has uncommitted changes; commit or discard" "$WB" merge b-001 "one" --no-review
( cd .worktrees/b-001-one && git checkout -q README )

# the item file plus a stray .md: not the item-only case
( cd .worktrees/b-001-one && echo n > notes.md && echo e >> workbench/items/bugs/b-001-one.md )
run "merge with item file and a stray .md is generic" 1 "has uncommitted changes; commit or discard" "$WB" merge b-001 "one" --no-review
( cd .worktrees/b-001-one && rm notes.md && git checkout -q workbench/items/bugs/b-001-one.md )

# main's copy edited after start, in a hunk the branch never touched: a
# three-way merge would take it silently, so it is refused before that
sed -i '1a\
edited on main' workbench/items/bugs/b-001-one.md && git commit -qm 'edited on main after start' -- workbench/items/bugs/b-001-one.md
run "merge refuses when main's copy of the item moved since the cut" 1 "main's copy of b-001 changed since b-001-one was cut" "$WB" merge b-001 "one" --no-review
check "the refusal touched nothing" [ -z "$(git log --grep='^Item:' --format=%h)" ]
git checkout -q HEAD~1 -- workbench/items/bugs/b-001-one.md && git commit -qm 'main back' -- workbench/items/bugs/b-001-one.md

# The branch copy of the item is the merge gate's only witness. Deleted, every
# check it feeds — fences, status, the trigger, evidence — was skipped silently,
# and the first sign was an archived item whose gate never ran.
( cd .worktrees/b-001-one && git rm -q workbench/items/bugs/b-001-one.md && git commit -qm "drop the item" )
run "merge refuses when the branch carries no item file" 1 "no item file on b-001-one" "$WB" merge b-001 "one" --no-review
( cd .worktrees/b-001-one && git checkout -q HEAD~1 -- workbench/items/bugs/b-001-one.md && git commit -qm "restore the item" )

# conflicting branch
echo b >> README && git commit -qam b
run "merge refuses a conflicting branch" 1 "conflicts with main" "$WB" merge b-001 "one" --no-review
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
# A pre-merge must read the branch. With the worktree gone, find_item falls
# through to the main checkout — item files live there from creation — so the
# reviewer, the baseline and review-check all agree on main and the pass is
# stamped on a branch commit nobody read. Nothing downstream can catch that.
git add -A && git commit -qm "settle the archive above"
idw=$(newc bug "no-worktree"); "$WB" start "$idw" >/dev/null 2>&1
( cd ".worktrees/$idw-no-worktree" && echo w > w.txt && git add -A && git commit -qm w )
git worktree remove --force ".worktrees/$idw-no-worktree"
run "pre-merge refuses a branch whose worktree is gone" 1 "has no worktree" "$WB" review pre-merge "$idw"
check "and no report was opened" [ -z "$(find workbench/reviews -name "*$idw*" 2>/dev/null)" ]
run "the refusal says how to get one" 1 "workbench start $idw" "$WB" review pre-merge "$idw"
git branch -D "$idw-no-worktree" >/dev/null
# an item with no branch at all still reviews: it is a reachable pre-merge input
idnb=$(newc bug "never-started")
report=$("$WB" review pre-merge "$idnb")
check "pre-merge still opens for an item never started" [ -f "$report" ]
"$WB" review-drop --force "$report" >/dev/null 2>&1

# retire overwrites main's copy, so a main-side edit since the cut is refused
# rather than lost
idr=$(newc bug "retire-guard"); "$WB" start "$idr" >/dev/null 2>&1
set_status ".worktrees/$idr-retire-guard/workbench/items/bugs/$idr-retire-guard.md" unreproduced
echo kept >> "workbench/items/bugs/$idr-retire-guard.md" && git commit -qm 'main moved' -- "workbench/items/bugs/$idr-retire-guard.md"
run "archive refuses to retire over a main copy that moved" 1 "main's copy of $idr changed since $idr-retire-guard was cut" "$WB" archive "$idr"
check "main's copy still holds its edit" grep -qx kept "workbench/items/bugs/$idr-retire-guard.md"
git checkout -q HEAD~1 -- "workbench/items/bugs/$idr-retire-guard.md" && git commit -qm 'main back' -- "workbench/items/bugs/$idr-retire-guard.md"
run "archive retires once main's copy is back" 0 "retired $idr-retire-guard" "$WB" archive "$idr"
git add -A && git commit -qm "archive $idr"

# The squash is not transactional: cleanup after the commit can fail, and the
# commit is already on main when it does. Refused before the commit where the
# worktree cannot be removed, and a re-run of the half-finished state names what
# was left rather than refusing with nowhere to go.
idk=$(newc bug "locked"); "$WB" start "$idk" >/dev/null 2>&1
( cd ".worktrees/$idk-locked" && echo l > l.txt && git add -A && git commit -qm l ); ready ".worktrees/$idk-locked"
git worktree lock ".worktrees/$idk-locked"
run "merge refuses a locked worktree" 1 "worktree .* is locked" "$WB" merge "$idk" "locked" --no-review
check "and the refusal came before the commit" [ -z "$(git log --grep="^Item: $idk\$" --format=%h)" ]
git worktree unlock ".worktrees/$idk-locked"
run "merge takes it once unlocked" 0 "merged $idk" "$WB" merge "$idk" "locked" --no-review
# the half-finished shape: the trailer is on main, the branch never went away
git branch "$idk-locked" main
run "a re-run names what cleanup left behind" 1 "cleanup after that commit did not finish" "$WB" merge "$idk" "locked" --no-review
run "and gives the command that finishes it" 1 "branch -D $idk-locked" "$WB" merge "$idk" "locked" --no-review
git branch -D "$idk-locked" >/dev/null
run "with nothing left behind it is the plain refusal" 1 "already carries 'Item: $idk'" "$WB" merge "$idk" "locked" --no-review

# an item on its branch alone — started under an older workbench, so never
# on main at the cut — with the worktree gone: archive reads the branch, the
# guard above does not fire, and no temp file is left behind on a refusal
# branch_only <id> <slug> <status> — the old-model shape: an item file that
# exists on its branch and nowhere else, worktree already gone.
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
git add -A && git commit -qm "archive $ido"

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
run "merge refuses the branch's item copied onto main by hand" 1 "main's copy of $idd changed since $idd-dup was cut" "$WB" merge "$idd" "dup" --no-review
check "the refusal left main clean" [ -z "$(git status --porcelain --untracked-files=no)" ]
git checkout -q HEAD~1 -- "workbench/items/bugs/$idd-dup.md" && git commit -qm 'item back' -- "workbench/items/bugs/$idd-dup.md"
run "merge with the work already on main carries the item alone" 0 "merged $idd" "$WB" merge "$idd" "dup" --no-review
check "the squash holds only the item file" [ "$(git show --stat --format= HEAD | grep -c '|')" -eq 1 ]

# another item's file written on the branch would ride the squash under the
# wrong trailer; one landed on main since the cut is not on the branch
idh=$(newc bug "host"); "$WB" start "$idh" >/dev/null 2>&1
ready ".worktrees/$idh-host"
idg=$(newc feature "guest")
check "an item landed after the cut is not on the branch" [ -z "$(git diff --name-only "main...$idh-host" | grep guest)" ]
cp "workbench/items/features/$idg-guest.md" ".worktrees/$idh-host/workbench/items/features/"
( cd ".worktrees/$idh-host" && git add -A && git commit -qm 'guest by hand' )
run "merge refuses a branch carrying another item's file" 1 "carries another item's file" "$WB" merge "$idh" "host" --no-review
check "the refusal names the guest file" bash -c "'$WB' merge $idh host --no-review 2>&1 | grep -q '^  workbench/items/features/$idg-guest.md$'"
check "the refusal does not name the host's own file" bash -c "! '$WB' merge $idh host --no-review 2>&1 | grep -q '$idh-host.md'"
check "nothing landed on main" [ -z "$(git log --grep="^Item: $idh" --format=%h)" ]
( cd ".worktrees/$idh-host" && git rm -q "workbench/items/features/$idg-guest.md" && git commit -qm 'guest off' )
run "merge goes through once the file is off the branch" 0 "merged $idh" "$WB" merge "$idh" "host" --no-review
check "the squash carries only the host's item" bash -c "! git show --stat --format= HEAD | grep -q guest"

# --- lookups over every worktree --------------------------------------------
# A detached worktree with no workbench/, an item created in a sibling, a
# pre-merge before the item commit, a worktree removed by hand, and archive
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

report=$("$WB" review pre-merge b-001 2>/dev/null)
check "pre-merge on a branch with no commits says so" grep -q 'b-001-one carries no commits beyond main' "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

ready .worktrees/b-001-one
rm -rf .worktrees/b-001-one
run "status survives a worktree removed by hand" 0 "b-001-one +open +started" "$WB" status
run "merge names the unpruned worktree" 1 "git worktree prune" "$WB" merge b-001 "one" --no-review
git worktree prune
echo diverge >> README && git commit -qam diverge
run "merge after prune" 0 "merged b-001" "$WB" merge b-001 "one" --no-review
ready ".worktrees/$ids-from-sibling"
echo diverge >> README && git commit -qam diverge2
out=$("$WB" merge "$ids" "two" --no-review 2>&1)
check "merge prints nothing of git's own on success" [ "$(grep -c 'Automatic merge' <<< "$out")" -eq 0 ]

# archive from a sibling worktree: main's copy is the item's home
fill_evidence workbench/items/bugs/b-001-one.md "run" "ok"
idy=$(newc bug "sibling"); "$WB" start "$idy" >/dev/null 2>&1
check "setup: the sibling inherited b-001's merged copy" [ -f ".worktrees/$idy-sibling/workbench/items/bugs/b-001-one.md" ]
check "find from a sibling lists a merged item once" [ "$(cd ".worktrees/$idy-sibling" && "$WB" find --grep one 2>/dev/null | grep -c '^b-001 ')" -eq 1 ]
run "archive from a sibling worktree archives main's copy" 0 "git -C $PWD add" bash -c "cd .worktrees/$idy-sibling && '$WB' archive b-001"
check "main's copy is in the archive" [ -f workbench/items/archive/b-001-one.md ]
check "the sibling's copy is untouched" [ -f ".worktrees/$idy-sibling/workbench/items/bugs/b-001-one.md" ]
run "status does not list the sibling's stale copy of an archived item" 0 "" bash -c "! '$WB' status | grep -q b-001-one"
run "statusline counts the two real items, not the stale copy" 0 "wb: 2 open$" bash -c "$(declare -f session); session '$PWD' | sed 's/\"display_name\":\"Opus\"/\"display_name\":\"\"/' | '$WB' statusline"
run "find --grep from a sibling lists an archived item once, as archived" 0 "^b-001 .*archived" \
  bash -c "cd .worktrees/$idy-sibling && '$WB' find --grep one | grep -c '^b-001 ' | grep -qx 1 && '$WB' find --grep one"
run "find by path from a sibling picks the archived copy" 0 "^b-001 .*archived" \
  bash -c "cd .worktrees/$idy-sibling && '$WB' find workbench/items/bugs/b-001-one.md | grep -c '^b-001 ' | grep -qx 1 && '$WB' find workbench/items/bugs/b-001-one.md"

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
# origin's ref outlives the merge and the archive; neither may be resumed
ready .worktrees/b-001-gone
"$WB" merge b-001 "gone" --no-review >/dev/null 2>&1
check "setup: b-001 merged in the clone" [ -n "$(git log --grep='^Item: b-001$' --format=%h)" ]
check "setup: origin still has the branch after the merge" [ -n "$(git branch -r --list origin/b-001-gone)" ]
run "start refuses a merged item whose ref is left on origin" 1 "already merged as [0-9a-f]+; origin/b-001-gone is a leftover" "$WB" start b-001
check "no worktree was cut for it" [ ! -e .worktrees/b-001-gone ]
fill_evidence workbench/items/bugs/b-001-gone.md "run" "ok"
"$WB" archive b-001 >/dev/null 2>&1
run "start refuses an archived item whose ref is left on origin" 1 "already archived" "$WB" start b-001

# --- gates: calls, provisional (agent) decisions, the review mark, holds ------

new_repo gates
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
run "call parks a question naming its item" 0 "workbench/DECISIONS.md$" "$WB" call b-001 "criterion: is the count right?"
check "the call is one bullet with the id" grep -qx -- '- b-001: criterion: is the count right?' workbench/DECISIONS.md
run "call takes - for no item" 0 "" "$WB" call - "which realm first?"
check "the id-less call is a bullet" grep -qx -- '- which realm first?' workbench/DECISIONS.md
run "call refuses a newline" 1 "a call is one line" "$WB" call - $'a\nb'
run "call refuses an essay" 1 "one question under" "$WB" call - "$(printf 'x%.0s' $(seq 1 301))"
run "status lists calls waiting on the user" 0 "calls waiting on the user" "$WB" status
check "status prints the call lines" bash -c "'$WB' status | grep -q '^  b-001: criterion: is the count right?$'"
git checkout -q workbench/DECISIONS.md

newc bug "unattended" >/dev/null; "$WB" start b-001 >/dev/null 2>&1
wt=.worktrees/b-001-unattended
( cd "$wt" && echo w > w.txt && git add -A && git commit -qm w )
set_status "$wt/workbench/items/bugs/b-001-unattended.md" 'awaiting — the next deploy (agent)'
( cd "$wt" && git commit -qam provisional )
run "status lists a provisional status" 0 "provisional decisions \(agent\)" "$WB" status
check "the provisional line names the item and the status" bash -c "'$WB' status | grep -q '^  b-001-unattended  *status: awaiting — the next deploy (agent)$'"
check "main's as-started copy is not what status reads" bash -c "! grep -q '(agent)' workbench/items/bugs/b-001-unattended.md"
run "merge accepts a provisional awaiting" 0 "merged b-001" "$WB" merge b-001 "unattended" --no-review
run "status still lists it, from main now" 0 "b-001-unattended  *status: awaiting — the next deploy \(agent\)" "$WB" status
set_status workbench/items/bugs/b-001-unattended.md 'unverified — the next deploy (agent)'
run "archive refuses a provisional status" 1 "was entered unattended; confirm it by deleting the '\(agent\)' marker" "$WB" archive b-001
set_status workbench/items/bugs/b-001-unattended.md 'unverified — the next deploy'
run "archive takes it once confirmed" 0 "archived b-001" "$WB" archive b-001
git add -A && git commit -qm 'archive b-001'

newc bug "reviewed" >/dev/null; "$WB" start b-002 >/dev/null 2>&1
wt=.worktrees/b-002-reviewed
( cd "$wt" && echo r > r.txt && git add -A && git commit -qm w ); ready "$wt"
report=$("$WB" review pre-merge b-002)
printf '\ncovered: r.txt, workbench/items/bugs/b-002-reviewed.md\nverdict: merge\n' >> "$report"
run "review-check records a merge verdict against the branch commit" 0 "verdict: merge — recorded for b-002 at $(git -C "$wt" rev-parse --short HEAD)" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1
( cd "$wt" && echo more >> r.txt && git commit -qam more )
run "merge refuses a review that read an older commit" 1 "read an older commit of b-002-reviewed" "$WB" merge b-002 "reviewed"
for n in 1 2 3; do
  report=$("$WB" review pre-merge b-002)
  printf '\ncovered: r.txt, workbench/items/bugs/b-002-reviewed.md\nverdict: hold — the count is wrong\n' >> "$report"
  out=$("$WB" review-check "$report" 2>&1)
  [ "$n" -lt 3 ] && check "hold $n is counted" grep -q "hold $n of 3 for b-002" <<< "$out"
  "$WB" review-drop "$report" >/dev/null 2>&1
done
check "the third hold says to stop and call" grep -q "three holds: stop, 'workbench call b-002" <<< "$out"
run "merge refuses after holds" 1 "no passed pre-merge review" "$WB" merge b-002 "reviewed"

# --- abandoned: the one exit for work the user drops --------------------------

new_repo drop
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
# an unproved item naming the path, older than the abandoned one below
idu=$(newc bug "unproved"); printf '\nsee src/realm.ts\n' >> "workbench/items/bugs/$idu-unproved.md"
set_status "workbench/items/bugs/$idu-unproved.md" 'unverified — a third party'
"$WB" archive "$idu" >/dev/null 2>&1; git add -A && git commit -qm "archive $idu"
# never started: on main only
idn=$(newc feature "never started"); fn=workbench/items/features/$idn-never-started.md
set_status "$fn" abandoned
run "archive refuses abandoned without a why" 1 "'abandoned' must say why" "$WB" archive "$idn"
set_status "$fn" 'abandoned — superseded by the realm rewrite'
run "archive takes an abandoned item never started" 0 "archived $idn at none" "$WB" archive "$idn"
check "it records no commit" grep -qx 'commit: none' "workbench/items/archive/$idn-never-started.md"
git add -A && git commit -qm "archive $idn"
# started, with half-built work on the branch
idh=$(newc feature "half built"); "$WB" start "$idh" >/dev/null 2>&1
wt=.worktrees/$idh-half-built; fh=$wt/workbench/items/features/$idh-half-built.md
( cd "$wt" && echo half > half.txt && git add -A && git commit -qm half )
printf '\ntouches src/realm.ts\n' >> "$fh"
set_status "$fh" 'abandoned — not worth finishing'
( cd "$wt" && git commit -qam abandon && echo more > scratch.txt )
run "merge refuses an abandoned item" 1 "abandoned and never merges" "$WB" merge "$idh" "half" --no-review
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
git add -A && git commit -qm "archive $idh"
run "find lists an abandoned item by the path it named" 0 "^$idh .*abandoned — not worth finishing" "$WB" find src/realm.ts
check "the unproved item still sorts first, though older" bash -c "'$WB' find src/realm.ts | head -1 | grep -q '^$idu '"
# --discard stays refused where nothing is ever dropped
idg=$(newc bug "ghost"); "$WB" start "$idg" >/dev/null 2>&1
set_status ".worktrees/$idg-ghost/workbench/items/bugs/$idg-ghost.md" unreproduced
run "--discard is refused for an unreproduced bug" 1 "for research and abandoned items" "$WB" archive "$idg" --discard
"$WB" archive "$idg" >/dev/null 2>&1; git add -A && git commit -qm "archive $idg"
# shipped work is not abandoned
ids=$(newc bug "shipped"); "$WB" start "$ids" >/dev/null 2>&1
( cd ".worktrees/$ids-shipped" && echo s > s.txt && git add -A && git commit -qm s ); ready ".worktrees/$ids-shipped"
"$WB" merge "$ids" "shipped" --no-review >/dev/null 2>&1
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
# research never takes it; a provisional one is unarchivable
idx=$(newc research "area"); "$WB" start "$idx" >/dev/null 2>&1
set_status ".worktrees/$idx-area/workbench/items/research/$idx-area.md" 'abandoned — no'
run "research refuses abandoned" 1 "stays 'open' until archived" "$WB" archive "$idx"
idp=$(newc feature "unattended drop")
set_status "workbench/items/features/$idp-unattended-drop.md" 'abandoned — looked pointless (agent)'
run "archive refuses a provisional abandoned" 1 "entered unattended" "$WB" archive "$idp"

# --- statusline with awaiting items and reports, find by absolute path ------

new_repo sl
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
"$WB" new bug "waits" >/dev/null 2>&1
set_status workbench/items/bugs/b-001-waits.md 'awaiting — the next release'
git add -A && git commit -qm 'awaiting on main'
report=$("$WB" review memory 2>/dev/null)
run "statusline counts awaiting items and reports" 0 '^wb: 1 open · 1 awaiting · 1 report$' bash -c "$(declare -f session); session '$PWD' | sed 's/\"display_name\":\"Opus\"/\"display_name\":\"\"/' | '$WB' statusline"
"$WB" review-drop "$report" >/dev/null 2>&1
newc bug "abs" >/dev/null; "$WB" start b-002 >/dev/null 2>&1
( cd .worktrees/b-002-abs && echo a >> README && git add -A && git commit -qm a )
ready .worktrees/b-002-abs
"$WB" merge b-002 "abs" --no-review >/dev/null 2>&1
check "find by a relative path lists the item" bash -c "'$WB' find README | grep -q '^b-002 '"
check "find by an absolute path lists the item" bash -c "'$WB' find '$PWD/README' | grep -q '^b-002 '"
check "find by an absolute path outside the repo lists nothing" not_listed b-002 /nonexistent/README
check "find --grep is a fixed string" not_listed b-002 --grep 'a.s'

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

# --- find's cap, and citations that name a file without its path ------------

new_repo cap
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
for i in $(seq 1 11); do "$WB" new bug "cap $i" >/dev/null 2>&1; done
check "find shows ten lines and counts the rest" bash -c "'$WB' find --grep cap | grep -c '^b-' | grep -qx 10 && '$WB' find --grep cap | grep -q '… 1 more'"
check "find --all shows every line" bash -c "'$WB' find --grep cap --all | grep -c '^b-' | grep -qx 11 && ! '$WB' find --grep cap --all | grep -q 'more'"
mkdir -p a b && seq 5 > a/pos_test.go && seq 50 > b/pos_test.go && git add -A && git commit -qm pos
report=$("$WB" review sweep 2>/dev/null)
printf '\nsee pos_test.go:42, db.internal:5432 and 2026-08-26T10:15:30\n' >> "$report"
run "a basename citation passes when any file of that name reaches the line" 0 "^clean:" "$WB" review-check "$report"
"$WB" review-drop "$report" >/dev/null 2>&1
report=$("$WB" review sweep 2>/dev/null)
printf '\nsee pos_test.go:99 and other.go:3\n' >> "$report"
run "a basename citation fails when no file of that name reaches the line" 1 "cites pos_test.go:99, and no pos_test.go has 99 lines" "$WB" review-check "$report"
run "a basename with a known extension and no such file is bogus" 1 "cites other.go:3, and no other.go is in the tree" "$WB" review-check "$report"
"$WB" review-drop --force "$report" >/dev/null 2>&1

# --- worktree cut before the init commit ------------------------------------

new_repo early
"$WB" init >/dev/null           # left uncommitted: main has no workbench/
newc bug "early" >/dev/null
run "start notes an uncommitted .claude" 0 "lacks the workbench commands" "$WB" start b-001
[ ! -d .worktrees/b-001-early/workbench/reviews ] || fail "setup: reviews/ unexpectedly present"
report=$("$WB" review pre-merge b-001 2>/dev/null) || true
check "review pre-merge creates reviews/ when the branch lacks it" [ -f "$report" ]
"$WB" review-drop "$report" >/dev/null 2>&1
# The worktree's workbench/ holds nothing tracked but the item; the item must
# still be seen as the one file it is, not as the directory.
set_status .worktrees/b-001-early/workbench/items/bugs/b-001-early.md unreproduced
run "archive retires a branch whose workbench/ is untracked" 0 "retired b-001-early" "$WB" archive b-001

# --- sessions: lead, workers, cap, signals, gates, mode, open, round -------

new_repo sessions
rm -rf "$TMUX_SHIM_STATE"
run "init" 0 "workbench ready" "$WB" init
git add -A && git commit -qm 'workbench init'
tlog() { cat "$TMUX_SHIM_STATE/log"; }
title_of() { grep -P "^$1\t" "$TMUX_SHIM_STATE/windows" | cut -f3; }
reg_of() { grep -lP "^worker\t$1\t" .git/workbench/sessions/@* | xargs -n1 basename; }
hook() { printf '{"session_id":"%s","cwd":"%s","permission_mode":"acceptEdits","tool_name":"%s","tool_input":{"to":"%s","command":"rm x"},"agent_type":"%s","message":"needs a decision"}' "${1:-sid-1}" "${2:-$PWD}" "${3:-Bash}" "${4:-}" "${5:-}"; }
# The gates' JSON is a contract with Claude Code, not a string. A substring
# match passes on a wrong shape — which is how a string-valued 'decision'
# shipped, inert, past a green suite — so assert the documented objects:
# PermissionRequest carries decision as an object with behavior/message, and
# exit 2 is not honoured for it; PreToolUse carries the flat strings and is.
deny_schema() {
  python3 -c 'import json,sys
d = json.load(sys.stdin)["hookSpecificOutput"]
assert d["hookEventName"] == "PermissionRequest", d
c = d["decision"]
assert isinstance(c, dict), "decision must be an object, got %r" % (c,)
assert c["behavior"] == "deny", c
assert isinstance(c.get("message"), str) and c["message"], c
assert "decisionReason" not in d and "verdict" not in c, d'
}
ask_schema() {
  python3 -c 'import json,sys
d = json.load(sys.stdin)["hookSpecificOutput"]
assert d["hookEventName"] == "PreToolUse", d
assert d["permissionDecision"] == "deny", d
r = d["permissionDecisionReason"]
assert isinstance(r, str) and r, r'
}
export -f tlog title_of reg_of hook deny_schema ask_schema

s1=$(newc bug "one")
run "start without a lead is git-only" 0 "started $s1" "$WB" start "$s1"
check "no window was opened" bash -c "! tlog | grep -q new-window"
run "open without a lead refuses" 1 "no tmux session wb-sessions; 'workbench lead' starts it" "$WB" open "$s1"
run "mode defaults to attended" 0 '^attended$' "$WB" mode
git config workbench.mode unattended
run "gate ask, unattended, refuses a session working alone" 2 "move to work that is describable" bash -c "hook | '$WB' gate ask"
run "gate permission, unattended, denies a session working alone" 0 '"decision"' bash -c "hook | '$WB' gate permission"
check "and the denial is the documented decision object" bash -c "hook | '$WB' gate permission | deny_schema"
git config workbench.mode attended
run "gate ask, attended, is quiet for a session working alone" 0 "" bash -c "hook | '$WB' gate ask"

run "lead creates the tmux session" 0 "started wb-sessions: window lead runs wb-sessions-lead" env TMUX=x "$WB" lead
check "the lead session is named for the repo" grep -qx wb-sessions "$TMUX_SHIM_STATE/sessions"
check "the lead runs claude under its session name" bash -c "tlog | grep -q 'claude -n wb-sessions-lead'"
check "the lead window is registered" grep -qP '^lead\t-\t' .git/workbench/sessions/@1
check "lead switches this client to its window" bash -c "tlog | grep -q '^switch-client -t @1'"

s2=$(newc bug "two")
run "start under a lead opens a worker window" 0 "opened window $s2 in wb-sessions" env TMUX=x "$WB" start "$s2"
w2=$(reg_of "$s2"); p2="%${w2#@}"
check "the window is named by the item id" [ "$(title_of "$w2")" = "$s2" ]
check "the worker runs claude as the wb-worker agent under its name" bash -c "tlog | grep -q 'claude -n wb-sessions-$s2 --agent wb-worker'"
check "the dispatch names the lead and the mode" bash -c "tlog | grep -q 'lead: wb-sessions-lead — mode: attended'"
check "the worker window opens in the worktree" bash -c "tlog | grep -q -- '-c $PWD/.worktrees/$s2-two '"
s3=$(newc bug "three")
n=$(tlog | grep -c new-window)
run "start --no-open opens nothing" 0 "started $s3" "$WB" start "$s3" --no-open
check "no window for --no-open" [ "$(tlog | grep -c new-window)" -eq "$n" ]
run "status shows the sessions header" 0 'sessions: wb-sessions · mode attended · workers 3/5' "$WB" status
run "status shows a started item with no session" 0 "$s3-.*\[no session\]" "$WB" status
run "status shows a worker opening" 0 "$s2-.*\[opening\]" "$WB" status

git config workbench.maxWorkers 3
s4=$(newc bug "four")
run "start refuses at maxWorkers" 1 "3 started .$s1 $s2 $s3.; finish or archive one, or 'git config workbench.maxWorkers 4'" "$WB" start "$s4"
check "the refused item has no branch" bash -c "! git branch --list '$s4-*' | grep -q ."
run "at the cap, a started item is refused as started, not as one too many" 1 "$s2 is already started; its worktree is" "$WB" start "$s2"
git config workbench.maxWorkers 4
run "a raised cap admits it" 0 "opened window $s4" "$WB" start "$s4"

# signals, from a pane the registry knows
run "the lead's session start records its permission mode" 0 "" bash -c "hook sid-lead | TMUX_PANE=%1 '$WB' signal start"
check "the lead row carries it" grep -qP "\tacceptEdits$" .git/workbench/sessions/@1
w4=$(reg_of "$s4"); p4="%${w4#@}"
run "a start without a permission mode leaves the slot open" 0 "" bash -c "printf '{\"session_id\":\"sid-4\"}' | TMUX_PANE=$p4 '$WB' signal start"
check "the slot is -" grep -qP "\tsid-4\tworking\t-$" ".git/workbench/sessions/$w4"
run "the first tool call fills it" 0 "" bash -c "hook sid-4 | TMUX_PANE=$p4 '$WB' signal working"
check "from the hook input" grep -qP "\tsid-4\tworking\tacceptEdits$" ".git/workbench/sessions/$w4"
check "workers before that took no permission mode" bash -c "! tlog | grep -q -- '--permission-mode'"
run "signal start records the session" 0 "" bash -c "hook sid-2 | TMUX_PANE=$p2 '$WB' signal start"
check "the registry holds the session id, state and permission mode" grep -qxP "worker\t$s2\tsid-2\tworking\tacceptEdits" ".git/workbench/sessions/$w2"
check "the title is the bare id while working" [ "$(title_of "$w2")" = "$s2" ]
run "signal needs-you" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal needs-you"
check "needs-you titles the window with ?" [ "$(title_of "$w2")" = "? $s2" ]
run "signal working with the question tool changes nothing" 0 "" bash -c "hook sid-2 '$PWD' AskUserQuestion | TMUX_PANE=$p2 '$WB' signal working"
check "the ? stays until the answer" [ "$(title_of "$w2")" = "? $s2" ]
run "signal working after a plain tool" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal working"
check "back to the bare id" [ "$(title_of "$w2")" = "$s2" ]
run "signal asked to the reviewer is ignored" 0 "" bash -c "hook sid-2 '$PWD' SendMessage reviewer | TMUX_PANE=$p2 '$WB' signal asked"
check "no ↑ for a reviewer message" [ "$(title_of "$w2")" = "$s2" ]
run "signal asked to the lead by name" 0 "" bash -c "hook sid-2 '$PWD' SendMessage wb-sessions-lead | TMUX_PANE=$p2 '$WB' signal asked"
check "↑ for a message to the lead" [ "$(title_of "$w2")" = "↑ $s2" ]
run "signal stopped keeps asked" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal stopped"
check "stopped after asking stays ↑" [ "$(title_of "$w2")" = "↑ $s2" ]
run "a session start on compaction changes nothing" 0 "" bash -c "printf '{\"session_id\":\"sid-2\",\"source\":\"compact\"}' | TMUX_PANE=$p2 '$WB' signal start"
check "still ↑ after compacting" [ "$(title_of "$w2")" = "↑ $s2" ]
run "the lead replying to a worker is not asking" 0 "" bash -c "hook sid-lead '$PWD' SendMessage uds:/run/w.sock | TMUX_PANE=%1 '$WB' signal asked"
check "the lead's title is untouched" [ "$(title_of @1)" = "lead" ]
run "signal working" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal working"
run "signal asked to a socket address" 0 "" bash -c "hook sid-2 '$PWD' SendMessage uds:/run/x.sock | TMUX_PANE=$p2 '$WB' signal asked"
check "↑ for a reply to the lead's socket" [ "$(title_of "$w2")" = "↑ $s2" ]
run "signal review" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal review"
check "⟳ while a reviewer runs" [ "$(title_of "$w2")" = "⟳ $s2" ]
run "a reviewer's own tool calls do not end the review" 0 "" bash -c "hook sid-2 '$PWD' Bash '' wb-reviewer | TMUX_PANE=$p2 '$WB' signal working"
check "still ⟳" [ "$(title_of "$w2")" = "⟳ $s2" ]
run "a turn that ends with the reviewer in the background stays in review" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal stopped"
check "still ⟳ after stopping" [ "$(title_of "$w2")" = "⟳ $s2" ]
run "signal working after the review" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal working"
wt2="$PWD/.worktrees/$s2-two"
run "signal stopped with nothing to show" 0 "" bash -c "hook sid-2 '$wt2' | TMUX_PANE=$p2 '$WB' signal stopped"
check "· for a turn that ended on nothing" [ "$(title_of "$w2")" = "· $s2" ]
"$WB" call "$s2" "which colour?" >/dev/null
run "signal stopped with an open call" 0 "" bash -c "hook sid-2 '$wt2' | TMUX_PANE=$p2 '$WB' signal stopped"
check "! for a parked call" [ "$(title_of "$w2")" = "! $s2" ]
sed -i "/^- $s2: /d" workbench/DECISIONS.md
mkdir -p .git/review-passed && git -C "$wt2" rev-parse HEAD > ".git/review-passed/$s2"
run "signal stopped with a passed review" 0 "" bash -c "hook sid-2 '$wt2' | TMUX_PANE=$p2 '$WB' signal stopped"
check "✓ when the review mark matches the branch" [ "$(title_of "$w2")" = "✓ $s2" ]
run "status shows the worker's state" 0 "$s2-.*\[ready\]" "$WB" status
run "statusline carries mode, cap and the flagged workers" 0 " · attended · 4/4 workers · ✓ $s2$" bash -c "$(declare -f session); session '$PWD' | '$WB' statusline"
n=$(tlog | grep -c rename-window)
run "a pane the registry does not know is left alone" 0 "" bash -c "hook | TMUX_PANE=%99 '$WB' signal needs-you"
check "no rename for a stranger" [ "$(tlog | grep -c rename-window)" -eq "$n" ]
run "signal end" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal end"
check "ended is recorded" grep -qP "\tended\t" ".git/workbench/sessions/$w2"
run "signal working" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal working"

# gates, by mode
run "gate ask, attended, lets the question through" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' gate ask"
check "and flags the window" [ "$(title_of "$w2")" = "? $s2" ]
run "gate permission, attended, prints nothing" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' gate permission"
check "gate permission printed nothing" [ -z "$(hook | TMUX_PANE=$p2 "$WB" gate permission)" ]
run "mode unattended names the live workers to tell" 0 "tell wb-sessions-$s2: mode is now unattended" "$WB" mode unattended
run "mode reads back" 0 '^unattended$' "$WB" mode
run "gate ask, unattended, refuses" 2 '"permissionDecision":"deny"' bash -c "hook | TMUX_PANE=$p2 '$WB' gate ask"
check "the refusal is the documented PreToolUse shape" bash -c "{ hook | TMUX_PANE=$p2 '$WB' gate ask || true; } | ask_schema"
run "the refusal says where to park it" 2 "workbench call <id>" bash -c "hook | TMUX_PANE=$p2 '$WB' gate ask"
run "gate permission, unattended, denies" 0 '"decision"' bash -c "hook | TMUX_PANE=$p2 '$WB' gate permission"
check "the denial is the documented decision object" bash -c "hook | TMUX_PANE=$p2 '$WB' gate permission | deny_schema"
run "the mode is the project's: a stranger's window is refused too" 2 "then send the lead" bash -c "hook | TMUX_PANE=%99 '$WB' gate ask"

# A tmux restart hands out window ids from @0 again, so a registry row can name
# a window that now belongs to another session entirely. Adopting it by id alone
# retitles a stranger's window.
git config workbench.mode attended
awk -F'\t' -v w="$w2" 'BEGIN{OFS="\t"} $1==w {$2="elsewhere"} {print}' "$TMUX_SHIM_STATE/windows" > "$TMUX_SHIM_STATE/w.t"
mv "$TMUX_SHIM_STATE/w.t" "$TMUX_SHIM_STATE/windows"
stale_title=$(title_of "$w2")
run "a signal from a window in another session is not ours" 0 "" bash -c "hook | TMUX_PANE=$p2 '$WB' signal working"
check "and the stranger's window keeps its title" [ "$(title_of "$w2")" = "$stale_title" ]
awk -F'\t' -v w="$w2" -v s="$(basename "$PWD")" 'BEGIN{OFS="\t"} $1==w {$2="wb-" s} {print}' "$TMUX_SHIM_STATE/windows" > "$TMUX_SHIM_STATE/w.t"
mv "$TMUX_SHIM_STATE/w.t" "$TMUX_SHIM_STATE/windows"
git config workbench.mode unattended
git config workbench.maxWorkers 9
s5=$(newc bug five)
run "start under unattended dispatches the mode" 0 "dispatch: wb-worker $s5 in .* — resources: account, client" "$WB" start "$s5" --resources "account, client"
check "the dispatch says unattended" bash -c "tlog | grep -q 'mode: unattended'"
check "the dispatch names the resources granted" bash -c "tlog | tail -1 | grep -q -- '— resources: account, client — lead:'"
check "workers take the lead's permission mode" bash -c "tlog | tail -1 | grep -q -- '--permission-mode acceptEdits --agent wb-worker'"
run "start wants a value after --resources" 2 "usage" "$WB" start "$(newc bug six-b)" --resources
w5=$(reg_of "$s5")
tmux kill-window -t "$w5"
run "open reopens a window whose session never registered, fresh" 0 "reopened $s5$" env TMUX=x "$WB" open "$s5"
check "fresh means the agent and the dispatch line again, no resume" bash -c "tlog | grep -- '--agent wb-worker .$s5 in .* — resources: none — lead: wb-sessions-lead' | grep -qv -- --resume"
run "mode rejects other words" 2 "usage" "$WB" mode sometimes
"$WB" mode attended >/dev/null

# open
run "open switches to a live window" 0 "" env TMUX=x "$WB" open "$s2"
check "switch-client targeted it" bash -c "tlog | grep -q '^switch-client -t $w2$'"
run "open lead" 0 "" env TMUX=x "$WB" open lead
check "the lead's window was targeted" bash -c "tlog | grep -q '^switch-client -t @1$'"
tmux kill-window -t "$w2"
run "open reopens a window that is gone, resuming the session" 0 "reopened $s2, resuming sid-2" env TMUX=x "$WB" open "$s2"
check "claude was resumed by id" bash -c "tlog | grep -q -- '--resume sid-2'"
check "the resumed worker is still the wb-worker agent" bash -c "tlog | grep -q -- '--agent wb-worker --resume sid-2$'"
check "the old registry file is gone" [ ! -e ".git/workbench/sessions/$w2" ]
w2=$(reg_of "$s2")
check "the item is registered under its new window" [ -n "$w2" ]
run "open refuses an item that is not started" 1 "is not started; 'workbench start" "$WB" open "$(newc bug six)"
run "open outside tmux attaches" 0 "" env -u TMUX "$WB" open "$s2"
check "attach was called, exactly" bash -c "tlog | grep -q '^attach -t =wb-sessions'"

# merge closes the window
ready "$wt2"
run "merge without review" 0 "merged $s2" "$WB" merge "$s2" "two done" --no-review
check "merge killed the worker's window" bash -c "tlog | grep -q '^kill-window -t $w2$'"
check "and dropped its registry file" [ ! -e ".git/workbench/sessions/$w2" ]
check "the window is gone from tmux" bash -c "! tmux list-windows -t wb-sessions | grep -qx '$w2'"

# round: the review dialog's accountant
r=$(newc feature "rounds")
f=$(find workbench/items -name "$r-*.md")
run "round one always asks for a second" 0 "next: review again — a new reviewer, round 2" "$WB" round "$r" 5 2
check "the item records it under status" grep -qx "rounds: r1 5/2 · again" "$f"
check "rounds sits right after the status line" bash -c "grep -A1 '^status: ' '$f' | grep -q '^rounds: '"
run "a clean second round stops" 0 "next: gate — /workbench-review pre-merge $r" "$WB" round "$r" 0 0
check "the line accumulates" grep -qx "rounds: r1 5/2 · r2 0/0 · stop" "$f"
r=$(newc feature "tail")
"$WB" round "$r" 4 0 >/dev/null
run "as many fixes as before continues" 0 "next: review again" "$WB" round "$r" 4 0
run "three fixes continue even when fewer" 0 "next: review again" "$WB" round "$r" 3 0
run "a small declining tail stops" 0 "next: gate" "$WB" round "$r" 1 0
r=$(newc feature "cap")
for _ in 1 2 3 4; do "$WB" round "$r" 5 0 >/dev/null; done
run "the fifth round parks it" 0 "next: call — 5 rounds and still finding" "$WB" round "$r" 5 0
check "the decision is recorded" grep -q " · call$" "$(find workbench/items -name "$r-*.md")"
r2=$(newc feature "tail")
run "a clean first round still gets a second" 0 "next: review again" "$WB" round "$r2" 0 0
run "one fix after a clean round is a tail" 0 "next: gate" "$WB" round "$r2" 1 0
r3=$(newc feature "trickle")
"$WB" round "$r3" 1 0 >/dev/null
run "one fix a round does not go on" 0 "next: gate" "$WB" round "$r3" 1 0
r4=$(newc feature "pair")
"$WB" round "$r4" 2 0 >/dev/null
run "two fixes after two continue" 0 "next: review again" "$WB" round "$r4" 2 0
r5=$(newc feature "drop")
"$WB" round "$r5" 5 0 >/dev/null
run "two after five stop" 0 "next: gate" "$WB" round "$r5" 2 0
run "round wants counts" 1 "fixed and stands are counts" "$WB" round "$r" many 0
# concatenated, "" and "3" read as the single count "3" and passed
run "round wants both counts, not their concatenation" 1 "fixed and stands are counts" "$WB" round "$r" "" 3
run "and rejects an empty second count too" 1 "fixed and stands are counts" "$WB" round "$r" 3 ""
run "round wants three arguments" 2 "usage" "$WB" round "$r" 1
# The rewrite goes through mktemp, which creates 0600; the item file is
# committed and read by everything downstream, so its mode must survive.
rp=$(newc feature "perms")
rf=$(find workbench/items -name "$rp-*.md")
chmod 644 "$rf"
"$WB" round "$rp" 1 0 >/dev/null
check "round leaves the item file's mode alone" bash -c "[ \"\$(stat -c %a '$rf')\" = 644 ]"

# --no-review is the user's override, so an unattended session cannot take it,
# and init writes tracked files that belong on the default branch.
new_repo "gates"
"$WB" init >/dev/null
git add -A && git commit -qm wb
gi=$(newc bug "gated")
"$WB" start "$gi" --no-open >/dev/null 2>&1
gwt=".worktrees/$(git branch --format='%(refname:short)' | grep "^$gi-")"
ready "$gwt"
# Before the merge below, which takes the worktree with it. A worktree is the
# only place init can land its files on a branch, so the refusal is the test —
# an unguarded init renders content identical to what the branch already has
# whenever the source has not drifted, so a clean 'git status' proves nothing.
run "init in a linked worktree is refused" 1 "run it in the main checkout" bash -c "cd '$PWD/$gwt' && '$WB' init"
git config workbench.mode unattended
run "merge --no-review is refused unattended" 1 "the mode is unattended" "$WB" merge "$gi" "gated" --no-review
run "the refusal names the gate to run instead" 1 "/workbench-review pre-merge $gi" "$WB" merge "$gi" "gated" --no-review
git config workbench.mode attended
run "and is the user's to take when they are here" 0 "merged $gi" "$WB" merge "$gi" "gated" --no-review

# A long criterion, unfenced. 'section_filled' piped into 'grep -q', which stops
# at the first non-blank byte it sees; under 'set -o pipefail' the writer was
# still sending, took SIGPIPE, and the pipeline reported 141 — read as an empty
# section. At this size it did that in 281 of 300 runs, so 'start' refused an
# item whose criterion was filled in. Small sections never showed it: the writer
# finishes before the reader exits.
new_repo "bigsection"
"$WB" init >/dev/null
git add -A && git commit -qm wb
bigid=$("$WB" new bug "long criterion" 2>/dev/null)
bigf=$(find workbench/items -name "$bigid-*.md")
{ echo; for i in $(seq 1 400); do echo "agreed with the user, line $i of a long agreed criterion"; done; } > "$TMP/bigcrit"
sed -i "/^## How to confirm/r $TMP/bigcrit" "$bigf"
check "the criterion is past the pipe buffer" [ "$(wc -c < "$bigf")" -gt 16384 ]
git add -A && git commit -qm "long criterion"
run "start takes an item whose criterion is long" 0 "started $bigid" "$WB" start "$bigid" --no-open

# a repo name tmux could not target
new_repo "dot.ted"
"$WB" init >/dev/null 2>&1
rm -rf "$TMUX_SHIM_STATE"
run "without a lead, --resources still reaches the dispatch line" 0 "dispatch: wb-worker .* — resources: account$" "$WB" start "$(newc bug "held")" --resources account
run "lead names the session without tmux's separators" 0 "started wb-dot-ted: window lead runs wb-dot-ted-lead" env TMUX=x "$WB" lead
check "and targets it exactly" bash -c "tlog | grep -q -- '-t =wb-dot-ted'"

echo
echo "$checks checks, $fails failed"
[ "$fails" -eq 0 ]
