return {
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "csharpier",
        "prettier",
        "ruff",
        "shfmt",
        "stylua",
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
    },
    config = function()
      -- Servers are configured through vim.lsp.config: nvim-lspconfig ships
      -- the per-server defaults under lsp/, and mason-lspconfig v2 enables
      -- every installed server with vim.lsp.enable. It has no `handlers`
      -- option any more; a handlers table is silently ignored.
      --
      -- blink registers its completion capabilities into vim.lsp.config("*")
      -- from its own plugin/ file, but only once it loads (InsertEnter).
      -- Setting them here, with blink as a dependency, means the first server
      -- to start already gets them instead of the plain nvim defaults.
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      require("mason-lspconfig").setup({
        ensure_installed = {
          "bashls",
          "clangd",
          "gopls",
          "jsonls",
          "lua_ls",
          "marksman",
          "powershell_es",
          "pyright",
          "rust_analyzer",
          "taplo",
          "ts_ls",
          "yamlls",
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "Go to references")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("gt", vim.lsp.buf.type_definition, "Go to type definition")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          vim.keymap.set("v", "<leader>ca", vim.lsp.buf.code_action, { buffer = event.buf, desc = "Code action" })
        end,
      })
    end,
  },
}
