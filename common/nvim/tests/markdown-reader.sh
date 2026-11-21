#!/usr/bin/env bash
# markdown-reader: a markdown file you left the reader on to edit stays
# editable. Coming back to it while the session reads (another file read
# since) must show the source, not the read-only mirror, where :w fails with
# E382. A file not edited yet still opens in the reader. And edit keys typed
# in the reader reach the source in the order typed.
# Runs headless nvim with this config's lua/ only (no plugins): markdown-reader
# and mdtable need nothing else. Run from common/nvim: bash tests/markdown-reader.sh
set -euo pipefail

NVIM_DIR=$(readlink -f "$(dirname "$0")/..")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
printf '# A\n\nhello\n' >"$TMP/a.md"
printf '# B\n\nworld\n' >"$TMP/b.md"
printf '# C\n\nnew\n' >"$TMP/c.md"

cat >"$TMP/run.lua" <<'LUA'
local out = {}
local function say(s) out[#out + 1] = s end
local function shown(tag)
  local b = vim.api.nvim_get_current_buf()
  say(string.format("%s: %s", tag, vim.bo[b].buftype == "" and "source" or "reader"))
end
local function settle() vim.wait(50, function() return false end) end
local dir = vim.env.MDTEST

-- After VimEnter: the reader holds the first file's render until then.
vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function() vim.schedule(function()
local ok_all, e_all = pcall(function()
settle()
shown("a.md opened")
vim.cmd.MarkdownRead(); settle()                     -- leave the reader to edit
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "edited" })
vim.cmd("silent write")
vim.cmd("edit " .. dir .. "/b.md"); settle()         -- raw: editing mode now
vim.cmd.MarkdownRead(); settle()                     -- read b.md: reading mode again
vim.cmd("buffer " .. vim.fn.bufnr(dir .. "/a.md")); settle()
shown("back on a.md")
local ok, err = pcall(vim.cmd, "silent write")
say("a.md :w: " .. (ok and "ok" or err:match("E%d+") or err))
vim.cmd("edit " .. dir .. "/c.md"); settle()
shown("c.md opened")
end)
if not ok_all then say("error: " .. tostring(e_all)) end
vim.fn.writefile(out, dir .. "/result")
vim.cmd("qa!")
end) end })
LUA

MDTEST="$TMP" timeout 30 nvim --headless --clean -u NONE \
  --cmd "set rtp^=${NVIM_DIR} hidden" --cmd "lua require('markdown-reader')" \
  -c "luafile $TMP/run.lua" "$TMP/a.md" >/dev/null 2>&1 || true

# Edit keys typed in the reader act on the source in the order typed, also
# when the rest of the keys are already waiting (a paste, a fast typist, key
# repeat): `otyped<Esc>` must add a line "typed", not run "typed" as commands.
cat >"$TMP/keys.lua" <<'LUA'
vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function() vim.schedule(function()
  local keys = vim.env.MDKEYS
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.fn.writefile({ table.concat(lines, "|") }, vim.env.MDTEST .. "/keys-result")
  vim.cmd("qa!")
end) end })
LUA

fail=0
# keys, then the source's lines after them (joined by |), from "# A", "", "hello".
while IFS=$'\t' read -r keys want; do
  printf '# A\n\nhello\n' >"$TMP/k.md"
  rm -f "$TMP/keys-result"
  MDTEST="$TMP" MDKEYS="$keys" timeout 30 nvim --headless --clean -u NONE \
    --cmd "set rtp^=${NVIM_DIR} hidden" --cmd "lua require('markdown-reader')" \
    -c "luafile $TMP/keys.lua" "$TMP/k.md" >/dev/null 2>&1 || true
  got=$(cat "$TMP/keys-result" 2>/dev/null || echo "(nvim wrote no result)")
  if [[ "$got" == "$want" ]]; then
    echo "ok   $keys typed ahead in the reader edits the source"
  else
    echo "FAIL $keys typed ahead in the reader edits the source"
    printf '     expected: %s\n     got:      %s\n' "$want" "$got"
    fail=1
  fi
done <<'CASES'
otyped<Esc>	# A|typed||hello
ccswapped<Esc>	swapped||hello
Aend<Esc>	# Aend||hello
CASES

expected='a.md opened: reader
back on a.md: source
a.md :w: ok
c.md opened: reader'
got=$(cat "$TMP/result" 2>/dev/null || echo "(nvim wrote no result)")
if [[ "$got" == "$expected" ]]; then
  echo "ok   a file left for editing stays editable; a new one still opens in the reader"
else
  echo "FAIL a file left for editing stays editable; a new one still opens in the reader"
  diff <(echo "$expected") <(echo "$got") | sed 's/^/     /'
  fail=1
fi
exit "$fail"
