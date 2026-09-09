-- Prompt navigation for a tmux pane's scrollback, opened by `prefix e`.
--
-- The tmux binding captures the pane's history to a file named
-- tmux-scrollback.* and opens it in nvim. Only that buffer gets this: every
-- line that starts with a prompt sign (`❯ `, Claude Code's echo of what you
-- asked, and the starship prompt of a shell) is a section, `]]` and `[[`
-- move between them, the lines are highlighted, `/` is preloaded so `n` and
-- `N` walk them too, and the statusline says which prompt the cursor is
-- under. Nothing here touches any other buffer or a global key.

local M = {}

local PROMPT = [[^❯ ]]

local ns = vim.api.nvim_create_namespace("scrollback")

-- Line numbers (1-based) of the prompt lines, computed once per buffer.
local function prompts(buf)
  local out = {}
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find(PROMPT) then out[#out + 1] = i end
  end
  return out
end

-- Index of the prompt at or above the cursor, 0 when above the first.
local function current(list, row)
  local at = 0
  for i, l in ipairs(list) do
    if l <= row then at = i else break end
  end
  return at
end

local function jump(buf, dir)
  local list = vim.b[buf].scrollback_prompts
  if #list == 0 then return end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if dir > 0 then
    for _, l in ipairs(list) do
      if l > row then target = l; break end
    end
  else
    for i = #list, 1, -1 do
      if list[i] < row then target = list[i]; break end
    end
  end
  if target then
    vim.cmd("normal! m'")
    vim.api.nvim_win_set_cursor(0, { target, 0 })
    vim.cmd("normal! zt")
  end
end

function M.status()
  local list = vim.b.scrollback_prompts or {}
  if #list == 0 then return "no prompts" end
  return string.format("prompt %d/%d", current(list, vim.api.nvim_win_get_cursor(0)[1]), #list)
end

local function attach(buf)
  local list = prompts(buf)
  vim.b[buf].scrollback_prompts = list
  for _, l in ipairs(list) do
    vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, { line_hl_group = "ScrollbackPrompt", priority = 10 })
  end
  vim.keymap.set("n", "]]", function() jump(buf, 1) end, { buffer = buf, desc = "Next prompt" })
  vim.keymap.set("n", "[[", function() jump(buf, -1) end, { buffer = buf, desc = "Previous prompt" })
  vim.fn.setreg("/", PROMPT)
  vim.wo.statusline = " %t %= %{v:lua.require'scrollback'.status()}  %l:%c "
  vim.bo[buf].modifiable = false
end

vim.api.nvim_set_hl(0, "ScrollbackPrompt", { link = "Visual", default = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("scrollback", { clear = true }),
  pattern = "tmux-scrollback.*",
  callback = function(ev) attach(ev.buf) end,
})

return M
