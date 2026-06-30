return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "FzfLua",
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Live grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Buffers" },
    { "<leader>fh", "<cmd>FzfLua helptags<CR>", desc = "Help tags" },
    { "<leader>fr", "<cmd>FzfLua oldfiles<CR>", desc = "Recent files" },
    { "<leader>fd", "<cmd>FzfLua diagnostics_workspace<CR>", desc = "Diagnostics" },
    { "<leader>fa", "<cmd>FzfLua commands<CR>", desc = "Find action (ex commands)" },
    { "<leader>/", "<cmd>FzfLua lgrep_curbuf<CR>", desc = "Search in buffer" },
    { "<leader>'", "<cmd>FzfLua marks<CR>", desc = "Marks" },
  },
  opts = {},
}
