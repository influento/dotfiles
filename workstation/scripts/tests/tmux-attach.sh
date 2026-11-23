#!/usr/bin/env bash
# tmux-attach: a broken tmux leaves a usable terminal.
#   - a failed attach (tmux-revive or plain tmux) execs a login shell and says why
#   - exit 0 (a detach, the last session ending) closes the window: no shell
# Fakes on PATH: tmux-revive and tmux exit with $FAKE_RC; SHELL is a fake that
# records how it was started. Nothing touches the real tmux server.
# Plain bash, no framework. Run from workstation/scripts: bash tests/tmux-attach.sh
# shellcheck disable=SC2016  # each check is a string that check() evals
set -euo pipefail

ATTACH=$(readlink -f "$(dirname "$0")/../tmux-attach")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/with" "$TMP/without"

for name in tmux-revive tmux; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"$TMP_LOG"\nexit "${FAKE_RC:-0}"\n' "$name" \
    >"$TMP/with/$name"
done
cp "$TMP/with/tmux" "$TMP/without/tmux"
printf '#!/usr/bin/env bash\necho "shell $*" >>"$TMP_LOG"\n' >"$TMP/shell"
chmod +x "$TMP/with/"* "$TMP/without/"* "$TMP/shell"

fail=0
check() {
  if eval "$2"; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    sed 's/^/     /' "$TMP/log" "$TMP/err"
    fail=1
  fi
}

# run <with|without tmux-revive> <exit code of the fakes>
run() {
  : >"$TMP/log"
  env PATH="$TMP/$1:/usr/bin:/bin" SHELL="$TMP/shell" TMP_LOG="$TMP/log" FAKE_RC="$2" \
    bash "$ATTACH" >/dev/null 2>"$TMP/err" || true
}

run with 0
check "tmux-revive attaches" 'grep -qx "tmux-revive attach" "$TMP/log"'
check "a detach closes the window, no shell" '! grep -q "^shell" "$TMP/log"'

run with 1
check "tmux-revive fails: a login shell in the same window" 'grep -qx "shell -l" "$TMP/log"'
check "tmux-revive fails: it says why" 'grep -q "tmux-revive attach failed (exit 1)" "$TMP/err"'

run without 0
check "no tmux-revive: plain tmux" 'grep -qx "tmux new-session -A -s main" "$TMP/log" && ! grep -q "^shell" "$TMP/log"'

run without 1
check "no tmux-revive, tmux fails: a login shell" 'grep -qx "shell -l" "$TMP/log" && grep -q "tmux failed" "$TMP/err"'

exit "$fail"
