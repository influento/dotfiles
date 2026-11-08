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
  config = function(_, opts)
    require("neo-tree").setup(opts)

    -- A markdown file in the reader (lua/markdown-reader.lua) is a nameless
    -- buffer, so neo-tree finds no current file to reveal or follow. Every
    -- reveal goes through get_path_to_reveal, so answer with the reader's
    -- source there; the callers keep their own rules, such as ignoring files
    -- outside the tree root. Floats stay ignored, as the original does.
    local manager = require("neo-tree.sources.manager")
    local get_path_to_reveal = manager.get_path_to_reveal
    manager.get_path_to_reveal = function(...)
      if not require("neo-tree.utils").is_floating() then
        local src = require("markdown-reader").source(vim.api.nvim_get_current_buf())
        if src then return src end
      end
      return get_path_to_reveal(...)
    end

    -- follow_current_file only fires for buffers with a real file name, so a
    -- reader buffer entered again (another window, :b) asks to follow by itself.
    if not opts.filesystem.follow_current_file.enabled then return end
    vim.api.nvim_create_autocmd("BufEnter", {
      group = vim.api.nvim_create_augroup("neo-tree-reader-follow", { clear = true }),
      callback = function(args)
        if require("markdown-reader").source(args.buf) then
          require("neo-tree.sources.filesystem").follow()
        end
      end,
    })
  end,
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
