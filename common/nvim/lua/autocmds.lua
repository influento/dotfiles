-- Auto-reload files changed by external processes (agents, git, etc.)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = vim.api.nvim_create_augroup("auto-reload", { clear = true }),
  command = "checktime",
})

-- Briefly highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
})

-- Auto-save: format + organize imports + write after 15s idle or on focus loss / buffer leave.
-- Mirrors JetBrains IDE behavior — paste-friendly because saves are not triggered on InsertLeave.
local auto_save_group = vim.api.nvim_create_augroup("auto-save", { clear = true })

local function saveable()
  return vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= ""
end

local function format_and_save(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  if not vim.bo[bufnr].modified or vim.bo[bufnr].buftype ~= "" then return end
  if vim.api.nvim_buf_get_name(bufnr) == "" then return end

  -- Organize imports for languages that support it (e.g. Go via gopls)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client:supports_method("textDocument/codeAction") then
      local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
      params.context = { only = { "source.organizeImports" }, diagnostics = {} }
      local result = client:request_sync("textDocument/codeAction", params, 3000, bufnr)
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
    conform.format({ bufnr = bufnr, timeout_ms = 3000, lsp_format = "fallback" }, function()
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modified then
        vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)
      end
    end)
  else
    vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! write") end)
  end
end

-- Debounced idle save: timer runs outside insert mode only. Entering insert pauses it;
-- leaving insert restarts it. Paste-safe: format never fires while you are typing, and
-- `o`→`<Esc>`→`p` restarts the timer on each TextChanged.
local idle_ms = 15000
local idle_timer
local pending_buf

local function stop_timer()
  if idle_timer then
    idle_timer:stop()
    idle_timer:close()
    idle_timer = nil
  end
end

local function start_timer(bufnr)
  stop_timer()
  if not saveable() then
    pending_buf = nil
    return
  end
  pending_buf = bufnr
  idle_timer = vim.uv.new_timer()
  idle_timer:start(idle_ms, 0, vim.schedule_wrap(function()
    stop_timer()
    local buf = pending_buf
    pending_buf = nil
    if buf then format_and_save(buf) end
  end))
end

vim.api.nvim_create_autocmd("TextChanged", {
  group = auto_save_group,
  callback = function(args) start_timer(args.buf) end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  group = auto_save_group,
  callback = function() stop_timer() end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = auto_save_group,
  callback = function(args)
    if pending_buf or vim.bo[args.buf].modified then
      start_timer(args.buf)
    end
  end,
})

-- Immediate save on focus loss / buffer leave — matches JetBrains "save on frame deactivation".
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  group = auto_save_group,
  callback = function(args)
    stop_timer()
    pending_buf = nil
    format_and_save(args.buf)
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
