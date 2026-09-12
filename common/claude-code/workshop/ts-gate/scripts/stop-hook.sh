#!/usr/bin/env bash
# Claude Code Stop hook: the model cannot declare "done" while the local gate fails.
# The gate is deterministic, so blocking again while it is red is correct — up
# to a point. The same failure three stops running is a fight the model is not
# winning, and every further block re-runs a full turn over the whole context
# to lose it again. So: identical output three times → one last block that says
# to park it and stop → the next stop is allowed. A failure that changes resets
# the count: that is progress. The count lives outside the tree, per session.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
IN=$(cat)
OUT=$(bash ts-gate/scripts/gate.sh --local 2>&1) && exit 0

SID=$(printf '%s' "$IN" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
SAME=1
if [ -n "$SID" ]; then
  MARK="${TMPDIR:-/tmp}/ts-gate-stop-$SID"
  HASH=$(printf '%s' "$OUT" | sha256sum | cut -c1-16)
  read -r LAST N 2>/dev/null < "$MARK" || { LAST=""; N=0; }
  [ "$HASH" = "$LAST" ] && SAME=$((N + 1))
  printf '%s %s\n' "$HASH" "$SAME" > "$MARK"
fi
if [ "$SAME" -gt 3 ]; then
  echo "ts-gate: the same failure $((SAME - 1)) stops running; this stop is allowed" >&2
  exit 0
fi

# What the model reads back: enough to act on, never the whole log.
LINES=$(printf '%s\n' "$OUT" | wc -l)
if [ "$LINES" -gt 80 ]; then
  OUT=$(printf '%s\n' "$OUT" | head -n 80; echo "… $((LINES - 80)) more lines; run npm run gate:local for all of it")
fi
if [ "$SAME" -eq 3 ]; then
  # shellcheck disable=SC2016  # the backticks are markdown for the model, not a command
  printf 'Gate failed the same way three times. Stop working around it: park it — under workbench, `workbench call <id> "gate: %s"`, report blocked — and end the turn. The next stop is allowed.\n%s\n' \
    "$(printf '%s\n' "$OUT" | grep -m1 -E 'error|TS[0-9]{4}|✖|unused|FAIL' | cut -c1-120)" "$OUT" >&2
else
  printf 'Gate failed. Fix before finishing:\n%s\n' "$OUT" >&2
fi
exit 2
