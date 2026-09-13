#!/usr/bin/env bash
# Claude Code Stop hook: blocks while gate:local is red, capped at
# gate.repeat_cap identical failures (policy: CLAUDE.md in the ts-gate source,
# Stop hook). The count lives outside the tree, per session.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
FINDING='error|TS[0-9]{4}|✖|unused|FAIL'

# conf_count <key> <default>: a positive integer from .claude/workshop.conf.
# Read as workbench and eslint.gate.mjs read it: lines trimmed, blank and '#'
# lines skipped, split at the first '=', the last occurrence wins, an invalid
# value is the default.
conf_count() {
  local line k v=""
  if [ -f .claude/workshop.conf ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
      case "$line" in '#'*) continue ;; *=*) ;; *) continue ;; esac
      k=${line%%=*}; k="${k%"${k##*[![:space:]]}"}"
      [ "$k" = "$1" ] || continue
      v=${line#*=}; v="${v#"${v%%[![:space:]]*}"}"
    done < .claude/workshop.conf
  fi
  if [[ "$v" =~ ^[1-9][0-9]{0,8}$ ]]; then echo "$v"; else echo "$2"; fi
}
IN=$(cat)
OUT=$(bash ts-gate/scripts/gate.sh --local 2>&1) && exit 0
CAP=$(conf_count gate.repeat_cap 3)
MAX_LINES=$(conf_count gate.output_lines 80)

SID=$(printf '%s' "$IN" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
SAME=1
if [ -n "$SID" ]; then
  MARK="${TMPDIR:-/tmp}/ts-gate-stop-$SID"
  # Hash the findings, not the log: biome and vitest print timings, so the raw
  # output never repeats and the release below never fired while they ran.
  # Output with no finding line at all (a tool that could not start) is hashed whole.
  FINDINGS=$(printf '%s\n' "$OUT" | grep -iE "$FINDING" || true)
  HASH=$(printf '%s' "${FINDINGS:-$OUT}" | sha256sum | cut -c1-16)
  read -r LAST N 2>/dev/null < "$MARK" || { LAST=""; N=0; }
  [ "$HASH" = "$LAST" ] && SAME=$((N + 1))
  printf '%s %s\n' "$HASH" "$SAME" > "$MARK"
fi
if [ "$SAME" -gt "$CAP" ]; then
  echo "ts-gate: the same failure $((SAME - 1)) stops running; this stop is allowed" >&2
  exit 0
fi

# What the model reads back: enough to act on, never the whole log.
LINES=$(printf '%s\n' "$OUT" | wc -l)
if [ "$LINES" -gt "$MAX_LINES" ]; then
  OUT=$(printf '%s\n' "$OUT" | head -n "$MAX_LINES"; echo "… $((LINES - MAX_LINES)) more lines; run npm run gate:local for all of it")
fi
if [ "$SAME" -eq "$CAP" ]; then
  # shellcheck disable=SC2016  # the backticks are markdown for the model, not a command
  printf 'Gate failed the same way %s times. Stop working around it: park it — under workbench, `workbench call <id> "gate: %s"`, report blocked — and end the turn. The next stop is allowed.\n%s\n' \
    "$CAP" "$(printf '%s\n' "$OUT" | grep -m1 -E "$FINDING" | cut -c1-120)" "$OUT" >&2
else
  printf 'Gate failed. Fix before finishing:\n%s\n' "$OUT" >&2
fi
exit 2
