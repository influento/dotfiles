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
  -- Table and list groups prefer the treesitter capture the raw buffer is
  -- coloured by, so the same document does not change colour when it is toggled:
  -- a header cell is @markup.heading there and the pipes @punctuation.special.
  MdReadTableHead   = { "@markup.heading.markdown", "RenderMarkdownTableHead" },
  MdReadTableBorder = { "@punctuation.special.markdown", "@punctuation.special" },
  MdReadBullet      = { "@markup.list.markdown", "@markup.list" },
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
  -- A terminal cell has one size, so the top of the hierarchy is drawn rather
  -- than scaled: H1 is a filled bar in the heading's own colour. Derived from the
  -- theme every time, so it follows a colourscheme change like everything else.
  -- Inline code takes its foreground from the raw buffer's own group and keeps
  -- the reader's background box: the same green, still visibly a code span.
  local raw = vim.api.nvim_get_hl(0, { name = "@markup.raw.markdown_inline", link = false })
  local box = vim.api.nvim_get_hl(0, { name = "RenderMarkdownCodeInline", link = false })
  if raw.fg and box.bg then
    vim.api.nvim_set_hl(0, "MdReadCodeInline", { fg = raw.fg, bg = box.bg })
  end

  local h1 = vim.api.nvim_get_hl(0, { name = "MdReadH1", link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  vim.api.nvim_set_hl(0, "MdReadH1Bar", (h1.fg and normal.bg)
    and { fg = normal.bg, bg = h1.fg, bold = true }
    or { link = "MdReadH1" })
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
  local out, i = {}, 1
  while true do
    local a, b = text:find("%S+", i)
    if not a then break end
    local first, part, at = true, "", a
    for _, ch in ipairs(chars(text:sub(a, b))) do
      part = part .. ch
      if ch == "/" or ch == "," or ch == ";" then
        out[#out + 1] = { text = part, pos = at, glue = first and " " or "" }
        first, at, part = false, at + #part, ""
      end
    end
    if part ~= "" then out[#out + 1] = { text = part, pos = at, glue = first and " " or "" } end
    i = b + 1
  end
  return out
end

-- Whitespace-only units, for prose.
local function words(text)
  local out, i = {}, 1
  while true do
    local a, b = text:find("%S+", i)
    if not a then break end
    out[#out + 1] = { text = text:sub(a, b), pos = a, glue = " " }
    i = b + 1
  end
  return out
end

-- The one wrapping engine, shared by prose and by table cells. `items` are the
-- smallest units a line may start with -- each carrying its byte position in the
-- source text and the glue that joins it to the one before -- and `at` maps a
-- 1-based byte of that text to a highlight group. Highlight is tracked per byte
-- rather than by clipping ranges, because a wrapped line is rebuilt from pieces
-- whose bytes no longer line up with the source.
---@return string[] lines, table[][] spans  one span list per output line
local function wrap_marked(items, at, width)
  if width < 1 then width = 1 end
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

  for _, it in ipairs(items) do
    local glue = (cur and cur ~= "") and it.glue or ""
    if cur and strwidth(cur .. glue .. it.text) <= width then
      cur = cur .. glue
      put(it.text, it.pos)
    else
      flush()
      -- A unit wider than the line has no break point of its own, so split it on
      -- character boundaries as a last resort. In a table this is what keeps the
      -- border aligned.
      local rest, rpos = it.text, it.pos
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

local function marks_of(spans)
  local at = {}
  for _, sp in ipairs(spans) do
    for b = sp.col + 1, sp.end_col do at[b] = sp.hl end
  end
  return at
end

-- One table cell, wrapped. `base` colours whatever the inline markup did not
-- claim, so a header cell comes out one colour with its code spans and links
-- still standing out -- the per-byte map settles the overlap, so no extmark
-- priority is involved.
local function wrap_cell(src, width, base)
  local text, spans = inline(src)
  local at = marks_of(spans)
  if base then
    for b = 1, #text do if at[b] == nil then at[b] = base end end
  end
  return wrap_marked(tokens(text), at, width)
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

-- One table row: the rendered lines, and for each the highlight spans. Columns
-- are byte offsets built up as the line is assembled -- never computed from
-- display width, which the box-drawing glyphs and the icons do not agree with.
---@return string[] lines, table[][] spans
local function row_lines(cells, widths, aligns, base)
  local wrapped, spans, height = {}, {}, 1
  for i, w in ipairs(widths) do
    wrapped[i], spans[i] = wrap_cell(cells[i] or "", w, base)
    height = math.max(height, #wrapped[i])
  end
  local out, hls = {}, {}
  for li = 1, height do
    local line = B.v
    local sp = { { col = 0, end_col = #B.v, hl = "MdReadTableBorder" } }
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
      line = line .. string.rep(" ", M.opts.cell_pad + left)
      local at = #line
      line = line .. text .. string.rep(" ", right + M.opts.cell_pad)
      for _, c in ipairs(spans[i][li] or {}) do
        sp[#sp + 1] = { col = at + c.col, end_col = at + c.end_col, hl = c.hl }
      end
      sp[#sp + 1] = { col = #line, end_col = #line + #B.v, hl = "MdReadTableBorder" }
      line = line .. B.v
    end
    out[li], hls[li] = line, sp
  end
  return out, hls
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
        -- Measured with the same function that renders it. Two implementations
        -- of "what does this cell display" that disagree by one column would
        -- misalign every border below it.
        natural[i] = math.max(natural[i], strwidth((inline(row.cells[i] or ""))))
      end
    end
  end
  local widths = allocate(natural, avail)

  local rendered, hls = {}, {}
  for ri, row in ipairs(rows) do
    if row.delim then
      local line = border(widths, B.ml, B.mm, B.mr)
      rendered[ri] = { line }
      hls[ri] = { { { col = 0, end_col = #line, hl = "MdReadTableBorder" } } }
    else
      rendered[ri], hls[ri] =
        row_lines(row.cells, widths, aligns, ri < delim_idx and "MdReadTableHead" or nil)
    end
  end
  return { rows = rows, delim_idx = delim_idx, widths = widths, rendered = rendered, hls = hls }
end

-- The table as a flat list of lines, borders and rules included, with the
-- highlight spans for each. Line numbers are relative to the table.
---@return string[] lines, table[] hls  {line, col, end_col, hl}
local function flatten(lo)
  local out, hls = {}, {}
  local function add(line, sp)
    out[#out + 1] = line
    for _, c in ipairs(sp) do
      hls[#hls + 1] = { line = #out, col = c.col, end_col = c.end_col, hl = c.hl }
    end
  end
  local function rule(line)
    add(line, { { col = 0, end_col = #line, hl = "MdReadTableBorder" } })
  end

  rule(border(lo.widths, B.tl, B.tm, B.tr))
  for ri = 1, #lo.rows do
    for li, line in ipairs(lo.rendered[ri]) do add(line, lo.hls[ri][li]) end
    -- A rule between every pair of body rows. The delimiter row already draws the
    -- one under the header, hence ri > delim_idx.
    if ri > lo.delim_idx and ri < #lo.rows then rule(row_rule(lo.widths)) end
  end
  rule(border(lo.widths, B.bl, B.bm, B.br))
  return out, hls
end

-- ---------------------------------------------------------------------------
-- The document: headings, prose and lists around the tables laid out above.

M.heading_icons = { "󰲡", "󰲣", "󰲥", "󰲧", "󰲩", "󰲫" }

-- Prose: the same engine, with whitespace as the only break point.
local function wrap_hl(text, spans, width)
  return wrap_marked(words(text), marks_of(spans), width)
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
-- A heading is one or more rendered lines plus the highlight for each. Levels 1-3
-- carry weight the font cannot: a filled bar, a full-width rule, a rule the width
-- of the title. Below that the icon and the theme's own colour are the whole cue.
---@return table[]|nil  { {text, hl}, ... }
local function render_heading(line, text_w)
  local hashes, title = line:match("^(#+)%s+(.*)$")
  if not hashes or #hashes > 6 then return nil end
  local level = #hashes
  local head = M.heading_icons[level] .. " " .. plain(title)
  local hl = "MdReadH" .. level

  if level == 1 then
    -- Padded to the page width so the bar runs margin to margin. Not hl_eol: the
    -- colour has to stop at the text column, not run off into the window.
    return { { text = head .. string.rep(" ", math.max(0, text_w - strwidth(head))),
               hl = "MdReadH1Bar" } }
  elseif level == 2 then
    return { { text = head, hl = hl }, { text = string.rep("─", text_w), hl = hl } }
  elseif level == 3 then
    return { { text = head, hl = hl }, { text = string.rep("─", strwidth(head)), hl = hl } }
  end
  return { { text = head, hl = hl } }
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
          local tl, thls = flatten(lo)
          repl[lo.rows[1].lnum] = { last = lo.rows[#lo.rows].lnum, lines = tl, hls = thls }
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
      for _, tl in ipairs(r.lines) do out[#out + 1] = pad .. tl end
      for _, c in ipairs(r.hls) do
        hls[#hls + 1] = { line = first + c.line - 1, col = #pad + c.col,
                          end_col = #pad + c.end_col, hl = c.hl }
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
        local head = render_heading(line, text_w)
        if head then
          for n, part in ipairs(head) do
            local at = emit(part.text, part.hl)
            if n == 1 then map[i + 1] = at end
          end
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
