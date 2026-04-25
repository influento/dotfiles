-- Auto-reload files changed by external processes (agents, git, etc.)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = vim.api.nvim_create_augroup("auto-reload", { clear = true }),
  command = "checktime",
})

-- Auto-save: format + organize imports on InsertLeave, plain write on TextChanged
local auto_save_group = vim.api.nvim_create_augroup("auto-save", { clear = true })

local function saveable()
  return vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= ""
end

vim.api.nvim_create_autocmd("InsertLeave", {
  group = auto_save_group,
  callback = function()
    if not saveable() then return end

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
          vim.cmd("silent! write")
        end
      end)
    else
      vim.cmd("silent! write")
    end
  end,
})

-- Catch normal-mode edits (dw, dd, x, p, r, u, <C-r>, etc.) — write only, no formatting
vim.api.nvim_create_autocmd("TextChanged", {
  group = auto_save_group,
  callback = function()
    if saveable() then
      vim.cmd("silent! write")
    end
  end,
})

-- <C-;> in insert mode: jump to end of line and append semicolon (statement terminator)
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("semicolon-eol", { clear = true }),
  pattern = {
    "c", "cpp", "cs", "java", "rust", "go", "kotlin", "swift", "dart",
    "php", "perl", "javascript", "typescript", "javascriptreact",
    "typescriptreact", "css", "scss",
  },
  callback = function(args)
    vim.schedule(function()
      vim.keymap.set("i", "<C-;>", "<End>;", { buffer = args.buf })
    end)
  end,
})
