#!/usr/bin/env bash
set -euo pipefail

# Prints the rules a sweep needs for its reason: the reason's own file from
# rules/, then the reference the reason audits against — docs.md for docs and
# memory, adopt.md plus docs.md for adopt. Whole files, never a section cut out
# by heading: the block this feeds is fail-closed, and a heading edit would
# abort the sweep silently.
#
# One script rather than a shell one-liner in the skill body, because the
# preprocessed block is permission-parsed per statement and a compound command
# there demands a separate approval for each part.

reason="${1:-}"
[ -n "$reason" ] || { echo "usage: rules.sh <reason>" >&2; exit 2; }

here="$(dirname "$(readlink -f "$0")")"
rules="$here/../rules"
# the workbench skill's references, one level up out of workbench-review/
refs="$here/../../workbench/references"

[ -f "$rules/$reason.md" ] || { echo "rules.sh: no rules for reason '$reason'" >&2; exit 2; }

cat "$rules/$reason.md"
case "$reason" in
  docs|memory)
    echo
    cat "$refs/docs.md" ;;
  adopt)
    echo
    cat "$refs/adopt.md"
    echo
    cat "$refs/docs.md" ;;
esac
