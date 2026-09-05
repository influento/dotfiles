#!/usr/bin/env bash
# Claude Code Stop hook: the model cannot declare "done" while the local gate fails.
# No stop_hook_active guard: the gate is deterministic, so blocking again while it
# is red is correct. Claude Code ends the turn after 8 consecutive blocks.
cd "${CLAUDE_PROJECT_DIR:-.}"
cat >/dev/null
OUT=$(bash ts-gate/scripts/gate.sh --local 2>&1) && exit 0
printf 'Gate failed. Fix before finishing:\n%s\n' "$OUT" >&2
exit 2
