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
