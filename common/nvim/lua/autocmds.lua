-- Auto-reload files changed by external processes (agents, git, etc.)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = vim.api.nvim_create_augroup("auto-reload", { clear = true }),
  command = "checktime",
})

-- Auto-save when leaving insert mode (with formatting)
vim.api.nvim_create_autocmd("InsertLeave", {
  group = vim.api.nvim_create_augroup("auto-save", { clear = true }),
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
      -- Organize imports for languages that support it (e.g. Go via gopls)
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      for _, client in ipairs(clients) do
        if client:supports_method("textDocument/codeAction") then
          local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
          params.context = { only = { "source.organizeImports" }, diagnostics = {} }
          local result = client:request_sync("textDocument/codeAction", params, 3000, 0)
          if result and result.result then
            for _, action in ipairs(result.result) do
              if action.edit then
                vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
              end
            end
          end
          break
        end
      end

      local ok, conform = pcall(require, "conform")
      if ok then
        conform.format({ bufnr = 0, timeout_ms = 3000, lsp_format = "fallback" }, function()
          if vim.bo.modified then
            vim.cmd("write")
          end
        end)
      else
        vim.cmd("write")
      end
    end
  end,
})
