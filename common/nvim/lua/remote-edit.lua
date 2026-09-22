-- :EditAt {line} {file} -- the single entry point lazygit's `e` uses to hand a
-- file to this nvim.
--
-- lazygit's built-in nvim-remote preset does it in three separate `nvim --server`
-- invocations: send "q", then --remote-tab, then send ":{line}<CR>". Three
-- round trips into a running editor is three chances to interleave badly, and
-- two of them actually do:
--
--   * the "q" is meant for lazygit itself, but if the float is already gone it
--     lands in nvim -- and in a markdown reader buffer `q` toggles the reader
--     off AND sets its auto flag false, silently killing reader mode for the
--     rest of the session.
--   * ":{line}<CR>" arrives after --remote-tab, so for markdown the reader has
--     usually already swapped in its rendered mirror. The jump then indexes the
--     RENDERED buffer, where one source line can occupy several -- asking for
--     source line 12 landed on a table border.
--
-- One command fixes both: nothing is sent that lazygit could have wanted, and
-- the order is ours, so the cursor is placed on the real line.
local reader = require("markdown-reader")

-- lazygit substitutes an absolute path, so the first branch is the one that runs.
-- The repo fallback is for calling :EditAt by hand with a path relative to the
-- repository rather than to nvim's cwd.
local function resolve(file)
  if vim.fn.filereadable(file) == 1 then return vim.fn.fnamemodify(file, ":p") end
  local root = vim.fs.root(0, { ".git" })
  if root then
    local candidate = root .. "/" .. file
    if vim.fn.filereadable(candidate) == 1 then return candidate end
  end
  return vim.fn.fnamemodify(file, ":p")
end

vim.api.nvim_create_user_command("EditAt", function(o)
  -- nargs="+" so a path containing spaces survives: lazygit does not quote its
  -- substitution, so the tail is rejoined rather than read as one argument.
  local line = tonumber(o.fargs[1]) or 0
  local file = table.concat(o.fargs, " ", 2)
  if file == "" then
    vim.notify("EditAt: no file given", vim.log.levels.WARN)
    return
  end

  -- `e` means "I am about to change this", so markdown opens as source. The
  -- reader is what `o` is for now that it gets its own window, and <leader>z is
  -- one key away. Suppressing it also makes the line exact rather than mapped.
  local path = resolve(file)
  reader.suppress(path)

  -- We may be called from terminal mode in the lazygit float. Leaving it before
  -- switching tabpages keeps the float from holding the keyboard afterwards.
  vim.cmd("stopinsert")
  -- And close the float itself. Leaving it open desynchronises Snacks.lazygit()'s
  -- toggle -- the next <leader>gv hides the window still sitting in the tab we
  -- came from instead of showing one -- and once it is shown again it covers the
  -- very file we dropped to, so a second `e` on that file looks like it did
  -- nothing. The terminal buffer and its job outlive the window, so toggling back
  -- resumes the same lazygit rather than starting a new one.
  local from = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(from).relative ~= "" then
    pcall(vim.api.nvim_win_close, from, false)
  end
  -- `drop`, not `tabedit`: a file already open in some window is jumped to
  -- instead of being opened a second time in a tab of its own.
  vim.cmd("tab drop " .. vim.fn.fnameescape(path))

  if line > 0 then
    local target = math.max(1, math.min(line, vim.api.nvim_buf_line_count(0)))
    vim.api.nvim_win_set_cursor(0, { target, 0 })
    vim.cmd("normal! zz")
  end
end, { nargs = "+", desc = "Open a file at a line for lazygit's remote edit" })
