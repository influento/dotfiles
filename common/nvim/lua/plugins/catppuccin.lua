return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  opts = {
    flavour = "mocha",
    integrations = {
      gitsigns = true,
      indent_blankline = { enabled = true },
      mason = true,
      neotree = true,
      snacks = true,
      treesitter = true,
      which_key = true,
      mini = { enabled = true },
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
