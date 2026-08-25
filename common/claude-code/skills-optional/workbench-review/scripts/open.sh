#!/usr/bin/env bash
# Opens the report for the preprocessed block in SKILL.md. That block is
# fail-closed — a non-zero exit aborts the skill with no output at all — so a
# refusal from 'workbench review' (bad slug, no contract, no workbench/) would
# vanish with the sweep. Stderr folds into stdout and the exit is always 0:
# the fork reads a path or the reason there is none, and SKILL.md tells it to
# stop on anything that is not a path. A missing 'workbench' prints the shell's
# error the same way.
# no -e: a refusal from workbench must reach stdout, not abort the block.
set -uo pipefail
exec 2>&1
workbench review "$@"
exit 0
