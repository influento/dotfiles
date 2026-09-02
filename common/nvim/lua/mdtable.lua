-- Render a markdown buffer into plain lines for a read-only reader: tables fitted
-- to the window by shrinking columns widest-first and wrapping their cells, prose
-- re-flowed to a readable measure, the page inset on both sides.
--
-- Real lines, deliberately. Decorating the live buffer with extmarks cannot work:
-- `conceal` hides a row's glyphs but keeps its wrapped height (blank gaps in the
-- table), `conceal_lines` collapses the row but suppresses that line's own
-- `virt_lines` (nothing renders at all), and a `virt_lines` block taller than the
-- window is one Neovim refuses to scroll into. A separate buffer of ordinary
-- lines has none of those limits: scrolling, search and zt/zz just work.
--
-- Entry point: M.document(buf, avail) -> lines, map, highlights.

local M = {}

local strwidth = vim.api.nvim_strwidth

M.opts = {
  cell_pad = 1,    -- spaces between a cell border and its text
  min_col = 6,     -- a column is never squeezed below this
  page_pad = 2,    -- minimum blank columns on each side of the rendered page
  max_width = 90,  -- longest rendered line; a wider window centres the page
}

-- Highlight groups. The names are ours; each links to the theme's markdown
-- palette where it has one -- catppuccin defines the RenderMarkdown* groups
-- whether or not that plugin is installed -- and to a treesitter group otherwise.
-- M.set_highlights() is idempotent; call it again on ColorScheme.
local LINKS = {
  MdReadH1         = { "RenderMarkdownH1", "@markup.heading.1" },
  MdReadH2         = { "RenderMarkdownH2", "@markup.heading.2" },
  MdReadH3         = { "RenderMarkdownH3", "@markup.heading.3" },
  MdReadH4         = { "RenderMarkdownH4", "@markup.heading.4" },
  MdReadH5         = { "RenderMarkdownH5", "@markup.heading.5" },
  MdReadH6         = { "RenderMarkdownH6", "@markup.heading.6" },
  MdReadTableHead  = { "RenderMarkdownTableHead", "@markup.heading" },
  MdReadTableRow   = { "RenderMarkdownTableRow", "@punctuation.special" },
  MdReadBullet     = { "RenderMarkdownBullet", "@markup.list" },
  MdReadCode       = { "RenderMarkdownCode", "@markup.raw.block" },
  MdReadCodeInline = { "RenderMarkdownCodeInline", "@markup.raw" },
  MdReadBold       = { "@markup.strong" },
  MdReadItalic     = { "@markup.italic" },
  MdReadStrike     = { "@markup.strikethrough" },
  MdReadLink       = { "@markup.link.label" },
}

