-- Key mappings

local map = vim.keymap.set

-- Clear search highlight on Esc
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Window navigation (handled by vim-tmux-navigator plugin)

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })

-- Stay in visual mode when indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Move lines in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- Reload config
map("n", "<leader>rc", function()
  vim.cmd("source " .. vim.fn.stdpath("config") .. "/init.lua")
  vim.notify("Config reloaded")
end, { desc = "Reload Neovim config" })

-- Quit all
map("n", "<leader>qq", "<cmd>qa<CR>", { desc = "Quit all" })
map("n", "<leader>qw", "<cmd>wa | qa<CR>", { desc = "Save all and quit" })

-- Terminal escape
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Diagnostic navigation
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Show diagnostic" })
