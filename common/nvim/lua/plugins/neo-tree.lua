return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  cmd = { "Neotree" },
  keys = {
    {
      "<leader>e",
      function()
        local manager = require("neo-tree.sources.manager")
        local state = manager.get_state("filesystem")
        if state.winid and vim.api.nvim_win_is_valid(state.winid) then
          if vim.api.nvim_get_current_win() == state.winid then
            vim.cmd("Neotree close")
          else
            vim.cmd("Neotree focus")
          end
        else
          vim.cmd("Neotree focus")
        end
      end,
      desc = "Toggle/focus file explorer",
    },
  },
  opts = {
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    window = {
      width = 35,
      mappings = {
        ["<space>"] = "none",
      },
    },
  },
}
