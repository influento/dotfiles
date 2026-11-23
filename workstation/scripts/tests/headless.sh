#!/usr/bin/env bash
# headless at the desk: coming back to a headless session must bring the
# monitor back, or say why not, without losing the session.
#   - toggle on the lock screen turns headless mode off, never on
#   - off with no monitor in sway's list (it drops out while another VT is
#     active) keeps the virtual output, its workspaces and wayvnc, and says to
#     switch to tty1
#   - off brings a monitor back lit, even after swayidle's dpms off
#   - dpms off leaves a disabled output's power alone, so it is not dark when
#     enabled again (headless off, lid open)
# Fakes on PATH: swaymsg (outputs and workspaces in files; config for an
# output sway does not list is ignored, as sway keeps it until it appears),
# systemctl (wayvnc active while a file exists), systemd-run (marks that a
# unit was started), pgrep (swaylock running when FAKE_LOCKED=1), nosleep and
# notify-send. Nothing touches the real session.
# Plain bash, no framework. Run from workstation/scripts: bash tests/headless.sh
# shellcheck disable=SC2016,SC2034,SC2329  # each check is a string that check() evals
set -euo pipefail

HEADLESS=$(readlink -f "$(dirname "$0")/../headless")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export PATH="$TMP/bin:$PATH"

# Outputs: "name active power" per line. Workspaces: "name output".
cat >"$TMP/bin/swaymsg" <<'EOF'
#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2329  # each check is a string that check() evals
set -euo pipefail
R="$XDG_RUNTIME_DIR"
if [[ "$1" == -t ]]; then
  case "$2" in
    get_outputs) python3 -c '
import json, sys
rows = [l.split() for l in open(sys.argv[1]) if l.strip()]
print(json.dumps([{"name": n, "active": a == "1", "power": p == "1"} for n, a, p in rows]))
' "$R/outputs" ;;
    get_workspaces) python3 -c '
import json, sys
rows = [l.split() for l in open(sys.argv[1]) if l.strip()]
print(json.dumps([{"name": n, "output": o, "focused": False} for n, o in rows]))
' "$R/ws" ;;
  esac
  exit 0
