#!/usr/bin/env bash
set -euo pipefail

# Prints the workbench rules a sweep needs for its reason: reviews.md always,
# plus docs.md or adopt.md when the reason is one of those.
#
# One script rather than a shell one-liner in the skill body, because the
# preprocessed block is permission-parsed per statement and a compound command
# there demands a separate approval for each part.

reason="${1:-}"
[ -n "$reason" ] || { echo "usage: rules.sh <reason>" >&2; exit 2; }

refs="$(dirname "$(readlink -f "$0")")/../../workbench/references"

cat "$refs/reviews.md"
case "$reason" in
  docs|adopt)
    echo
    cat "$refs/$reason.md" ;;
esac
