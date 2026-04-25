return {
  "GustavEikaas/easy-dotnet.nvim",
  ft = { "cs", "fsharp", "vb", "xaml", "razor" },
  cmd = "Dotnet",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "mfussenegger/nvim-dap",
    "folke/snacks.nvim",
  },
  keys = {
    { "<leader>nr", function() require("easy-dotnet").run() end,            desc = "Run" },
    { "<leader>nR", function() require("easy-dotnet").run_default() end,    desc = "Run default" },
    { "<leader>nw", function() require("easy-dotnet").watch() end,          desc = "Watch" },
    { "<leader>nb", function() require("easy-dotnet").build() end,          desc = "Build" },
    { "<leader>nB", function() require("easy-dotnet").build_solution() end, desc = "Build solution" },
    { "<leader>nt", function() require("easy-dotnet").testrunner() end,     desc = "Test runner" },
    { "<leader>nT", function() require("easy-dotnet").test() end,           desc = "Test (current)" },
    { "<leader>ns", function() require("easy-dotnet").solution_select() end, desc = "Select solution" },
    { "<leader>na", function() require("easy-dotnet").add_package() end,    desc = "Add NuGet package" },
    { "<leader>nA", function() require("easy-dotnet").remove_package() end, desc = "Remove NuGet package" },
    { "<leader>nn", function() require("easy-dotnet").new() end,            desc = "Dotnet new" },
    { "<leader>nc", function() require("easy-dotnet").clean() end,          desc = "Clean" },
    { "<leader>nx", function() require("easy-dotnet").reset() end,          desc = "Reset cache" },
    { "<leader>np", function() require("easy-dotnet").project_view() end,   desc = "Project view" },
    { "<leader>no", function() require("easy-dotnet").outdated() end,       desc = "Outdated packages" },
    { "<leader>nd", function() require("easy-dotnet").diagnostic() end,     desc = "Workspace diagnostics" },
    { "<leader>n`", function() require("easy-dotnet").terminal_toggle() end, desc = "Toggle managed terminal" },
  },
  opts = {
    picker = "snacks",
    test_runner = {
      viewmode = "split",
      enable_buffered_executions = true,
    },
    managed_terminal = {
      auto_hide = false,
    },
  },
}
