return {
  "echasnovski/mini.nvim",
  version = false,
  event = "VeryLazy",
  config = function()
    require("mini.pairs").setup()
    require("mini.surround").setup()
    require("mini.comment").setup()
    require("mini.statusline").setup()
  end,
}
