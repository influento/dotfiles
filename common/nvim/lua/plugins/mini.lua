return {
  "echasnovski/mini.nvim",
  version = false,
  event = "VeryLazy",
  config = function()
    require("mini.pairs").setup()
    require("mini.surround").setup({
      -- Keep bare `s` free for flash.nvim.
      mappings = {
        add            = "<leader>sa",
        delete         = "<leader>sd",
        find           = "<leader>sf",
        find_left      = "<leader>sF",
        highlight      = "<leader>sh",
        replace        = "<leader>sr",
        update_n_lines = "<leader>sn",
      },
    })
    require("mini.statusline").setup()
    require("mini.pick").setup({
      window = {
        config = {
          relative = "cursor",
          anchor = "NW",
          row = 1,
          col = 0,
          width = 60,
          height = 10,
        },
      },
    })
    vim.ui.select = function(items, opts, on_choice)
      return require("mini.pick").ui_select(items, opts, on_choice)
    end
  end,
}
