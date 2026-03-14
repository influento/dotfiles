return {
  "christoomey/vim-tmux-navigator",
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Move to left window/pane" },
    { "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Move to lower window/pane" },
    { "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Move to upper window/pane" },
    { "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Move to right window/pane" },
  },
}
