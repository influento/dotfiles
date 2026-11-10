#!/usr/bin/env bash
# The linking half of install.sh against a throwaway HOME: a deploy links
# every source, keeps what it replaces, and a second deploy changes nothing.
# Nothing is fetched. Needs the templates rendered (bash install.sh once).
# Plain bash, no framework. Run: bash tests/deploy.sh
# shellcheck source-path=SCRIPTDIR
set -euo pipefail

DOTFILES_DIR=$(readlink -f "$(dirname "$0")/..")
# shellcheck source=../lib/log.sh
source "${DOTFILES_DIR}/lib/log.sh"
# shellcheck source=../lib/helpers.sh
source "${DOTFILES_DIR}/lib/helpers.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail=0
check() { if "$@" >/dev/null 2>&1; then echo "ok   $*"; else echo "FAIL $*"; fail=1; fi; }
# shellcheck disable=SC2329  # called through check
not() { ! "$@"; }

# The link steps of install.sh, in its order, both profiles.
deploy() {
  deploy_configs "${DOTFILES_DIR}/common" "$1" common
  link_debian_names "$1"
  deploy_configs "${DOTFILES_DIR}/workstation" "$1" workstation
  prune_dead_links "$1"
}
# Every path under a HOME with its type, mode, link target and content.
snapshot() {
  (cd "$1" && find . -printf '%y %m %p -> %l\n' | sort && find . -type f -exec md5sum {} + | sort -k2)
}
# A symlink under a HOME that points into the repo at nothing.
dead_links() {
  find "$1" -type l -lname "${DOTFILES_DIR}/*" ! -exec test -e {} \; -print
}

missing=$(cd "$DOTFILES_DIR" && git ls-files '*.tpl' | while read -r t; do [[ -e "${t%.tpl}" ]] || echo "$t"; done)
if [[ -n "$missing" ]]; then
  echo "FAIL templates not rendered (run bash install.sh first): $missing"
  exit 1
fi

echo "== a fresh HOME"
H="$TMP/fresh"; mkdir -p "$H"
deploy "$H" 2>"$TMP/fresh.1"
check not grep -q 'Source does not exist' "$TMP/fresh.1"
check test -z "$(dead_links "$H")"
check test "$(readlink "$H/.config/nvim")" = "${DOTFILES_DIR}/common/nvim"
check test "$(readlink "$H/.zshrc")" = "${DOTFILES_DIR}/common/zsh/.zshrc"
check test "$(readlink "$H/.local/bin/stack")" = "${DOTFILES_DIR}/common/claude-code/workshop/stack/bin/stack"
check test "$(readlink "$H/.config/gtk-4.0")" = "${DOTFILES_DIR}/workstation/theming/gtk-4.0"
check test -x "$H/.local/bin/tmux-overlay"
check not test -e "$H/.local/bin/CLAUDE.md"
check test -f "$H/.claude/settings.json"
check not test -L "$H/.claude/settings.json"
snapshot "$H" >"$TMP/fresh.s1"
deploy "$H" 2>"$TMP/fresh.2"
snapshot "$H" >"$TMP/fresh.s2"
check cmp -s "$TMP/fresh.s1" "$TMP/fresh.s2"
check not grep -qE 'Linked|Relinked|Wrote|Backing up|Pruning' "$TMP/fresh.2"

echo "== a HOME with its own files"
H="$TMP/own"; mkdir -p "$H/.config/nvim" "$H/.claude"
echo mine >"$H/.zshrc"
echo mine >"$H/.config/nvim/init.lua"
ln -s /etc/hostname "$H/.gitconfig"
echo '{"theme":"dark","permissions":{"allow":["Bash(mine)"]}}' >"$H/.claude/settings.json"
deploy "$H" 2>"$TMP/own.1"
check grep -qx mine "$H"/.zshrc.backup.*
check grep -qx mine "$H"/.config/nvim.backup.*/init.lua
check test "$(readlink "$H"/.gitconfig.backup.*)" = /etc/hostname
check test "$(readlink "$H/.zshrc")" = "${DOTFILES_DIR}/common/zsh/.zshrc"
# keys only the app writes survive the merge; the tracked lists replace the live ones
check python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(d["theme"]!="dark" or "Bash(mine)" in d["permissions"]["allow"])' "$H/.claude/settings.json"
check grep -q 'Dropped from .*Bash(mine)' "$TMP/own.1"
snapshot "$H" >"$TMP/own.s1"
deploy "$H" 2>"$TMP/own.2"
snapshot "$H" >"$TMP/own.s2"
check cmp -s "$TMP/own.s1" "$TMP/own.s2"

echo "== a HOME with links from an older checkout"
H="$TMP/old"; mkdir -p "$H/.local/bin" "$H/.config"
ln -s "${DOTFILES_DIR}/common/scripts/gone" "$H/.local/bin/gone"
# a link to another path in the repo, as a moved source leaves it
ln -s "${DOTFILES_DIR}/workstation/sway" "$H/.config/mako"
deploy "$H" 2>"$TMP/old.1"
check not test -L "$H/.local/bin/gone"
check test "$(readlink "$H/.config/mako")" = "${DOTFILES_DIR}/workstation/mako"
check test -z "$(find "$H/.config" -maxdepth 1 -name 'mako.backup.*')"
check not grep -q 'Backing up' "$TMP/old.1"
snapshot "$H" >"$TMP/old.s1"
deploy "$H" 2>"$TMP/old.2"
snapshot "$H" >"$TMP/old.s2"
check cmp -s "$TMP/old.s1" "$TMP/old.s2"

echo "== a Debian PATH: batcat and fdfind, no bat or fd"
H="$TMP/debian"; mkdir -p "$H" "$TMP/debian-bin" "$TMP/path"
for f in /usr/bin/* /bin/*; do
  case "${f##*/}" in bat | fd | batcat | fdfind) continue ;; esac
  [[ -e "$TMP/path/${f##*/}" ]] || ln -s "$f" "$TMP/path/${f##*/}"
done
printf '#!/bin/sh\n' >"$TMP/debian-bin/batcat"
printf '#!/bin/sh\n' >"$TMP/debian-bin/fdfind"
chmod +x "$TMP/debian-bin/batcat" "$TMP/debian-bin/fdfind"
PATH="$TMP/debian-bin:$TMP/path" link_debian_names "$H" 2>/dev/null
check test "$(readlink "$H/.local/bin/bat")" = "$TMP/debian-bin/batcat"
check test "$(readlink "$H/.local/bin/fd")" = "$TMP/debian-bin/fdfind"
snapshot "$H" >"$TMP/debian.s1"
PATH="$H/.local/bin:$TMP/debian-bin:$TMP/path" link_debian_names "$H" 2>"$TMP/debian.2"
snapshot "$H" >"$TMP/debian.s2"
check cmp -s "$TMP/debian.s1" "$TMP/debian.s2"
check not grep -qE 'Linked|Relinked|Backing up' "$TMP/debian.2"

exit "$fail"
