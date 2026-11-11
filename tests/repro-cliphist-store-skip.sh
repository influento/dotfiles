#!/usr/bin/env bash
# cliphist-store offers a copy back through launcher-clipboard --offer only
# when cliphist stored it. cliphist 0.7.0 drops input over 5,000,000 bytes and
# empty or whitespace-only input without a word, and then the newest entry is
# an older copy, which must not go up in place of this one.
# Fakes on PATH: cliphist (stores to a temp dir, each stored input, a dedup
# too, gets a new higher id; drops input over FAKE_LIMIT bytes or blank),
# wl-paste (types and image from files) and launcher-clipboard (records its
# arguments). Nothing touches the real clipboard or history.
# Plain bash, no framework. Run: bash tests/repro-cliphist-store-skip.sh
set -euo pipefail

REPO=$(readlink -f "$(dirname "$0")/..")
STORE="${REPO}/workstation/scripts/cliphist-store"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export FAKE="$TMP/state" FAKE_LIMIT=100
export PATH="$TMP/bin:$PATH"

cat >"$TMP/bin/cliphist" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd=
for arg in "$@"; do
  case "$arg" in store | list) cmd=$arg ;; esac
done
case "$cmd" in
  store)
    in="$FAKE/in"
    cat >"$in"
    size=$(stat -c %s "$in")
    if ((size > FAKE_LIMIT)) || ! grep -q '[^[:space:]]' "$in"; then
      exit 0
    fi
    for entry in "$FAKE"/entries/*; do
      if [[ -e "$entry" ]] && cmp -s "$entry" "$in"; then rm -f "$entry"; fi
    done
    next=$(($(cat "$FAKE/seq") + 1))
    echo "$next" >"$FAKE/seq"
    mv "$in" "$FAKE/entries/$next"
    ;;
  list)
    for entry in "$FAKE"/entries/*; do
      if [[ -e "$entry" ]]; then printf '%s\tpreview\n' "${entry##*/}"; fi
    done | sort -rn
    ;;
esac
EOF

cat >"$TMP/bin/wl-paste" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --list-types) cat "$FAKE/types" ;;
  --type) cat "$FAKE/image" ;;
esac
EOF

cat >"$TMP/bin/launcher-clipboard" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$FAKE/offers"
EOF
chmod +x "$TMP/bin/"*

# fresh STATE with N entries already in the history
reset() {
  rm -rf "$FAKE"
  mkdir -p "$FAKE/entries"
  echo 0 >"$FAKE/seq"
  : >"$FAKE/offers"
  local i
  for ((i = 1; i <= $1; i++)); do
    printf 'older %s\n' "$i" | cliphist store
  done
}
small() { printf 'small image'; }
big() { head -c 200 /dev/zero | tr '\0' x; }

# one copy: offered types, then stdin (what wl-paste chose) and the image
copy() {
  printf '%s\n' "$@" >"$FAKE/types"
  "$STORE" <"$FAKE/text"
}

fail=0
expect_offers() {
  local want=$1 got
  got=$(cat "$FAKE/offers")
  if [[ "$got" == "$want" ]]; then
    echo "ok   $2"
  else
    echo "FAIL $2: offers [${got//$'\n'/ | }], want [${want//$'\n'/ | }]"
    fail=1
  fi
}

reset 1
: >"$FAKE/text"
big >"$FAKE/image"
copy image/png
expect_offers "" "image over the limit is not offered (history has an older copy)"

reset 0
: >"$FAKE/text"
big >"$FAKE/image"
copy image/png
expect_offers "" "image over the limit is not offered (empty history)"

reset 1
big >"$FAKE/text"
copy text/uri-list
expect_offers "" "uri-list over the limit is not offered"

reset 1
printf ' \n\t\n' >"$FAKE/text"
copy text/uri-list
expect_offers "" "blank uri-list is not offered"

reset 1
: >"$FAKE/text"
small >"$FAKE/image"
copy image/png
expect_offers "--offer 2" "stored image is offered"

reset 1
printf 'file:///tmp/a.png\n' >"$FAKE/text"
copy text/uri-list
expect_offers "--offer 2" "stored uri-list is offered"

reset 1
: >"$FAKE/text"
small >"$FAKE/image"
copy image/png
copy image/png
expect_offers $'--offer 2\n--offer 3' "same image twice (dedup, new id) is offered both times"

exit "$fail"
