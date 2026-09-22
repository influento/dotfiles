-- The gutter: a one-cell sign lane, then the line number.
--
-- The built-in sign column is two cells wide whatever the sign, and gitsigns'
-- bar and the diagnostic letters are one, so half of it was always blank. This
-- draws the highest-priority sign's first cell and nothing else.

local M = {}

local function sign(buf, lnum)
  local marks = vim.api.nvim_buf_get_extmarks(buf, -1, { lnum - 1, 0 }, { lnum - 1, -1 },
    { type = "sign", details = true })
  local best
  for _, m in ipairs(marks) do
    local d = m[4]
    if d.sign_text and (not best or (d.priority or 0) > (best.priority or 0)) then best = d end
  end
  if not best then return " " end
  local text = vim.fn.strcharpart(vim.trim(best.sign_text), 0, 1)
  if text == "" then return " " end
  return "%#" .. (best.sign_hl_group or "SignColumn") .. "#" .. text .. "%*"
end

function M.render()
  local win = vim.g.statusline_winid
  local wo = vim.wo[win]
  -- A window that turned the gutter off (the markdown reader, neo-tree, plugin
  -- panels) gets none, as it would with the built-in columns.
  if not wo.number and not wo.relativenumber and wo.signcolumn == "no" then return "" end
  local lane = " "
  if wo.signcolumn ~= "no" and vim.v.virtnum == 0 then
    lane = sign(vim.api.nvim_win_get_buf(win), vim.v.lnum)
  end
  return lane .. "%l "
end

return M
