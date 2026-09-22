return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  keys = {
    { "<leader>gv", function() Snacks.lazygit() end, desc = "Lazygit" },
  },
  opts = {
    lazygit = {
      -- Replace lazygit's nvim-remote preset. That preset edits in three
      -- separate `nvim --server` calls -- send "q", --remote-tab, send
      -- ":{line}<CR>" -- and both the "q" and the trailing jump land in the
      -- wrong place often enough to matter (see lua/remote-edit.lua). One
      -- <cmd> mapping is atomic and works from terminal mode, so lazygit is
      -- never sent a key it did not ask for and keeps running in the float.
      config = {
        os = {
          edit = 'nvim --server "$NVIM" --remote-send "<cmd>EditAt 0 {{filename}}<cr>"',
          editAtLine = 'nvim --server "$NVIM" --remote-send "<cmd>EditAt {{line}} {{filename}}<cr>"',
        },
      },
    },
    dashboard = {
      preset = {
        header = "  " .. (vim.uv.os_gethostname or vim.loop.os_gethostname)():upper() .. "  ",
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":FzfLua files" },
          { icon = " ", key = "g", desc = "Live Grep", action = ":FzfLua live_grep" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":FzfLua oldfiles" },
          { icon = " ", key = "e", desc = "Explorer", action = ":Neotree focus" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "recent_files", cwd = true, limit = 8, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
