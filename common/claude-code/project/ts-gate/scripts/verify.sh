#!/usr/bin/env bash
# Confirms the install works here: gate passes clean, blocks on a seeded violation
# (type error, unused export), the Stop hook blocks a session on it and releases
# once it removes the file, and the tree is clean again after.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
F=src/__gate_verify__.ts
fail() { echo "VERIFY FAILED: $1"; command rm -f "$F"; exit 1; }
[ -d src ] || fail "no src/"
[ -e "$F" ] && fail "$F already exists"

npm run -s gate:local >/dev/null 2>&1 || fail "gate does not pass on the clean tree. Fix that first: npm run gate:local"
echo "1/3 gate passes on clean tree"

cat > "$F" <<'TS'
export function add(a: number, b: number): number {
  const wrong: number = "no";
  return a + b + wrong;
}
TS
OUT=$(npm run -s gate:local 2>&1) && fail "gate passed with a seeded type error"
grep -q 'TS2322' <<<"$OUT" || fail "tsc did not report the seeded type error"
grep -qi 'unused' <<<"$OUT" || fail "knip/eslint did not report the unused export"
echo "2/3 gate blocks on type error and unused export"

# stream-json carries the hook feedback turns themselves, so the check does not
# depend on the model echoing them.
OUT=$(env -u CLAUDECODE claude -p "Reply with the single word ok. When a hook blocks you, run exactly: rm -f $F   and stop. Change nothing else." \
  --allowedTools "Bash(rm -f $F)" --output-format stream-json --verbose < /dev/null 2>&1)
grep -q 'Gate failed' <<<"$OUT" || fail "Stop hook did not block. Output: $OUT"
[ -e "$F" ] && fail "Stop hook did not release after the fix. Output: $OUT"
echo "3/3 Stop hook blocks the session and releases after the fix"

command rm -f "$F"
npm run -s gate:local >/dev/null 2>&1 || fail "gate does not pass after cleanup"
echo "verified"
