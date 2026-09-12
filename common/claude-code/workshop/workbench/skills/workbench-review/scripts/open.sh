#!/usr/bin/env bash
# Opens the report for the preprocessed block in SKILL.md. That block is
# fail-closed — a non-zero exit aborts the skill with no output at all — so a
# refusal from 'workbench review' (bad slug, no contract, no workbench/) would
# vanish with the sweep. The exit is always 0, and the fork gets exactly one
# of the two streams: stdout when the open succeeded, which is the path alone,
# stderr when it did not, which is the reason. Kept apart so that a warning
# on stderr can never precede the path — SKILL.md tests "starts with
# workbench:", and this is what makes that test hold. A missing 'workbench'
# lands on stderr the same way.
# no -e: a refusal from workbench must reach stdout, not abort the block.
set -uo pipefail
err=$(mktemp)
trap 'rm -f "$err"' EXIT
if out=$(workbench review "$@" 2>"$err"); then
  printf '%s\n' "$out"
else
  cat "$err"
fi
exit 0
