-- Read-only rendered view for markdown, toggled with <leader>z.
--
-- The buffer you edit stays raw markdown: nothing decorates it, so the cursor,
-- soft-wrap and scrolling behave normally and tables stay editable one source
-- line per row. Reading happens in a mirror buffer built by lua/mdtable.lua,
-- which lays tables out to the window width, re-flows prose to a readable
-- measure and insets the page. That mirror holds real lines, so scroll, search
-- and zt/zz work there too -- see the comment at the top of mdtable.lua for why
-- decorating the live buffer with extmarks cannot achieve the same thing.

local mdtable = require("mdtable")

local reader = {} -- reader buf -> { src = source buf, map = src lnum -> reader lnum }
local ns = vim.api.nvim_create_namespace("markdown-reader")

local function render(rbuf, sbuf, win)
  local info = vim.fn.getwininfo(win)[1]
  local avail = info and (info.width - info.textoff) or 80
  local lines, map, hls = mdtable.document(sbuf, avail)

  vim.bo[rbuf].modifiable = true
  vim.api.nvim_buf_set_lines(rbuf, 0, -1, false, lines)
  vim.bo[rbuf].modifiable = false

  -- Colour. These extmarks carry hl_group ONLY -- never conceal, virt_text or
  -- virt_lines: anything that changed a line's width would shift the box-drawing
  -- borders out of alignment with the row below.
  vim.api.nvim_buf_clear_namespace(rbuf, ns, 0, -1)
  for _, h in ipairs(hls) do
    local text = lines[h.line]
    if text then
      pcall(vim.api.nvim_buf_set_extmark, rbuf, ns, h.line - 1, math.min(h.col or 0, #text), {
        end_col = math.min(h.end_col or #text, #text),
        hl_group = h.hl,
        hl_eol = h.eol,
        priority = 190,
      })
    end
  end

  reader[rbuf] = { src = sbuf, map = map }
  return map
end

-- Reading or editing is a mode for the whole session, not a per-file memory:
-- leaving the reader means "I am editing now", so the next markdown file opens
-- raw too. One <leader>z puts you back into reading for good. Set
-- vim.g.markdown_reader_auto = false to start in editing mode instead.
local auto = vim.g.markdown_reader_auto ~= false

local function open()
  local sbuf = vim.api.nvim_get_current_buf()
  -- <leader>z is markdown-buffer-local, but :MarkdownRead can be run anywhere.
  if vim.bo[sbuf].filetype ~= "markdown" then
    vim.notify("MarkdownRead: not a markdown buffer", vim.log.levels.WARN)
    return
  end
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)[1]

  local rbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[rbuf].buftype = "nofile"
  vim.bo[rbuf].bufhidden = "wipe"
  vim.bo[rbuf].swapfile = false

  -- No filetype on purpose, so treesitter does not decorate a buffer that only
  -- looks like markdown: every conceal shortens a line, and a shortened line
  -- inside a rendered table misaligns its borders. The colours come from
  -- render()'s own extmarks instead.
  vim.api.nvim_win_set_buf(win, rbuf)

  -- Window options before the first render: the layout is computed from the
  -- window's usable width, so the gutter has to be gone first or the page ends up
  -- inset by the number column instead of by its own margin. (A reader line
  -- number would mean nothing anyway -- one source line can render as several.)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].list = false
  vim.wo[win].wrap = true      -- text is wrapped already; this catches overflow
  vim.wo[win].linebreak = true
  -- The buffer is deliberately nameless. A name like "reader://<path>" is not a
  -- path that exists, and anything that resolves the current buffer against the
  -- cwd trips over it -- neo-tree's follow_current_file asked to change the cwd
  -- every time the tree was focused. Nameless makes those checks skip the buffer
  -- (neo-tree's get_path_to_reveal returns nil on an empty name), and the winbar
  -- carries the file's identity instead, where a reader wants a title anyway.
  vim.wo[win].winbar = "  " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(sbuf), ":~:.")

  mdtable.set_highlights()
  local map = render(rbuf, sbuf, win)

  local target = math.max(1, math.min(map[cursor] or 1, vim.api.nvim_buf_line_count(rbuf)))
  vim.api.nvim_win_set_cursor(win, { target, 0 })
  vim.cmd("normal! zz")

  for _, key in ipairs({ "q", "<leader>z" }) do
    vim.keymap.set("n", key, "<cmd>MarkdownRead<cr>", { buffer = rbuf, silent = true })
  end
  -- Reading is the default, so the keys that mean "I want to change this" have to
  -- work from here: they drop to the source at the matching line and then do what
  -- they normally do. Without this, every edit costs a <leader>z first.
  for _, key in ipairs({ "i", "a", "I", "A", "o", "O", "c", "s", "r", "x", "d", "p", "u" }) do
    vim.keymap.set("n", key, function()
      vim.cmd.MarkdownRead()
      vim.api.nvim_feedkeys(key, "m", false)  -- remap, so the config's own x and d still apply
    end, { buffer = rbuf, silent = true, desc = "Edit the source" })
  end
  -- Leaving by any route -- close(), :bd, another buffer opened here -- takes the
  -- title with it. It belongs to the window, not to the buffer that set it.
  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = rbuf,
    callback = function()
      local w = vim.fn.bufwinid(rbuf)
      if w ~= -1 then vim.wo[w].winbar = "" end
    end,
  })
  -- Both the column allocation and the re-flow depend on the window width.
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    buffer = rbuf,
    callback = function()
      local w = vim.fn.bufwinid(rbuf)
      if w ~= -1 then render(rbuf, sbuf, w) end
    end,
  })