function M.set_highlights()
  for name, chain in pairs(LINKS) do
    local target = chain[#chain]
    for _, candidate in ipairs(chain) do
      if vim.fn.hlexists(candidate) == 1 then target = candidate; break end
    end
    vim.api.nvim_set_hl(0, name, { link = target })
  end
end

local B = { tl = "╭", tm = "┬", tr = "╮",
            ml = "├", mm = "┼", mr = "┤",
            bl = "╰", bm = "┴", br = "╯",
            v = "│", h = "─" }

-- Split one table row into cells. Honours `\|` escapes and pipes inside code
-- spans of any backtick-run length, which a plain :split on "|" gets wrong.
local function split_row(line)
  local cells, cur = {}, {}
  local i, n, tick = 1, #line, 0
  while i <= n do
    local c = line:sub(i, i)
    if c == "\\" and i < n then
      cur[#cur + 1] = line:sub(i, i + 1)
      i = i + 2
    elseif c == "`" then
      local j = i
      while j <= n and line:sub(j, j) == "`" do j = j + 1 end
      local run = j - i
      if tick == 0 then tick = run elseif tick == run then tick = 0 end
      cur[#cur + 1] = line:sub(i, j - 1)
      i = j
    elseif c == "|" and tick == 0 then
      cells[#cells + 1] = table.concat(cur)
      cur = {}
      i = i + 1
    else
      cur[#cur + 1] = c
      i = i + 1
    end
  end
  cells[#cells + 1] = table.concat(cur)
  -- A leading or trailing pipe yields an empty edge entry that is not a cell.
  if line:match("^%s*|") then table.remove(cells, 1) end
  if #cells > 0 and line:match("|%s*$") then table.remove(cells) end
  return vim.tbl_map(vim.trim, cells)
end

-- Strip inline markup, reporting a highlight span for every construct removed.
-- Byte offsets are into the RETURNED string, so a caller can hand them straight
-- to an extmark. Prose needs this: stripping erases the very markers a syntax
-- highlighter keys on, and without the spans the text comes out flat.
local INLINE_HL = {
  code = "MdReadCodeInline",
  strong = "MdReadBold",
  em = "MdReadItalic",
  strike = "MdReadStrike",
  link = "MdReadLink",
}

local function inline(src)
  local out, spans = {}, {}
  local i, n, at = 1, #src, 0
  local function emit(text, kind)
    out[#out + 1] = text
    if kind then spans[#spans + 1] = { col = at, end_col = at + #text, hl = INLINE_HL[kind] } end
    at = at + #text
  end
  while i <= n do
    local rest = src:sub(i)
    local body, len, kind
    body, len = rest:match("^!?%[([^%]]*)%]%b()()")
    if body then kind = "link" end
    if not body then
      body, len = rest:match("^%[%[([^%]|]*)%]%]()")
      if body then kind = "link" end
    end
    if not body then
      body, len = rest:match("^%[%[([^%]|]*)|[^%]]*%]%]()")
      if body then kind = "link" end
    end
    if not body then
      body, len = rest:match("^(`+[^`]*`+)()")
      if body then body = body:match("^`+(.-)`+$"); kind = "code" end
    end
    if not body then
      body, len = rest:match("^%*%*([^*]*)%*%*()"); if body then kind = "strong" end
    end
    if not body then
      body, len = rest:match("^__([^_]*)__()"); if body then kind = "strong" end
    end
    if not body then
      body, len = rest:match("^%*([^*]+)%*()"); if body then kind = "em" end
    end
    if not body then
      body, len = rest:match("^~~([^~]*)~~()"); if body then kind = "strike" end
    end
    if not body then
      body, len = rest:match("^==([^=]*)==()"); if body then kind = "em" end
    end
    if body then
      emit(body, kind)
      i = i + len - 1
    elseif rest:sub(1, 2) == "\\|" then
      emit("|")
      i = i + 2
    else
      emit(src:sub(i, i))
      i = i + 1
    end
  end
  return table.concat(out), spans
end

-- Reduce inline markup to the text it displays, so a column is measured against
-- what the reader sees. Used for table cells, where the spans are not needed --
-- a cell is re-wrapped independently and coloured as a whole row.
local function plain(s)
  s = s:gsub("!?%[([^%]]*)%]%b()", "%1")
  s = s:gsub("%[%[([^%]|]*)|?[^%]]*%]%]", "%1")
  s = s:gsub("`+([^`]*)`+", "%1")
  s = s:gsub("%*%*([^*]*)%*%*", "%1")
  s = s:gsub("__([^_]*)__", "%1")
  s = s:gsub("%*([^*]*)%*", "%1")
  s = s:gsub("~~([^~]*)~~", "%1")
  s = s:gsub("==([^=]*)==", "%1")
  s = s:gsub("\\|", "|")
  return s
end

local function chars(s)
  local out = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
  return out
end

-- Break the cell into the smallest units a line may start with. Words split on
-- spaces, and each word splits again after / , ; so that long paths and lists
-- break at a meaningful point rather than mid-token.
local function tokens(text)
  local out = {}
  for word in text:gmatch("%S+") do
    local first, part = true, ""
    for _, ch in ipairs(chars(word)) do
      part = part .. ch
      if ch == "/" or ch == "," or ch == ";" then
        out[#out + 1] = { text = part, glue = first and " " or "" }
        first, part = false, ""
      end
    end
    if part ~= "" then out[#out + 1] = { text = part, glue = first and " " or "" } end
  end
  return out
end

local function wrap_cell(text, width)
  if width <= 0 then return { "" } end
  local items = tokens(text)
  if #items == 0 then return { "" } end
  local lines, cur = {}, ""
  for _, item in ipairs(items) do
    local glue = cur == "" and "" or item.glue
    local cand = cur .. glue .. item.text
    if strwidth(cand) <= width then
      cur = cand
    else
      if cur ~= "" then lines[#lines + 1] = cur end
      cur = ""
      -- A single token wider than the column has no break point; split it on
      -- character boundaries so the border still lines up.
      local rest = item.text
      while strwidth(rest) > width do
        local take = ""
        for _, ch in ipairs(chars(rest)) do
          if strwidth(take .. ch) > width then break end
          take = take .. ch
        end
        if take == "" then break end
        lines[#lines + 1] = take
        rest = rest:sub(#take + 1)
      end
      cur = rest
    end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return #lines > 0 and lines or { "" }
end

-- Shrink the widest column one cell at a time until the table fits. Widest-first
-- keeps narrow columns (ids, flags, short enums) at their natural width.
local function allocate(natural, avail)
  local n = #natural
  local chrome = (n + 1) + M.opts.cell_pad * 2 * n
  local widths = vim.deepcopy(natural)
  local function total()
    local t = chrome
    for _, w in ipairs(widths) do t = t + w end
    return t
  end
  while total() > avail do
    local best, idx = M.opts.min_col, nil
    for i, w in ipairs(widths) do
      if w > best then best, idx = w, i end
    end
    if not idx then break end
    widths[idx] = widths[idx] - 1
  end
  return widths
end

local function border(widths, l, m, r, fill)
  fill = fill or B.h
  local parts = { l }
  for i, w in ipairs(widths) do
    parts[#parts + 1] = string.rep(fill, w + M.opts.cell_pad * 2)
    parts[#parts + 1] = (i == #widths) and r or m
  end
  return table.concat(parts)
end

-- A rule between data rows. Once cells wrap onto two or three lines it stops
-- being obvious where one row ends, which is the whole point of the wrap.
local function row_rule(widths)
  return border(widths, B.ml, B.mm, B.mr, B.h)
end

local function row_lines(cells, widths, aligns)
  local wrapped, height = {}, 1
  for i, w in ipairs(widths) do
    wrapped[i] = wrap_cell(plain(cells[i] or ""), w)
    height = math.max(height, #wrapped[i])
  end
  local out = {}
  for li = 1, height do
    local parts = { B.v }
    for i, w in ipairs(widths) do
      local text = wrapped[i][li] or ""
      local slack = math.max(0, w - strwidth(text))
      local left, right
      local align = aligns[i] or "left"
      if align == "right" then
        left, right = slack, 0
      elseif align == "center" then
        left = math.floor(slack / 2)
        right = slack - left
      else
        left, right = 0, slack
      end
      parts[#parts + 1] = string.rep(" ", M.opts.cell_pad + left) .. text
        .. string.rep(" ", right + M.opts.cell_pad)
      parts[#parts + 1] = B.v
    end
    out[li] = table.concat(parts)
  end
  return out
end

local function alignment(cell)
  local left = cell:match("^:") ~= nil
  local right = cell:match(":$") ~= nil
  if left and right then return "center" end
  if right then return "right" end
  return "left"
end

-- Parsed on first use, not at load: this module is required before lazy.nvim
-- runs, so nvim-treesitter's markdown queries are not on the runtimepath yet.
local query
local function table_query()
  if not query then
    -- Only a success is cached. The first render can happen before lazy.nvim has
    -- the treesitter queries on the runtimepath, and remembering that failure
    -- would leave every table unrendered for the rest of the session.
    local ok, q = pcall(vim.treesitter.query.parse, "markdown", "(pipe_table) @table")
    query = ok and q or nil
  end
  return query
end

-- Everything needed to draw one table, computed once and shared by both consumers.
local function layout(buf, node, avail)
  local rows, delim_idx = {}, nil
  for child in node:iter_children() do
    local kind = child:type()
    if kind == "pipe_table_header" or kind == "pipe_table_row" or kind == "pipe_table_delimiter_row" then
      local lnum = child:range()
      local line = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1]
      if line then
        rows[#rows + 1] = { lnum = lnum, cells = split_row(line), delim = kind == "pipe_table_delimiter_row" }
        if kind == "pipe_table_delimiter_row" then delim_idx = #rows end
      end
    end
  end
  if not delim_idx then return nil end

  local ncols = #rows[delim_idx].cells
  local aligns = vim.tbl_map(alignment, rows[delim_idx].cells)
  local natural = {}
  for i = 1, ncols do natural[i] = M.opts.min_col end
  for _, row in ipairs(rows) do
    if not row.delim then
      for i = 1, ncols do
        natural[i] = math.max(natural[i], strwidth(plain(row.cells[i] or "")))
      end
    end
  end
  local widths = allocate(natural, avail)

  local rendered = {}
  for ri, row in ipairs(rows) do
    rendered[ri] = (not row.delim)
      and row_lines(row.cells, widths, aligns)
      or { border(widths, B.ml, B.mm, B.mr) }
  end
  return { rows = rows, delim_idx = delim_idx, widths = widths, rendered = rendered }
end

-- The table as a flat list of lines, borders and rules included.
---@return string[] lines, integer head_lines  count of leading header-coloured lines
local function flatten(lo)
  local out = {}
  local head_lines = 0
  out[#out + 1] = border(lo.widths, B.tl, B.tm, B.tr)
  for ri = 1, #lo.rows do
    vim.list_extend(out, lo.rendered[ri])
    if ri <= lo.delim_idx then head_lines = #out end
    -- A rule between every pair of body rows. The delimiter row already draws
    -- the one under the header, hence ri > delim_idx.
    if ri > lo.delim_idx and ri < #lo.rows then
      out[#out + 1] = row_rule(lo.widths)
    end
  end
  out[#out + 1] = border(lo.widths, B.bl, B.bm, B.br)
  return out, head_lines
end

-- ---------------------------------------------------------------------------
-- The document: headings, prose and lists around the tables laid out above.

M.heading_icons = { "󰲡", "󰲣", "󰲥", "󰲧", "󰲩", "󰲫" }

-- Wrap `text` to `width`, carrying `spans` (byte ranges from inline()) across the
-- breaks. Highlight is tracked per byte rather than by clipping ranges, because a
-- wrapped line is rebuilt from words and its bytes do not line up with the source.
---@return string[] lines, table[][] spans  one span list per output line
local function wrap_hl(text, spans, width)
  if width < 1 then width = 1 end
  local at = {}
  for _, sp in ipairs(spans) do
    for b = sp.col + 1, sp.end_col do at[b] = sp.hl end
  end

  local words, i = {}, 1
  while true do
    local a, b = text:find("%S+", i)
    if not a then break end
    words[#words + 1] = { text = text:sub(a, b), pos = a }
    i = b + 1
  end

  local out, marks = {}, {}
  local cur, cur_marks
  local function flush()
    if cur then out[#out + 1] = cur; marks[#marks + 1] = cur_marks; cur, cur_marks = nil, nil end
  end
  local function put(str, pos)
    local base = #cur
    cur = cur .. str
    for j = 1, #str do cur_marks[base + j] = at[pos + j - 1] end
  end

  for _, w in ipairs(words) do
    if cur and strwidth(cur .. " " .. w.text) <= width then
      cur = cur .. " "
      put(w.text, w.pos)
    else
      flush()
      -- Prose breaks on whitespace only. A token too wide for the line has no
      -- break point, so split it on character boundaries as a last resort.
      local rest, rpos = w.text, w.pos
      while strwidth(rest) > width do
        local take = ""
        for _, ch in ipairs(chars(rest)) do
          if strwidth(take .. ch) > width then break end
          take = take .. ch
        end
        if take == "" then break end
        cur, cur_marks = "", {}
        put(take, rpos)
        flush()
        rpos, rest = rpos + #take, rest:sub(#take + 1)
      end
      cur, cur_marks = "", {}
      put(rest, rpos)
    end
  end
  flush()
  if #out == 0 then out, marks = { "" }, { {} } end

  local per_line = {}
  for k, line in ipairs(out) do
    local sp, m, b = {}, marks[k], 1
    while b <= #line do
      local hl = m[b]
      if hl then
        local e = b
        while e < #line and m[e + 1] == hl do e = e + 1 end
        sp[#sp + 1] = { col = b - 1, end_col = e, hl = hl }
        b = e + 1
      else
        b = b + 1
      end
    end
    per_line[k] = sp
  end
  return out, per_line
end

-- A line that cannot be swallowed into the paragraph above it.
local function is_break(line)
  if line == nil then return true end
  return line:match("^%s*$") ~= nil
    or line:match("^#+%s") ~= nil
    or line:match("^%s*```") ~= nil
    or line:match("^%s*<") ~= nil
    or line:match("^%s*>") ~= nil
    or line:match("^%s*[%-%*%+]%s") ~= nil
    or line:match("^%s*%d+[%.%)]%s") ~= nil
    or line:match("^%s*|") ~= nil
    or line:match("^%s*[%-=_]%s*[%-=_]%s*[%-=_][%s%-=_]*$") ~= nil
end

-- Split a paragraph's first line into the marker that starts it, the indent its
-- continuation lines get, and the text itself.
local function paragraph_head(line)
  local indent, _, rest = line:match("^(%s*)([%-%*%+])%s+(.*)$")
  local marker
  if indent then
    return indent .. "● ", indent .. "  ", rest, #indent
  end
  indent, marker, rest = line:match("^(%s*)(%d+[%.%)])%s+(.*)$")
  if indent then
    return indent .. marker .. " ", indent .. string.rep(" ", #marker + 1), rest
  end
  indent, rest = line:match("^(%s*)(.*)$")
  return indent, indent, rest
end

-- No per-level indent: the icon already says which level this is, and indenting
-- headings while prose and tables stay put makes the left edge zigzag.
local function render_heading(line)
  local hashes, title = line:match("^(#+)%s+(.*)$")
  if not hashes or #hashes > 6 then return nil end
  return M.heading_icons[#hashes] .. " " .. title
end

-- Render a whole buffer into plain lines for a read-only mirror: tables fitted to
-- `avail`, prose re-flowed to it, everything inset by M.opts.page_pad columns.
---@return string[] lines
---@return table<integer,integer> map  src_lnum1 -> reader_lnum1
---@return table[] hls  highlight-only spans {line, col, end_col, hl, eol}
function M.document(buf, avail)
  -- Inset the page. Past max_width the extra room becomes margin rather than
  -- longer lines, so a wide window centres a readable measure instead of running
  -- prose edge to edge.
  local text_w = math.max(20, math.min(avail - 2 * M.opts.page_pad, M.opts.max_width))
  local pad = string.rep(" ", math.max(M.opts.page_pad, math.floor((avail - text_w) / 2)))

  local src = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local repl = {}
  local q = table_query()
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if ok and parser and q then
    local tree = parser:parse()[1]
    if tree then
      for _, node in q:iter_captures(tree:root(), buf) do
        local lo = layout(buf, node, text_w)
        if lo then
          local tl, head_lines = flatten(lo)
          repl[lo.rows[1].lnum] = { last = lo.rows[#lo.rows].lnum, lines = tl, head_lines = head_lines }
        end
      end
    end
  end

  local out, map, hls = {}, {}, {}
  local function emit(text, hl, eol)
    out[#out + 1] = (text == "") and "" or (pad .. text)
    if hl then
      hls[#hls + 1] = { line = #out, col = #pad, hl = hl, eol = eol }
    end
    return #out
  end

  local i = 0
  while i < #src do
    local r = repl[i]
    if r then
      local first = #out + 1
      for n, tl in ipairs(r.lines) do
        emit(tl, n <= r.head_lines and "MdReadTableHead" or "MdReadTableRow")
      end
      for l = i, r.last do map[l + 1] = first end
      i = r.last + 1
    else
      local line = src[i + 1]
      if line:match("^%s*```") then
        -- Code blocks are verbatim: no re-flow, no markup stripping.
        local first = emit(line, "MdReadCode", true)
        map[i + 1] = first
        i = i + 1
        while i < #src do
          local l = src[i + 1]
          map[i + 1] = emit(l, "MdReadCode", true)
          i = i + 1
          if l:match("^%s*```") then break end
        end
      elseif line:match("^%s*<!%-%-") then
        -- HTML comments are instructions to other tools -- toc markers, prettier
        -- pragmas, linter pragmas. They are not part of the document being read,
        -- so the reader drops them; the source line still maps to whatever comes
        -- next, so a toggle from here lands somewhere sensible.
        local nxt = #out + 1
        repeat
          map[i + 1] = nxt
          local done = src[i + 1]:find("%-%->")
          i = i + 1
        until done or i >= #src
      elseif line:match("^%s*$") then
        -- One blank line is a separator; a run of them is just source formatting,
        -- and a dropped comment or a stripped block would otherwise leave a hole.
        if #out > 0 and out[#out] ~= "" then
          map[i + 1] = emit("")
        else
          map[i + 1] = math.max(#out, 1)
        end
        i = i + 1
      else
        local head = render_heading(line)
        if head then
          map[i + 1] = emit(head, "MdReadH" .. math.min(#line:match("^(#+)"), 6))
          i = i + 1
        else
          local prefix, hang, body, bullet_at = paragraph_head(line)
          -- Join the paragraph before wrapping it. Wrapping each source line on
          -- its own re-breaks text that is already hard-wrapped at some other
          -- width, which leaves one-word tails on every line.
          local j = i + 1
          while j < #src and not repl[j] and not is_break(src[j + 1]) do
            body = body .. " " .. src[j + 1]:gsub("^%s+", "")
            j = j + 1
          end

          local text, spans = inline(body)
          local wrapped, per_line = wrap_hl(text, spans, text_w - strwidth(prefix))
          local first = #out + 1
          for k, wl in ipairs(wrapped) do
            local p = (k == 1) and prefix or hang
            out[#out + 1] = pad .. p .. wl
            local shift = #pad + #p
            for _, sp in ipairs(per_line[k]) do
              hls[#hls + 1] = { line = #out, col = shift + sp.col, end_col = shift + sp.end_col, hl = sp.hl }
            end
            if k == 1 and bullet_at then
              hls[#hls + 1] = { line = #out, col = #pad + bullet_at,
                                end_col = #pad + bullet_at + #"●", hl = "MdReadBullet" }
            end
          end
          for l = i, j - 1 do map[l + 1] = first end
          i = j
        end
      end
    end
  end
  return out, map, hls
end

return M
