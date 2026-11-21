#!/usr/bin/env bash
# terminal ($mod+Return) brings the tmux terminal to the focused workspace,
# from wherever it is, and opens Ghostty only when there is none. A Ghostty
# window that runs nvim is not the terminal.
# Fakes on PATH: swaymsg (get_tree from FAKE_TREE, commands recorded) and
# ghostty (records that it ran). Nothing touches the real session.
# Plain bash, no framework. Run from workstation/scripts: bash tests/terminal.sh
set -euo pipefail

TERMINAL=$(readlink -f "$(dirname "$0")/../terminal")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export PATH="$TMP/bin:$PATH" LOG="$TMP/log"

cat >"$TMP/bin/swaymsg" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -t ]]; then cat "$FAKE_TREE"; exit 0; fi
[[ "$1" == -q ]] && shift
echo "swaymsg $*" >>"$LOG"
EOF
cat >"$TMP/bin/ghostty" <<'EOF'
#!/usr/bin/env bash
echo "ghostty $*" >>"$LOG"
EOF
chmod +x "$TMP/bin/"*

# A tree: workspace 1 focused on HDMI-A-1, "~park-5" on HEADLESS-2, and the
# scratchpad. $1..$3: the windows on each, as JSON arrays.
tree() {
  cat >"$TMP/tree.json" <<EOF
{"type": "root", "nodes": [
  {"type": "output", "name": "__i3", "nodes": [
    {"type": "workspace", "name": "__i3_scratch", "nodes": [], "floating_nodes": $3}]},
  {"type": "output", "name": "HDMI-A-1", "nodes": [
    {"type": "workspace", "name": "1", "nodes": $1, "floating_nodes": []}]},
  {"type": "output", "name": "HEADLESS-2", "nodes": [
    {"type": "workspace", "name": "~park-5", "nodes": $2, "floating_nodes": []}]}
]}
EOF
  export FAKE_TREE="$TMP/tree.json"
}
win() { printf '{"id": %s, "app_id": "%s", "name": "%s", "focused": %s, "nodes": []}' "$@"; }

fail=0
check() {
  : >"$LOG"
  bash "$TERMINAL"
  if [[ "$(cat "$LOG")" == "$2" ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    printf '     expected: %s\n     got:      %s\n' "$2" "$(cat "$LOG")"
    fail=1
  fi
}

ghostty=com.mitchellh.ghostty
move() { echo "swaymsg [con_id=$1] move container to workspace current, focus"; }

tree "[$(win 10 firefox Firefox true)]" "[]" "[]"
check "no terminal: opens Ghostty" "ghostty "

tree "[$(win 10 "$ghostty" Ghostty true)]" "[$(win 20 "$ghostty" tmux false)]" "[]"
check "terminal on a parked headless workspace: brought here, not nvim's window" "$(move 20)"

tree "[$(win 10 "$ghostty" tmux true)]" "[]" "[$(win 30 "$ghostty" tmux false)]"
check "a terminal here wins over one elsewhere, listed first" "$(move 10)"

tree "[$(win 10 firefox Firefox true)]" "[]" "[$(win 30 "$ghostty" tmux false)]"
check "terminal in the scratchpad: brought here" "$(move 30)"

tree "[]" "[]" "[]"
sed -i 's/"name": "1", "nodes": \[\]/"name": "1", "focused": true, "nodes": []/' "$TMP/tree.json"
check "empty focused workspace, no terminal: opens Ghostty" "ghostty "

exit "$fail"