fi
[[ "$1" == -q ]] && shift
cmd="$*"
if [[ "$cmd" =~ ^workspace\ \"(.*)\"$ ]]; then
  echo "${BASH_REMATCH[1]}" >"$R/focused"
elif [[ "$cmd" =~ ^move\ workspace\ to\ output\ \"(.*)\"$ ]]; then
  target="${BASH_REMATCH[1]}"
  grep -q "^${target} 1 " "$R/outputs" || exit 1
  sed -i "s/^$(cat "$R/focused") .*/$(cat "$R/focused") ${target}/" "$R/ws"
elif [[ "$cmd" == create_output ]]; then
  echo "HEADLESS-37 1 1" >>"$R/outputs"
elif [[ "$cmd" =~ ^output\ \"?([^\"\ ]+)\"?\ (.*)$ ]]; then
  name="${BASH_REMATCH[1]}"
  rest="${BASH_REMATCH[2]}"
  grep -q "^${name} " "$R/outputs" || exit 0
  if [[ "$rest" == unplug ]]; then
    sed -i "/^${name} /d" "$R/outputs"
    exit 0
  fi
  [[ "$rest" == *disable* ]] && sed -i "s/^${name} [01] /${name} 0 /" "$R/outputs"
  [[ "$rest" =~ (^|\ )enable ]] && sed -i "s/^${name} [01] /${name} 1 /" "$R/outputs"
  [[ "$rest" == *"power on"* ]] && sed -i "s/^\(${name} [01]\) [01]/\1 1/" "$R/outputs"
  [[ "$rest" == *"power off"* ]] && sed -i "s/^\(${name} [01]\) [01]/\1 0/" "$R/outputs"
fi
exit 0
EOF

cat >"$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
R="$XDG_RUNTIME_DIR"
case "$*" in
  *is-active*nosleep*) exit 3 ;;
  *is-active*wayvnc*) [[ -e "$R/wayvnc-active" ]] ;;
  *stop\ wayvnc) rm -f "$R/wayvnc-active" ;;
  *) exit 0 ;;
esac
EOF

cat >"$TMP/bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
: >"$XDG_RUNTIME_DIR/unit-started"
exit 1
EOF

cat >"$TMP/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ "${FAKE_LOCKED:-0}" == 1 ]]
EOF

printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/nosleep"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/notify-send"
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/bin/wayvncctl"
chmod +x "$TMP/bin/"*

fail=0
: >"$TMP/err"
check() {
  if eval "$2"; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    sed 's/^/     /' "$TMP/err"
    fail=1
  fi
}

# A headless session as `headless on` leaves it: workspaces 1 and 4 moved from
# HDMI-A-1 to this script's HEADLESS-36, 9 on another tool's HEADLESS-2,
# wayvnc serving. $1 is the monitor's line in sway's list, or empty when sway
# has lost it.
headless_session() {
  R="$TMP/run"
  rm -rf "$R"
  mkdir -m700 "$R"
  python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$R/sway-ipc.0.sock"
  echo HEADLESS-36 >"$R/headless.output"
  printf '1 HDMI-A-1\n4 HDMI-A-1\n9 HEADLESS-2\n' >"$R/headless.workspaces"
  echo 1 >"$R/headless.focus"
  { [[ -z "$1" ]] || echo "$1"; printf 'HEADLESS-2 1 1\nHEADLESS-36 1 1\n'; } >"$R/outputs"
  printf '1 HEADLESS-36\n4 HEADLESS-36\n9 HEADLESS-2\n' >"$R/ws"
  : >"$R/wayvnc-active"
}

run() {
  status=0
  env -u SWAYSOCK XDG_RUNTIME_DIR="$R" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
    bash "$HEADLESS" "$@" >"$TMP/out" 2>"$TMP/err" || status=$?
}

ws_on() { grep -qx "$1 $2" "$R/ws"; }
output_is() { grep -qx "$1" "$R/outputs"; }

# The socket path must stay short: AF_UNIX allows ~108 bytes.
if ((${#TMP} > 80)); then
  echo "TMPDIR gives too long a path for a socket: $TMP" >&2
  exit 1
fi

# --- toggle on the lock screen
config="$(dirname "$HEADLESS")/../sway/config.tpl"
check "the toggle key works on the lock screen" \
  'grep -Eq "^bindsym (--[a-z-]+ )*--locked (--[a-z-]+ )*\\\$mod\+Shift\+o exec ~/.local/bin/headless toggle$" "$config"'

headless_session "HDMI-A-1 1 1"
rm -f "$R/headless.output" "$R/wayvnc-active"
printf '1 HDMI-A-1\n4 HDMI-A-1\n9 HEADLESS-2\n' >"$R/ws"
FAKE_LOCKED=1 run toggle
check "locked toggle does not turn headless mode on" \
  '[[ $status -ne 0 && ! -e "$R/unit-started" ]] && output_is "HDMI-A-1 1 1" && ws_on 1 HDMI-A-1'
check "locked toggle says why" 'grep -q locked "$TMP/err"'

headless_session "HDMI-A-1 0 1"
FAKE_LOCKED=1 run toggle
check "locked toggle turns headless mode off" \
  '[[ $status -eq 0 ]] && output_is "HDMI-A-1 1 1" && ws_on 1 HDMI-A-1 && ! grep -q HEADLESS-36 "$R/outputs"'

# --- off with the monitor gone from sway's list
headless_session ""
run off
check "off with no monitor keeps the session served" \
  '[[ $status -ne 0 && -e "$R/wayvnc-active" ]] && output_is "HEADLESS-36 1 1" && ws_on 1 HEADLESS-36 && ws_on 4 HEADLESS-36'
check "off with no monitor says to switch to tty1" \
  'grep -q tty1 "$TMP/err" && ! grep -q "unbound variable" "$TMP/err"'

# --- off after swayidle's dpms off
headless_session "HDMI-A-1 0 0"
run off
check "off brings a powered-off monitor back lit" \
  '[[ $status -eq 0 ]] && output_is "HDMI-A-1 1 1" && ws_on 1 HDMI-A-1 && ws_on 4 HDMI-A-1 && ws_on 9 HEADLESS-2'

# --- dpms
headless_session "HDMI-A-1 0 1"
run dpms off
check "dpms off leaves a disabled monitor's power alone" 'output_is "HDMI-A-1 0 1"'

headless_session "HDMI-A-1 1 1"
run dpms off
check "dpms off powers off an active monitor" 'output_is "HDMI-A-1 1 0" && output_is "HEADLESS-36 1 1"'

# --- bound workspace with a view-only marker
# serve runs with the sway and wayvnc lookups stubbed, systemd-run logging its
# arguments. A view-only stream takes no input, says so in the unit
# Description (what restream compares), and show leaves the host's focus off
# the workspace.
serve() {
  (
    export XDG_RUNTIME_DIR="$R"
    # shellcheck source=/dev/null
    source <(sed '/^main "\$@"$/d' "$HEADLESS")
    ensure_swaysock() { :; }
    is_active() { true; }
    headless_bindable() { printf '9\tHEADLESS-2\tapp\n'; }
    served_output() { [[ -e "$R/run-args" ]] && echo HEADLESS-2; }
    systemctl() { [[ "$*" != *is-active* ]] || [[ -e "$R/run-args" ]]; }
    systemd-run() { printf '%s\n' "$@" >"$R/run-args"; }
    swaymsg() { echo "$*" >>"$R/sway-cmds"; }
    "$@"
  ) >"$TMP/out" 2>"$TMP/err"
}

headless_session "HDMI-A-1 1 1"
serve headless_serve 9 both
check "a bound workspace without a marker takes input" \
  '! grep -qx -- --disable-input "$R/run-args" && grep -q "input on)" "$R/run-args"'

headless_session "HDMI-A-1 1 1"
mkdir -p "$R/view-only" && echo "test: view-only" >"$R/view-only/9"
serve headless_serve 9 both
check "a view-only workspace's stream takes no input" \
  'grep -qx -- --disable-input "$R/run-args" && grep -q "view only)" "$R/run-args"'
serve headless_show 9 both
check "show leaves the host's focus off a view-only workspace" '[[ ! -e "$R/sway-cmds" ]]'

exit "$fail"
