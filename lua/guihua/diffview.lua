local api = vim.api
local class = require('middleclass')
local TextView = require('guihua.textview')
local util = require('guihua.util')
local log = require('guihua.log').info

local DiffView = class('DiffView', TextView)
local ns_id = api.nvim_create_namespace('guihua_diffview')
local DEFAULT_CLOSE_KEYMAP = '<C-c>'

-- DiffView opts:
--   title            Border title. Appends the close keymap when enabled.
--   description      Optional intro lines shown before the diff body.
--   diff             Unified diff text (git diff / diff -u).
--   syntax           Optional syntax highlighter for diff body lines.
--   close_keymap     Buffer-local close key, default <C-c>. Set false to disable.
--   autoclose        Neovim event name(s): string, list, or { events = {...}, timeout = ms }.
--                    Use { focus_moved = true } as shorthand for WinLeave/BufLeave.

local function split_lines(text)
  if type(text) == 'table' then
    return vim.deepcopy(text)
  end
  if type(text) ~= 'string' then
    return {}
  end
  return vim.split(text, '\n', { plain = true })
end

local function strwidth(text)
  return vim.fn.strdisplaywidth(text or '')
end

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(value, max_value))
end

local function unique_list(items)
  local seen = {}
  local out = {}
  for _, item in ipairs(items or {}) do
    if item ~= nil and item ~= '' and not seen[item] then
      seen[item] = true
      out[#out + 1] = item
    end
  end
  return out
end

local function normalize_autoclose(opts)
  local autoclose = opts.autoclose
  local events = {}
  if autoclose == true then
    autoclose = { events = { 'WinLeave' } }
  end
  if type(autoclose) == 'string' then
    autoclose = { events = { autoclose } }
  end
  if type(autoclose) ~= 'table' then
    autoclose = {}
  end
  if type(autoclose.events) == 'string' then
    events = { autoclose.events }
  elseif type(autoclose.events) == 'table' then
    events = vim.deepcopy(autoclose.events)
  elseif autoclose[1] ~= nil then
    events = vim.deepcopy(autoclose)
  end
  if opts.autoclose_focus_moved ~= nil then
    autoclose.focus_moved = opts.autoclose_focus_moved
  end
  if opts.autoclose_timeout ~= nil then
    autoclose.timeout = opts.autoclose_timeout
  end
  if autoclose.focus_moved then
    events[#events + 1] = 'WinLeave'
    events[#events + 1] = 'BufLeave'
  end
  autoclose.events = unique_list(events)
  return autoclose
end

local function build_title(opts)
  local base = opts.title or 'Diff'
  local close_keymap = opts.close_keymap
  if close_keymap == nil then
    close_keymap = DEFAULT_CLOSE_KEYMAP
  end
  if close_keymap == false or close_keymap == '' then
    return base
  end
  return base .. '  ' .. close_keymap
end

local function get_hl_def(group_name)
  if vim.api.nvim_get_hl ~= nil then
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group_name, link = false })
    if ok and type(hl) == 'table' then
      return vim.tbl_extend('force', {}, hl)
    end
  end

  local ok, hl = pcall(vim.api.nvim_get_hl_by_name, group_name, true)
  if not ok or type(hl) ~= 'table' then
    return {}
  end

  local normalized = {
    fg = hl.foreground,
    bg = hl.background,
    sp = hl.special,
  }
  for _, key in ipairs({ 'bold', 'italic', 'reverse', 'standout', 'underline', 'undercurl', 'nocombine' }) do
    if hl[key] ~= nil then
      normalized[key] = hl[key]
    end
  end
  return normalized
end

local function is_diff_header(line)
  return line:match('^diff%s') ~= nil
    or line:match('^index%s') ~= nil
    or line:match('^@@') ~= nil
    or line:match('^---%s') ~= nil
    or line:match('^%+%+%+%s') ~= nil
    or line:match('^new file') ~= nil
    or line:match('^deleted file') ~= nil
end

local function tokenize(line)
  local tokens = {}
  local start = 1
  while start <= #line do
    local s, e = line:find('%S+', start)
    if not s then
      break
    end
    tokens[#tokens + 1] = {
      text = line:sub(s, e),
      start_col = s - 1,
      end_col = e,
    }
    start = e + 1
  end
  return tokens
end

local function has_visible_bg(hl)
  return hl ~= nil and hl.bg ~= nil
end

local function setup_diff_highlights(ns)
  local add = get_hl_def('DiffAdd')
  local del = get_hl_def('DiffDelete')
  local change = get_hl_def('DiffChange')

  if not has_visible_bg(add) then
    add = {
      fg = 0xd7ffcf,
      bg = 0x1f3b24,
      bold = true,
      default = true,
    }
  end
  if not has_visible_bg(del) then
    del = {
      fg = 0xffd7d7,
      bg = 0x3b1f1f,
      bold = true,
      default = true,
    }
  end
  if not has_visible_bg(change) then
    change = {
      fg = 0xffffff,
      bg = 0x4b3b1f,
      bold = true,
      default = true,
    }
  else
    change.bold = true
    change.underline = true
  end

  api.nvim_set_hl(ns, 'GuihuaDiffAdd', add)
  api.nvim_set_hl(ns, 'GuihuaDiffDelete', del)
  api.nvim_set_hl(ns, 'GuihuaDiffChange', change)
  api.nvim_set_hl(ns, 'GuihuaDiffDescription', {
    fg = add.fg or del.fg or 0xd0d0d0,
    bg = 0x242424,
    bold = true,
    italic = true,
    default = true,
  })
  api.nvim_set_hl(ns, 'GuihuaDiffHeader', {
    fg = 0xc0c0c0,
    bg = 0x1e1e1e,
    bold = true,
    default = true,
  })
end

local function token_diff_ranges(old_line, new_line)
  local old_tokens = tokenize(old_line)
  local new_tokens = tokenize(new_line)
  if #old_tokens == 0 or #new_tokens == 0 then
    return {}, {}, old_tokens, new_tokens
  end

  local old_texts = {}
  local new_texts = {}
  for i, token in ipairs(old_tokens) do
    old_texts[i] = token.text
  end
  for i, token in ipairs(new_tokens) do
    new_texts[i] = token.text
  end

  local ok, hunks = pcall(vim.text.diff, table.concat(old_texts, '\n'), table.concat(new_texts, '\n'), {
    result_type = 'indices',
  })
  if not ok or type(hunks) ~= 'table' then
    return {}, {}, old_tokens, new_tokens
  end

  local old_ranges = {}
  local new_ranges = {}
  for _, hunk in ipairs(hunks) do
    local start_a, count_a, start_b, count_b = hunk[1], hunk[2], hunk[3], hunk[4]
    if count_a and count_a > 0 then
      old_ranges[#old_ranges + 1] = { start_a, start_a + count_a - 1 }
    end
    if count_b and count_b > 0 then
      new_ranges[#new_ranges + 1] = { start_b, start_b + count_b - 1 }
    end
  end
  return old_ranges, new_ranges, old_tokens, new_tokens
end

local function flatten_ranges(buf, ranges, tokens, hl, line_nr)
  for _, range in ipairs(ranges) do
    for i = range[1], range[2] do
      local token = tokens[i]
      if token then
        api.nvim_buf_set_extmark(buf, ns_id, line_nr, token.start_col, {
          end_col = token.end_col,
          hl_group = hl,
          hl_mode = 'combine',
          priority = 1800,
        })
      end
    end
  end
end

local function parse_diff_lines(lines)
  local entries = {}
  for _, line in ipairs(lines) do
    local kind = 'context'
    local text = line
    if is_diff_header(line) then
      kind = 'header'
    elseif line:match('^-%-%-%s') or line:match('^%+%+%+%s') then
      kind = 'header'
    elseif line:sub(1, 1) == '-' and not line:match('^%-{3}%s') then
      kind = 'delete'
      text = line:sub(2)
    elseif line:sub(1, 1) == '+' and not line:match('^%+%+%+%s') then
      kind = 'add'
      text = line:sub(2)
    elseif line:sub(1, 1) == ' ' then
      text = line:sub(2)
    end
    entries[#entries + 1] = {
      kind = kind,
      text = text,
      raw = line,
    }
  end
  return entries
end

local function add_description(entries, description)
  if description == nil or description == '' then
    return entries
  end
  local desc_lines = split_lines(description)
  local output = {}
  for _, line in ipairs(desc_lines) do
    output[#output + 1] = { kind = 'description', text = line, raw = line }
  end
  output[#output + 1] = { kind = 'description', text = '', raw = '' }
  for _, entry in ipairs(entries) do
    output[#output + 1] = entry
  end
  return output
end

local function compute_pairs(entries)
  local i = 1
  while i <= #entries do
    if entries[i].kind ~= 'delete' and entries[i].kind ~= 'add' then
      i = i + 1
    else
      local run_start = i
      while i <= #entries and (entries[i].kind == 'delete' or entries[i].kind == 'add') do
        i = i + 1
      end
      local deletes = {}
      local adds = {}
      for j = run_start, i - 1 do
        if entries[j].kind == 'delete' then
          deletes[#deletes + 1] = j
        else
          adds[#adds + 1] = j
        end
      end
      local pair_count = math.min(#deletes, #adds)
      for p = 1, pair_count do
        entries[deletes[p]].pair = adds[p]
        entries[adds[p]].pair = deletes[p]
      end
    end
  end
end

local function render_entries(entries)
  local lines = {}
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = entry.text
    entry.line_nr = #lines
  end
  return lines
end

local function compute_width(opts, lines)
  local columns = api.nvim_get_option_value('columns', {})
  local width = opts.width or 0
  for _, line in ipairs(lines) do
    width = math.max(width, strwidth(line) + 4)
  end
  if opts.title then
    width = math.max(width, strwidth(opts.title) + 8)
  end
  if opts.description then
    for _, line in ipairs(split_lines(opts.description)) do
      width = math.max(width, strwidth(line) + 4)
    end
  end
  return clamp(width > 0 and width or math.floor(columns * 0.9), 40, math.max(40, columns - 4))
end

local function compute_height(opts, lines)
  local screen_h = api.nvim_get_option_value('lines', {})
  local wanted = #lines + 2
  return clamp(opts.height or wanted, 4, math.max(4, screen_h - 6))
end

local function apply_annotations(view, entries)
  if view == nil or view.buf == nil or not api.nvim_buf_is_valid(view.buf) then
    return
  end
  api.nvim_buf_clear_namespace(view.buf, ns_id, 0, -1)
  api.nvim_set_option_value('signcolumn', 'yes:1', { win = view.win })

  for _, entry in ipairs(entries) do
    if entry.kind == 'description' then
      api.nvim_buf_set_extmark(view.buf, ns_id, entry.line_nr - 1, 0, {
        hl_group = 'Title',
        end_col = #entry.raw,
        priority = 600,
      })
    elseif entry.kind == 'header' then
      api.nvim_buf_set_extmark(view.buf, ns_id, entry.line_nr - 1, 0, {
        hl_group = 'Comment',
        end_col = #entry.raw,
        priority = 600,
      })
    elseif entry.kind == 'delete' then
      api.nvim_buf_set_extmark(view.buf, ns_id, entry.line_nr - 1, 0, {
        line_hl_group = 'GuihuaDiffDelete',
        hl_eol = true,
        priority = 1200,
      })
      api.nvim_buf_set_extmark(view.buf, ns_id, entry.line_nr - 1, 0, {
        sign_text = '-',
        sign_hl_group = 'GuihuaDiffDelete',
        priority = 1300,
      })
    elseif entry.kind == 'add' then
      api.nvim_buf_set_extmark(view.buf, ns_id, entry.line_nr - 1, 0, {
        line_hl_group = 'GuihuaDiffAdd',
        hl_eol = true,
        priority = 1200,
      })
      api.nvim_buf_set_extmark(view.buf, ns_id, entry.line_nr - 1, 0, {
        sign_text = '+',
        sign_hl_group = 'GuihuaDiffAdd',
        priority = 1300,
      })
    end
  end

  for _, entry in ipairs(entries) do
    if entry.kind == 'delete' and entry.pair then
      local other = entries[entry.pair]
      if other then
        local old_ranges, new_ranges, old_tokens, new_tokens = token_diff_ranges(entry.text, other.text)
        flatten_ranges(view.buf, old_ranges, old_tokens, 'GuihuaDiffChange', entry.line_nr - 1)
        flatten_ranges(view.buf, new_ranges, new_tokens, 'GuihuaDiffChange', other.line_nr - 1)
      end
    end
  end
end

local function normalize_opts(opts)
  opts = vim.deepcopy(opts or {})
  local entries = parse_diff_lines(split_lines(opts.diff or opts.data or ''))
  entries = add_description(entries, opts.description)
  compute_pairs(entries)
  local lines = render_entries(entries)
  opts.autoclose = normalize_autoclose(opts)
  opts.data = lines
  opts.entries = entries
  opts.syntax = opts.syntax
  opts.ft = opts.ft or nil
  opts.loc = opts.loc or 'none'
  opts.relative = opts.relative or 'cursor'
  opts.border = opts.border or 'rounded'
  opts.enter = opts.enter or false
  opts.title = build_title(opts)
  opts.rect = opts.rect or {
    width = compute_width(opts, lines),
    height = compute_height(opts, lines),
  }
  return opts
end

function DiffView:initialize(...)
  local opts = normalize_opts(select(1, ...) or {})
  TextView.initialize(self, opts)
  self.ns = api.nvim_create_namespace('guihua_diffview_window')
  setup_diff_highlights(self.ns)
  api.nvim_set_hl(self.ns, '@error', {})
  api.nvim_win_set_hl_ns(self.win, self.ns)
  api.nvim_set_option_value('wrap', true, { win = self.win })
  api.nvim_set_option_value('linebreak', true, { win = self.win })
  api.nvim_set_option_value('cursorline', false, { win = self.win })
  api.nvim_set_option_value('cursorcolumn', false, { win = self.win })
  api.nvim_set_option_value('signcolumn', 'yes:1', { win = self.win })
  apply_annotations(self, opts.entries or {})
  local closed = false
  local base_close = self.close
  local function close_view()
    if closed then
      return
    end
    closed = true
    if base_close ~= nil then
      base_close(self)
    end
  end
  self.close = close_view

  local close_keymap = opts.close_keymap
  if close_keymap == nil then
    close_keymap = DEFAULT_CLOSE_KEYMAP
  end
  if close_keymap ~= false and close_keymap ~= '' then
    vim.keymap.set({ 'n', 'i' }, close_keymap, close_view, { buffer = self.buf, silent = true, noremap = true })
  end

  local aug = api.nvim_create_augroup('GuihuaDiffView' .. tostring(self.win), { clear = true })
  if opts.autoclose and opts.autoclose.events and #opts.autoclose.events > 0 then
    api.nvim_create_autocmd(opts.autoclose.events, {
      group = aug,
      buffer = self.buf,
      callback = close_view,
    })
  end
  if opts.autoclose and opts.autoclose.timeout then
    vim.defer_fn(function()
      if not closed then
        close_view()
      end
    end, opts.autoclose.timeout)
  end
  if opts.syntax then
    util.highlighter(self.buf, opts.syntax, opts.lnum)
  end
  return self
end

function DiffView.preview_spec(opts)
  return {
    kind = 'guihua.diffview.preview',
    opts = normalize_opts(vim.deepcopy(opts or {})),
  }
end

function DiffView.is_preview_spec(preview)
  return type(preview) == 'table' and preview.kind == 'guihua.diffview.preview' and type(preview.opts) == 'table'
end

function DiffView.open(opts)
  log('open diffview')
  return DiffView:new(normalize_opts(opts))
end

function DiffView.open_preview(current_preview, preview)
  local opts = DiffView.is_preview_spec(preview) and preview.opts or preview
  opts = normalize_opts(opts)
  if current_preview ~= nil then
    current_preview:close()
  end
  return DiffView:new(opts)
end

-- Sample API call:
if true then
  DiffView.open({
    title = 'demo.lua diff',
    description = 'Review changes to demo.lua',
    syntax = 'lua',
    close_keymap = '<C-x>',
    autoclose = { events = { 'WinLeave' }, timeout = 5000 },
    diff = [[
diff --git a/demo.lua b/demo.lua
index 1111111..2222222 100644
--- a/demo.lua
+++ b/demo.lua
@@ -1,3 +1,3 @@
-local foo = "bar"
+local foo = "baz"
 local keep = true
]],
  })
end

return DiffView
