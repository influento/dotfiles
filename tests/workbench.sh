#!/usr/bin/env bash
# End-to-end tests for common/scripts/workbench, run in a throwaway repository.
# Plain bash, no framework: each check is an exit code and a grep on output.
# Run: bash tests/workbench.sh
set -euo pipefail

WB=$(readlink -f "$(dirname "$0")/../common/scripts/workbench")
OPEN=$(readlink -f "$(dirname "$0")/../common/claude-code/skills-optional/workbench-review/scripts/open.sh")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export HOME="$TMP/home"  # no user gitconfig, hooks or aliases
mkdir -p "$HOME"

fails=0 checks=0
pass() { checks=$((checks + 1)); echo "ok   $1"; }
fail() { checks=$((checks + 1)); fails=$((fails + 1)); echo "FAIL $1" >&2; }
# check <label> <cmd...> — passes when the command succeeds.
check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }
# not_listed <id> <find-args...> — the index must not carry the id.
not_listed() { local id="$1"; shift; ! "$WB" find "$@" 2>/dev/null | grep -q "$id"; }

# run <label> <expected-rc> <pattern> <cmd...> — the pattern is grepped over
# combined stdout+stderr; an empty pattern skips the grep.
run() {
  local label="$1" want="$2" pat="$3"; shift 3
  local out rc=0
  out=$("$@" 2>&1) || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: rc=$rc, wanted $want"; printf '%s\n' "$out" | sed 's/^/     /' >&2; return
  fi
  if [ -n "$pat" ] && ! printf '%s\n' "$out" | grep -qE -- "$pat"; then
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

new_repo() {
  local d="$TMP/$1"
  rm -rf "$d"; mkdir -p "$d"; cd "$d"
  git init -q -b main
  echo hello > README && git add -A && git commit -qm init
}

# --- the happy loop ---------------------------------------------------------

new_repo loop
run "init" 0 "workbench ready" "$WB" init
run "init outside ~ says to set the memory path by hand" 0 "not under ~" "$WB" init
for c in workbench workbench-review bug feature research idea wb; do
  check "init renders /$c as a copy" [ -f ".claude/skills/$c/SKILL.md" ] && [ ! -L ".claude/skills/$c" ] && [ -f ".claude/skills/$c/GENERATED" ]
done
check "init does not ignore the copies" bash -c "! grep -q '.claude/skills' .gitignore"
check "no /rename is rendered" [ ! -e .claude/skills/rename ]
check "the stamp carries source and copy hashes" bash -c "sed -n 1,2p .claude/skills/wb/GENERATED | grep -cE '^[0-9a-f]{12}\$' | grep -qx 2"
check "init ignores .worktrees/" grep -qx '.worktrees/' .gitignore
check "init allows Bash(workbench:*)" grep -q 'Bash(workbench:\*)' .claude/settings.json
check "init writes the session hook" grep -q '"workbench status"' .claude/settings.json
check "init writes the status line" grep -q '"workbench statusline"' .claude/settings.json
run "init is idempotent" 0 "workbench ready" "$WB" init
check "unchanged copies are not re-rendered" bash -c "! '$WB' init 2>&1 | grep -q 'rendered .claude'"
check "the hook is not duplicated" [ "$(grep -c '"workbench status"' .claude/settings.json)" -eq 1 ]
run "status is quiet while the copies are current" 0 "" bash -c "! '$WB' status | grep -q 'behind their source'"
session() { printf '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"%s"}}' "$1"; }
run "statusline with nothing in flight" 0 '^\[Opus\] wb: nothing in flight$' bash -c "$(declare -f session); session '$PWD' | '$WB' statusline"
run "statusline outside a workbench project is silent" 0 "" bash -c "$(declare -f session); session '$HOME' | '$WB' statusline"
check "statusline outside a workbench project prints nothing" [ -z "$(session "$HOME" | "$WB" statusline)" ]
git add -A && git commit -qm 'workbench init'

id=$("$WB" new bug "crash on save" 2>/dev/null)
check "new allocates b-001" [ "$id" = b-001 ]
item=workbench/items/bugs/b-001-crash-on-save.md
check "new writes the item file" [ -f "$item" ]

run "start" 0 "moved $item onto the branch" "$WB" start b-001
wt=.worktrees/b-001-crash-on-save
check "start moves the item into the worktree" [ -f "$wt/$item" ]
check "start leaves no copy on main" [ ! -e "$item" ]
run "statusline names the worktree's item" 0 '^\[Opus\] wb: on b-001 · 1 open$' bash -c "$(declare -f session); session '$PWD/$wt' | '$WB' statusline"

run "merge names the uncommitted item file" 1 "$item is not committed on the branch" "$WB" merge b-001 "fix crash"

( cd "$wt" && mkdir -p sub && echo fix > src.txt && echo x > sub/x.txt && git add -A && git commit -qm wip )

report=$("$WB" review pre-merge b-001)
check "review pre-merge writes the skeleton in the worktree" [ -f "$report" ]
check "pre-merge manifest names the item file" grep -q 'changed on the branch: 3 files, the item file among them' "$report"
run "review-check fails on unstated coverage" 1 "never named in the report" "$WB" review-check "$report"
printf '\ncovered: src.txt, sub/, %s\nno findings\n' "$item" >> "$report"
run "review-check passes once coverage is named" 0 "^clean:" "$WB" review-check "$report"
run "merge refuses while a report stands" 1 "still holds a review report" "$WB" merge b-001 "fix crash"
run "review-drop" 0 "deleted" "$WB" review-drop "$report"
run "merge" 0 "merged b-001" "$WB" merge b-001 "fix crash"
check "squash carries the trailer" grep -qx 'Item: b-001' <(git log -1 --format=%B)
check "item file lands on main" [ -f "$item" ]
check "worktree removed" [ ! -e "$wt" ]

run "archive refuses without evidence" 1 "no evidence recorded" "$WB" archive b-001
printf '\nTBD\n' >> "$item"
run "archive refuses prose-only evidence" 1 "no evidence recorded" "$WB" archive b-001
fill_evidence "$item" "make test" "ok"
run "archive" 0 "archived b-001" "$WB" archive b-001
git add -A && git commit -qm 'archive b-001'

run "find by path" 0 "b-001" "$WB" find src.txt
run "find is cwd-relative" 0 "b-001" bash -c "cd sub && '$WB' find x.txt"
run "find unrelated path is empty" 0 "" "$WB" find README
check "find README does not list b-001" not_listed b-001 README

# Text match: an unproved item names a path in prose; a bare word inside a
# longer one must not hit.
id2=$("$WB" new bug "handler lost" 2>/dev/null)
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
rm "workbench/items/features/$id3-under-goal.md"

run "status" 0 "" "$WB" status

# The skill's preprocessed block is fail-closed, so the wrapper must turn a
# refusal into output with a zero exit.
run "open.sh folds a refusal into stdout" 0 "^workbench: reason must be" env PATH="$(dirname "$WB"):$PATH" bash "$OPEN" bogus ""
run "open.sh returns the path on success" 0 "/workbench/reviews/.*-sweep\.md$" env PATH="$(dirname "$WB"):$PATH" bash "$OPEN" sweep ""
"$WB" review-drop "$(command ls workbench/reviews/*-sweep.md)" >/dev/null 2>&1
report=$(env PATH="$(dirname "$WB"):$PATH" bash "$OPEN" sweep "resize")
check "open.sh with a topic scope returns the path alone" [ -f "$report" ]
check "the topic warning is in the skeleton" grep -q "scope 'resize' is not all paths" "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

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

idl=$("$WB" new feature "later" 2>/dev/null)          # unstarted, in main
printf '\ntouches src.txt when it lands\n' >> "workbench/items/features/$idl-later.md"
run "find lists an open unstarted item by text, as open" 0 "$idl .*open" "$WB" find src.txt
"$WB" start "$idl" >/dev/null 2>&1
set_status ".worktrees/$idl-later/workbench/items/features/$idl-later.md" "awaiting — next deploy"
run "status keeps an awaiting item on its branch under branches" 0 "" bash -c "'$WB' status | sed -n '/awaiting a trigger/,\$p' | grep -q '(none)'"
( cd ".worktrees/$idl-later" && git add -A && git commit -qm later )
"$WB" merge "$idl" "later" >/dev/null 2>&1
run "status lists a merged awaiting item" 0 "$idl-later" bash -c "'$WB' status | sed -n '/awaiting a trigger/,\$p'"

# start from inside another item's worktree: the file is copied, the branch named
idi=$("$WB" new bug "inner" 2>/dev/null) && "$WB" start "$idi" >/dev/null 2>&1
idn=$(cd ".worktrees/$idi-inner" && "$WB" new bug "nested" 2>/dev/null && git add -A && git commit -qm 'nested on inner')
run "start from another worktree copies an item committed there" 0 "copied .* also committed on $idi-inner" bash -c "cd .worktrees/$idi-inner && '$WB' start $idn"
check "the nested worktree sits under the main checkout" [ -d ".worktrees/$idn-nested" ]
check "the copy is on the nested branch" [ -f ".worktrees/$idn-nested/workbench/items/bugs/$idn-nested.md" ]

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
rm -f "workbench/items/features/$id5-under-goal-too.md"
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
run "archive --discard refuses a non-research id" 1 "for research items" "$WB" archive b-001 --discard
"$WB" start "$idx" >/dev/null 2>&1
rwt=.worktrees/$idx-netcode
ritem=$rwt/$ritem
run "merge refuses research" 1 "never merges" "$WB" merge "$idx" "netcode"
run "status shows a research item with no concepts" 0 "$idx-netcode +open +no concepts yet" "$WB" status
research_item "$ritem" "$idx" "" "open" "-> backlog"
run "status counts open concepts" 0 "$idx-netcode +open +1 of 2 concepts open" "$WB" status
run "statusline counts open concepts" 0 "wb: .* · $idx 1 / 2" bash -c "$(declare -f session); session '$PWD' | '$WB' statusline"
run "archive refuses with an open concept" 1 "still has open concepts" "$WB" archive "$idx"
research_item "$ritem" "$idx" "" "" "-> backlog"
run "archive names a concept without a state" 1 "concepts without a state line" "$WB" archive "$idx"
research_item "$ritem" "$idx" "" "-> f-999"
run "archive refuses a state naming a missing item" 1 "names 'f-999', which is not an item" "$WB" archive "$idx"
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
check "the user statusLine survives" grep -q '"echo mine"' .claude/settings.json
check "the hook is still added beside it" grep -q '"workbench status"' .claude/settings.json
echo 'not json' > .claude/settings.json
run "init leaves invalid settings alone" 0 "not valid JSON; left alone" "$WB" init
check "invalid settings are untouched" grep -qx 'not json' .claude/settings.json
# a statusLine that is not an object is left alone, and init still finishes
echo '{"statusLine":"echo hi","hooks":{"SessionStart":["odd"]}}' > .claude/settings.json
run "init survives a non-object statusLine" 0 "statusLine is already set" "$WB" init
check "the string statusLine survives" grep -q '"echo hi"' .claude/settings.json
check "the hook is added beside a non-object SessionStart entry" grep -q '"workbench status"' .claude/settings.json
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
"$WB" new bug "one" >/dev/null 2>&1; "$WB" start b-001 >/dev/null 2>&1
( cd .worktrees/b-001-one && echo fix > src.txt && git add -A && git commit -qm fix )
echo learned >> .claude/memory/MEMORY.md
run "merge tolerates unstaged memory edits on main" 0 "merged b-001" "$WB" merge b-001 "one"
check "the memory edit stayed out of the squash" bash -c "! git show --stat --format= HEAD | grep -q MEMORY.md"
check "the memory edit is still pending" [ -n "$(git status --porcelain .claude/memory)" ]
git add -A && git commit -qm memory
"$WB" new bug "two" >/dev/null 2>&1; "$WB" start b-002 >/dev/null 2>&1
( cd .worktrees/b-002-two && echo fix2 > src2.txt && git add -A && git commit -qm fix2 )
echo staged >> .claude/memory/MEMORY.md && git add .claude/memory/MEMORY.md
run "merge refuses staged memory edits" 1 "uncommitted changes" "$WB" merge b-002 "two"
git reset -q && git checkout -q .claude/memory/MEMORY.md
echo other >> README
run "merge still refuses other unstaged dirt" 1 "uncommitted changes" "$WB" merge b-002 "two"
git checkout -q README

# --- rendered copies: migration from links, staleness, templates ------------

new_repo copies
src_root=$(readlink -f "$(dirname "$WB")/../claude-code/skills-optional")
"$WB" init >/dev/null 2>&1
rm -rf .claude/skills/wb && ln -s "$src_root/workbench-commands/wb" .claude/skills/wb
printf '.claude/skills/workbench\n.claude/skills/wb\n.claude/skills/rename\n.claude/settings.local.json\n' >> .gitignore
mkdir -p .claude/skills/rename && printf "x\nx\ngenerated by 'workbench init' from skills-optional/workbench-commands/rename\n" > .claude/skills/rename/GENERATED
mkdir -p .claude/skills/foreign && printf 'x\nx\nmade elsewhere\n' > .claude/skills/foreign/GENERATED
run "init replaces an old link with a copy" 0 "skills/wb: link replaced by a copy" "$WB" init
check "a foreign GENERATED file is not a workbench stamp" [ -f .claude/skills/foreign/GENERATED ]
rm -rf .claude/skills/foreign
check "the copy is no longer a link" [ ! -L .claude/skills/wb ] && [ -f .claude/skills/wb/GENERATED ]
check "init drops the old ignore lines" bash -c "! grep -q 'claude/skills' .gitignore"
check "init keeps settings.local.json ignored" grep -qx '.claude/settings.local.json' .gitignore
check "init keeps .worktrees/ ignored" grep -qx '.worktrees/' .gitignore
check "init removes a generated copy of a skill that is gone" [ ! -e .claude/skills/rename ]
# a dropped skill's copy that was edited by hand is refused like any other
cp -R .claude/skills/idea .claude/skills/gone && sed -i "s|from skills-optional/[^;]*|from skills-optional/gone|" .claude/skills/gone/GENERATED
echo tweak >> .claude/skills/gone/SKILL.md
run "init refuses to remove an edited copy of a dropped skill" 1 "no longer a workbench skill but was edited by hand" "$WB" init
run "init --force removes it" 0 "removed .claude/skills/gone" "$WB" init --force
run "adopt takes --force too" 0 "workbench ready" "$WB" adopt --force
sed -i '1s/.*/000000000000/' .claude/skills/wb/GENERATED
run "status flags a copy behind its source" 0 "behind their source" "$WB" status
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
cp -R "$src_root/workbench-commands/idea" .claude/skills/idea-copy && rm -rf .claude/skills/idea && mv .claude/skills/idea-copy .claude/skills/idea
run "init refuses a skill dir it did not generate" 1 "was not generated by workbench" "$WB" init
rm -rf .claude/skills/idea
# a .tpl in a source renders with the project's own values
cp -R "$src_root" "$TMP/src"
printf '@@PROJECT@@ on @@DEFAULT_BRANCH@@\n' > "$TMP/src/workbench-commands/wb/probe.md.tpl"
run "init renders a template from an overridden source" 0 "rendered .claude/skills/wb" env WORKBENCH_SKILL_SRC="$TMP/src/workbench" "$WB" init
check "the template is substituted" grep -qx 'copies on main' .claude/skills/wb/probe.md
check "the .tpl itself is not copied" [ ! -e .claude/skills/wb/probe.md.tpl ]
# the hash sees paths, not just content: a rename in the source is a change
mv "$TMP/src/workbench-commands/wb/probe.md.tpl" "$TMP/src/workbench-commands/wb/probe2.md.tpl"
run "a renamed source file shows the copy as stale" 0 "behind their source" env WORKBENCH_SKILL_SRC="$TMP/src/workbench" "$WB" status
ln -s SKILL.md "$TMP/src/workbench-commands/wb/link.md"
run "init refuses a symlink in a source" 1 "is a symlink" env WORKBENCH_SKILL_SRC="$TMP/src/workbench" "$WB" init
rm "$TMP/src/workbench-commands/wb/link.md"

# adopt on a symlinked CLAUDE.md edits the target, not the link
new_repo adopt
mkdir -p docs && echo '# adopt' > docs/CLAUDE.md && ln -s docs/CLAUDE.md CLAUDE.md && git add -A && git commit -qm claude
run "adopt" 0 "/workbench-review adopt" "$WB" adopt
check "adopt keeps CLAUDE.md a symlink" [ -L CLAUDE.md ]
check "adopt writes the block through the link" grep -q 'workbench:start' docs/CLAUDE.md
run "adopt is idempotent" 0 "refreshed the workbench block" "$WB" adopt
check "the block is not duplicated" [ "$(grep -c 'workbench:start' docs/CLAUDE.md)" -eq 1 ]

# --- failure paths ----------------------------------------------------------

new_repo fail
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'

# dirty main
"$WB" new bug "one" >/dev/null 2>&1; "$WB" start b-001 >/dev/null 2>&1
( cd .worktrees/b-001-one && echo a >> README && git add -A && git commit -qm a )
echo dirty >> README
run "merge refuses a dirty main" 1 "uncommitted changes; the squash commit would absorb them" "$WB" merge b-001 "one"
git checkout -q README

# generic dirt beyond the item file
( cd .worktrees/b-001-one && echo more >> README )
run "merge names generic dirt generically" 1 "has uncommitted changes; commit or discard" "$WB" merge b-001 "one"
( cd .worktrees/b-001-one && git checkout -q README )

# the item file plus a stray .md: not the item-only case
( cd .worktrees/b-001-one && git rm -q --cached workbench/items/bugs/b-001-one.md && git commit -qm untrack && echo n > notes.md )
run "merge with item file and a stray .md is generic" 1 "has uncommitted changes; commit or discard" "$WB" merge b-001 "one"
( cd .worktrees/b-001-one && rm notes.md && git add -A && git commit -qm retrack )

# conflicting branch
echo b >> README && git commit -qam b
run "merge refuses a conflicting branch" 1 "conflicts with main" "$WB" merge b-001 "one"
check "conflict leaves main untouched" [ -z "$(git log --grep='^Item:' --format=%h)" ]

# unreproduced retire: nothing but the item on the branch
"$WB" new bug "ghost" >/dev/null 2>&1; "$WB" start b-002 >/dev/null 2>&1
set_status .worktrees/b-002-ghost/workbench/items/bugs/b-002-ghost.md unreproduced
run "archive retires an unreproduced branch" 0 "retired b-002-ghost" "$WB" archive b-002
check "retire removes the worktree" [ ! -e .worktrees/b-002-ghost ]
check "retire deletes the branch" [ -z "$(git branch --list b-002-ghost)" ]
check "retired item is archived on main" [ -f workbench/items/archive/b-002-ghost.md ]

# unreproduced retire refuses when the branch carries work
"$WB" new bug "notghost" >/dev/null 2>&1; "$WB" start b-003 >/dev/null 2>&1
( cd .worktrees/b-003-notghost && echo w > work.txt && git add -A && git commit -qm w )
set_status .worktrees/b-003-notghost/workbench/items/bugs/b-003-notghost.md unreproduced
run "archive refuses to retire a branch with work" 1 "carries work beyond the item file" "$WB" archive b-003

# duplicate ids
cp workbench/items/archive/b-002-ghost.md workbench/items/bugs/b-002-again.md
run "status flags duplicate ids" 0 "DUPLICATE IDS" "$WB" status
rm workbench/items/bugs/b-002-again.md

# --- lookups over every worktree --------------------------------------------
# A detached worktree with no workbench/, an item created in a sibling, a
# pre-merge before the item commit, a worktree removed by hand, and archive
# run from a sibling that inherited the merged copy.

new_repo roots
"$WB" init >/dev/null && git add -A && git commit -qm 'workbench init'
git worktree add -q --detach "$TMP/roots-plain" HEAD   # lacks workbench/ entirely
"$WB" new bug "one" >/dev/null 2>&1
run "status with a detached worktree present" 0 "b-001-one" "$WB" status
run "archive with a detached worktree present reports, not dies" 1 "no evidence recorded" "$WB" archive b-001
"$WB" start b-001 >/dev/null 2>&1
ids=$(cd .worktrees/b-001-one && "$WB" new bug "from sibling" 2>/dev/null)
run "start finds an item created in another worktree" 0 "moved .* onto the branch" "$WB" start "$ids"
check "the sibling's copy moved, not copied" [ ! -e ".worktrees/b-001-one/workbench/items/bugs/$ids-from-sibling.md" ]

report=$("$WB" review pre-merge b-001 2>/dev/null)
check "pre-merge on a branch with no commits says so" grep -q 'b-001-one carries no commits beyond main' "$report"
"$WB" review-drop "$report" >/dev/null 2>&1

( cd .worktrees/b-001-one && git add -A && git commit -qm item )
rm -rf .worktrees/b-001-one
run "status survives a worktree removed by hand" 0 "b-001-one" "$WB" status
run "merge names the unpruned worktree" 1 "git worktree prune" "$WB" merge b-001 "one"
git worktree prune
echo diverge >> README && git commit -qam diverge
run "merge after prune" 0 "merged b-001" "$WB" merge b-001 "one"
( cd ".worktrees/$ids-from-sibling" && git add -A && git commit -qm item )
echo diverge >> README && git commit -qam diverge2
out=$("$WB" merge "$ids" "two" 2>&1)
check "merge prints nothing of git's own on success" [ "$(grep -c 'Automatic merge' <<< "$out")" -eq 0 ]

# archive from a sibling worktree: main's copy is the item's home
fill_evidence workbench/items/bugs/b-001-one.md "run" "ok"
idy=$("$WB" new bug "sibling" 2>/dev/null); "$WB" start "$idy" >/dev/null 2>&1
check "setup: the sibling inherited b-001's merged copy" [ -f ".worktrees/$idy-sibling/workbench/items/bugs/b-001-one.md" ]
check "find from a sibling lists a merged item once" [ "$(cd ".worktrees/$idy-sibling" && "$WB" find --grep 'crash\|one' 2>/dev/null | grep -c '^b-001 ')" -eq 1 ]
run "archive from a sibling worktree archives main's copy" 0 "git -C $PWD add" bash -c "cd .worktrees/$idy-sibling && '$WB' archive b-001"
check "main's copy is in the archive" [ -f workbench/items/archive/b-001-one.md ]
check "the sibling's copy is untouched" [ -f ".worktrees/$idy-sibling/workbench/items/bugs/b-001-one.md" ]
run "status labels main's archived copy" 0 "b-001-one +archived +\[in roots\]" "$WB" status
run "status labels the sibling's stale open copy" 0 "b-001-one +open +\[in $idy-sibling\]" "$WB" status
run "find --grep from a sibling lists an archived item once, as archived" 0 "^b-001 .*archived" \
  bash -c "cd .worktrees/$idy-sibling && '$WB' find --grep one | grep -c '^b-001 ' | grep -qx 1 && '$WB' find --grep one"
run "find by path from a sibling picks the archived copy" 0 "^b-001 .*archived" \
  bash -c "cd .worktrees/$idy-sibling && '$WB' find workbench/items/bugs/b-001-one.md | grep -c '^b-001 ' | grep -qx 1 && '$WB' find workbench/items/bugs/b-001-one.md"

# --- worktree cut before the init commit ------------------------------------

new_repo early
"$WB" init >/dev/null           # left uncommitted: main has no workbench/
"$WB" new bug "early" >/dev/null 2>&1
run "start notes an uncommitted .claude" 0 "lacks the workbench commands" "$WB" start b-001
[ ! -d .worktrees/b-001-early/workbench/reviews ] || fail "setup: reviews/ unexpectedly present"
report=$("$WB" review pre-merge b-001 2>/dev/null) || true
check "review pre-merge creates reviews/ when the branch lacks it" [ -f "$report" ]
"$WB" review-drop "$report" >/dev/null 2>&1
# The worktree's whole workbench/ is untracked here; the item must still be
# seen as the one file it is, not as the directory.
set_status .worktrees/b-001-early/workbench/items/bugs/b-001-early.md unreproduced
run "archive retires a branch whose workbench/ is untracked" 0 "retired b-001-early" "$WB" archive b-001

echo
echo "$checks checks, $fails failed"
[ "$fails" -eq 0 ]