end

local function close()
  local rbuf = vim.api.nvim_get_current_buf()
  local st = reader[rbuf]
  if not st then return end
  local win = vim.api.nvim_get_current_win()
  local rline = vim.api.nvim_win_get_cursor(win)[1]
  -- Invert the map: the last source line whose render starts at or before here.
  local best = 1
  for src, r in pairs(st.map) do
    if r <= rline and src > best and r >= (st.map[best] or 0) then best = src end
  end
  reader[rbuf] = nil
  vim.wo[win].winbar = ""
  -- The source can be gone: :bd while the reader was up, or the file replaced by
  -- something else editing it. Do not throw on the way out.
  if not vim.api.nvim_buf_is_valid(st.src) then
    vim.cmd.enew()
    return
  end
  vim.api.nvim_win_set_buf(win, st.src)
  vim.api.nvim_win_set_cursor(win, { math.min(best, vim.api.nvim_buf_line_count(st.src)), 0 })
  vim.cmd("normal! zz")
end

vim.api.nvim_create_user_command("MarkdownRead", function()
  if reader[vim.api.nvim_get_current_buf()] then
    auto = false
    close()
  else
    auto = true
    open()
  end
end, { desc = "Toggle the rendered markdown view" })

local group = vim.api.nvim_create_augroup("markdown-reader", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "markdown",
  callback = function(args)
    vim.keymap.set("n", "<leader>z", "<cmd>MarkdownRead<cr>",
      { buffer = args.buf, silent = true, desc = "Toggle rendered markdown view" })
  end,
})

-- BufWinEnter, not FileType: the layout is measured from the window, which is not
-- settled yet when FileType fires. Reader buffers have no filetype, so swapping one
-- in cannot re-trigger this, and close() clears `auto` before swapping the source
-- back -- otherwise leaving the reader would immediately reopen it.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(args)
    if not auto or vim.bo[args.buf].filetype ~= "markdown" then return end
    if vim.bo[args.buf].buftype ~= "" or reader[args.buf] then return end
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) ~= args.buf or vim.wo[win].diff then return end
    -- The very first file can arrive before lazy.nvim has loaded the colourscheme
    -- and the treesitter queries, so hold the opening render until startup is done.
    if vim.v.vim_did_enter == 0 then
      vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function() vim.schedule(open) end })
    else
      vim.schedule(open)
    end
  end,
})

-- The groups link into whatever markdown palette the active theme provides.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function()
    if next(reader) then mdtable.set_highlights() end
  end,
})
