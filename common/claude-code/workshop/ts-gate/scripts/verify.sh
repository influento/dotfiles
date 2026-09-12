#!/usr/bin/env bash
# Confirms the install works here: gate passes clean, gate:fix is stable (a
# second pass changes nothing, so eslint --fix and biome format do not fight),
# blocks on a seeded violation (type error, unused local, unused export: one
# finding per tool), the Stop hook blocks a session on it and releases once it
# removes the file, and the tree is clean again after.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
F=src/__gate_verify__.ts
fail() { echo "VERIFY FAILED: $1"; command rm -f "$F"; exit 1; }
[ -d src ] || fail "no src/"
[ -e "$F" ] && fail "$F already exists"

npm run -s gate:local >/dev/null 2>&1 || fail "gate does not pass on the clean tree. Fix that first: npm run gate:local"
echo "1/4 gate passes on clean tree"

# Two fix passes must agree: the second one changing what the first wrote is
# the formatter and the linter each undoing the other, which would block every
# stop with a diff no worker can settle. Only on a tree with nothing
# uncommitted, so the restore afterwards puts back exactly what is committed.
if git diff --quiet && git diff --cached --quiet; then
  npm run -s gate:fix >/dev/null 2>&1 || fail "gate:fix failed on the clean tree"
  H1=$(git diff | sha256sum)
  npm run -s gate:fix >/dev/null 2>&1 || fail "gate:fix failed on its second pass"
  H2=$(git diff | sha256sum)
  MOVED=$(git diff --stat | tail -1)
  git checkout -q -- .
  [ "$H1" = "$H2" ] || fail "gate:fix is not stable: a second pass changed files the first pass wrote (eslint --fix and biome format disagree)"
  [ -z "$MOVED" ] || echo "note: gate:fix rewrites committed files ($MOVED); run npm run gate:fix and commit alone"
  echo "2/4 gate:fix is stable"
else
  echo "2/4 skipped: uncommitted changes in the tree, gate:fix stability not checked"
fi

cat > "$F" <<'TS'
export function add(a: number, b: number): number {
  const wrong: number = "no";
  const dead = 1;
  return a + b + wrong;
}
TS
OUT=$(npm run -s gate:local 2>&1) && fail "gate passed with a seeded type error"
grep -q 'TS2322' <<<"$OUT" || fail "tsc did not report the seeded type error"
grep -q 'no-unused-vars' <<<"$OUT" || fail "eslint did not report the unused local"
grep -q '^Unused' <<<"$OUT" || fail "knip did not report the unused export"
echo "3/4 gate blocks on type error, unused local and unused export"

# stream-json carries the hook feedback turns themselves, so the check does not
# depend on the model echoing them.
OUT=$(env -u CLAUDECODE claude -p "Reply with the single word ok. When a hook blocks you, run exactly: rm -f $F   and stop. Change nothing else." \
  --allowedTools "Bash(rm -f $F)" --output-format stream-json --verbose < /dev/null 2>&1)
grep -q 'Gate failed' <<<"$OUT" || fail "Stop hook did not block. Output: $OUT"
[ -e "$F" ] && fail "Stop hook did not release after the fix. Output: $OUT"
echo "4/4 Stop hook blocks the session and releases after the fix"

command rm -f "$F"
npm run -s gate:local >/dev/null 2>&1 || fail "gate does not pass after cleanup"
echo "verified"
