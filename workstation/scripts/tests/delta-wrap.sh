#!/usr/bin/env bash
# delta-wrap on a diff with long lines, through the real delta and the repo's
# delta settings. Skips where delta is not installed.
set -euo pipefail
WRAP=$(readlink -f "$(dirname "$0")/../delta-wrap")
DELTA_CONF=$(readlink -f "$(dirname "$0")/../../../common/delta/delta.gitconfig")
command -v delta >/dev/null || { echo "skip: no delta"; exit 0; }
[[ -f "$DELTA_CONF" ]] || { echo "skip: delta.gitconfig not rendered"; exit 0; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
checks=0 fails=0
check() { local label="$1"; shift; checks=$((checks + 1)); if "$@"; then echo "ok   $label"; else fails=$((fails + 1)); echo "FAIL $label"; fi; }

printf 'short\n- a list item with words that go on well past the width of a narrow pane\nunbrokenunbrokenunbrokenunbrokenunbrokenunbrokenunbrokenunbroken\n' > "$TMP/new.md"
: > "$TMP/old.md"
(cd "$TMP" && git -c "include.path=$DELTA_CONF" diff --no-index old.md new.md || true) > "$TMP/diff"
render() { GIT_CONFIG_GLOBAL="$DELTA_CONF" COLUMNS="$1" "$WRAP" --dark --paging=never < "$TMP/diff"; }
plain() { python3 -c 'import re,sys;sys.stdout.write(re.sub(r"\x1b\[[0-9;:?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)","",sys.stdin.read()))'; }
render 40 | plain > "$TMP/40"
rows() { grep -E '^[ 0-9]{4} │ ' "$TMP/40"; }

check "no numbered row is wider than the pane" [ "$(rows | awk '{ if (length($0) > 40) print }' | wc -l)" -eq 0 ]
check "a long line continues behind a blank gutter" grep -qE '^     │ ' "$TMP/40"
check "a list item's continuation hangs under its text" grep -qE '^     │   [a-z]' "$TMP/40"
check "the text survives the wrap" [ "$(rows | sed -E 's/^[ 0-9]{4} │ +(- )?//' | tr -d ' \n')" = "$(sed 's/^- //' "$TMP/new.md" | tr -d ' \n')" ]
check "no COLUMNS leaves delta's output as it was" [ "$(render '' | plain)" = "$(GIT_CONFIG_GLOBAL="$DELTA_CONF" delta --dark --paging=never < "$TMP/diff" | plain)" ]
check "a wide pane leaves delta's output as it was" [ "$(render 500 | plain)" = "$(COLUMNS=500 GIT_CONFIG_GLOBAL="$DELTA_CONF" delta --dark --paging=never < "$TMP/diff" | plain)" ]

echo "$((checks - fails))/$checks passed"
[ "$fails" -eq 0 ]
