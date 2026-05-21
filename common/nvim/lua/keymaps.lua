-- Key mappings

local map = vim.keymap.set

-- Clear search highlight on Esc
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Delete buffer" })
map("n", "<leader>bo", "<cmd>%bd|e#|bd#<CR>", { desc = "Delete other buffers" })

-- Splits (tmux-style)
map("n", "<leader>-", "<cmd>split<CR>", { desc = "Split horizontal" })
map("n", "<leader>|", "<cmd>vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>wq", "<cmd>close<CR>", { desc = "Close split" })

-- Black hole deletes — clipboard is shared, so default d/c/dd are "cut".
-- Use x and <leader>d when you want a true delete that does not touch clipboard.
map({ "n", "x" }, "x", '"_x')
map({ "n", "x" }, "<leader>d", '"_d', { desc = "Delete (no yank)" })
map("n", "<leader>D", '"_D', { desc = "Delete to EOL (no yank)" })

-- Visual-mode paste must not clobber the clipboard with the overwritten selection.
-- Use the explicit form so it works in older Vim/IdeaVim too (parity across editors).
map("x", "p", '"_dP', { desc = "Paste without yanking selection" })

-- Stay in visual mode when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Move lines in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- gm{c} jumps to mark — ` is hard to reach.
map("n", "gm", function()
  local c = vim.fn.getcharstr()
  vim.cmd("normal! `" .. c)
end, { desc = "Jump to mark" })

map("n", "]m", "]'", { desc = "Next mark" })
map("n", "[m", "['", { desc = "Previous mark" })

map("n", "<leader>rc", function()
  vim.cmd("source " .. vim.fn.stdpath("config") .. "/init.lua")
  vim.notify("Config reloaded")
end, { desc = "Reload Neovim config" })

map("n", "<leader>qq", "<cmd>qa<CR>", { desc = "Quit all" })
map("n", "<leader>qw", "<cmd>wa | qa<CR>", { desc = "Save all and quit" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Diagnostic navigation
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Show diagnostic" })

-- ]g / [g — cycle usages of symbol via LSP documentHighlight; falls back to */# without LSP.
local function cycle_usage(direction)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local pos = vim.api.nvim_win_get_cursor(0)
    local cur_line, cur_col = pos[1] - 1, pos[2]

    local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentHighlight" })
    if vim.tbl_isempty(clients) then
      vim.cmd("normal! " .. (direction == 1 and "*" or "#"))
      return
    end

    local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
    local results = vim.lsp.buf_request_sync(bufnr, "textDocument/documentHighlight", params, 500) or {}
    local ranges = {}
    for _, res in pairs(results) do
      for _, hl in ipairs(res.result or {}) do
        table.insert(ranges, hl.range.start)
      end
    end
    if #ranges == 0 then
      vim.cmd("normal! " .. (direction == 1 and "*" or "#"))
      return
    end

    table.sort(ranges, function(a, b)
      if a.line ~= b.line then return a.line < b.line end
      return a.character < b.character
    end)

    local target
    if direction == 1 then
      for _, r in ipairs(ranges) do
        if r.line > cur_line or (r.line == cur_line and r.character > cur_col) then
          target = r
          break
        end
      end
      target = target or ranges[1]
    else
      for i = #ranges, 1, -1 do
        local r = ranges[i]
        if r.line < cur_line or (r.line == cur_line and r.character < cur_col) then
          target = r
          break
        end
      end
      target = target or ranges[#ranges]
    end

    vim.api.nvim_win_set_cursor(0, { target.line + 1, target.character })
  end
end

map("n", "]g", cycle_usage(1),  { desc = "Next usage of symbol" })
map("n", "[g", cycle_usage(-1), { desc = "Previous usage of symbol" })
