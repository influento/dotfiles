#!/usr/bin/env bash
# End-to-end tests for common/scripts/workbench, run in a throwaway repository.
# Plain bash, no framework: each check is an exit code and a grep on output.
# Run: bash tests/workbench.sh
set -euo pipefail

WB=$(readlink -f "$(dirname "$0")/../common/scripts/workbench")
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
git add -A && git commit -qm 'workbench init'

id=$("$WB" new bug "crash on save" 2>/dev/null)
check "new allocates b-001" [ "$id" = b-001 ]
item=workbench/items/bugs/b-001-crash-on-save.md
check "new writes the item file" [ -f "$item" ]

run "start" 0 "moved $item onto the branch" "$WB" start b-001
wt=.worktrees/b-001-crash-on-save
check "start moves the item into the worktree" [ -f "$wt/$item" ]
check "start leaves no copy on main" [ ! -e "$item" ]

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

run "status" 0 "" "$WB" status

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

# --- worktree cut before the init commit ------------------------------------

new_repo early
"$WB" init >/dev/null           # left uncommitted: main has no workbench/
"$WB" new bug "early" >/dev/null 2>&1
"$WB" start b-001 >/dev/null 2>&1
[ ! -d .worktrees/b-001-early/workbench/reviews ] || fail "setup: reviews/ unexpectedly present"
report=$("$WB" review pre-merge b-001 2>/dev/null) || true
check "review pre-merge creates reviews/ when the branch lacks it" [ -f "$report" ]

echo
echo "$checks checks, $fails failed"
[ "$fails" -eq 0 ]
