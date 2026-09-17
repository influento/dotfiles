#!/usr/bin/env bash
# lib/reminders.sh — Pending post-install reminders
#
# reminders/<name>.txt holds one reminder per line. `key:message` is pending
# until `key` appears in the state file (one key per line); a line without a
# colon is always pending. The split is on the first colon.
#
# Shared by install.sh (log_warn lines at the end of a deploy) and
# workstation/scripts/startup-reminders (desktop notifications on sway start).
# Keep it free of lib/log.sh so the script can source it on its own.

# Print the message of every pending reminder, one per line.
# Usage: pending_reminders "/path/to/state/completed" reminders/common.txt [reminders/workstation.txt ...]
pending_reminders() {
  local state_file="$1"
  shift

  local completed=""
  if [[ -f "$state_file" ]]; then
    completed="$(cat "$state_file")"
  fi

  local file line key msg
  for file in "$@"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue

      if [[ "$line" == *:* ]]; then
        key="${line%%:*}"
        msg="${line#*:}"
        if grep -qxF "$key" <<<"$completed"; then
          continue
        fi
      else
        msg="$line"
      fi

      printf '%s\n' "$msg"
    done < "$file"
  done
}
