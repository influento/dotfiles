return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      { "<leader>f", group = "find" },
      { "<leader>c", group = "code" },
      { "<leader>d", group = "debug" },
      { "<leader>g", group = "git" },
      { "<leader>m", group = "markdown" },
      { "<leader>n", group = "dotnet" },
      { "<leader>x", group = "diagnostics" },
    },
  },
}
