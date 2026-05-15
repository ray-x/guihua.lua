local class = require('middleclass')
local View = require('guihua.view')
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local util = require('guihua.util')
local TextViewData = require('guihua.textview_data')

local TextViewCtrl = require('guihua.textviewctrl')
-- local TextView = {}

if TextView == nil then
  TextView = class('TextView', View)
end
-- Note, Support only one active view
-- ActiveView = nil
--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  loc='center|up_left|center_right'
  background
  prompt
}
opts= {uri = l.uri, width = width, height=height, lnum = l.lnum, col = l.col, offset_x = 0, offset_y = offset_y}

with file uri {
    syntax = syntax,
    rect = {width = 40, height = 20},
    pos_x = opts.offset_x or 0,
    pos_y = opts.offset_y or 10,
    range = range,
    uri = uri,
    allow_edit = true
  }

--]]

local ns_id = vim.api.nvim_create_namespace('guihua_textview')
local PREVIEW_SPEC_KIND = 'guihua.textview.preview'

local function set_highlight(buf, line, hl_group)
  if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  return vim.api.nvim_buf_set_extmark(buf, ns_id, line - 1, 0, {
    hl_group = hl_group,
    end_row = line - 1,
    line_hl_group = hl_group,
    priority = 1000,
  })
end

local function normalize_textview_opts(opts)
  opts = opts or {}
  opts.bg = opts.preview_bg or opts.bg or 'GuihuaTextViewDark'

  if opts.width or opts.height then
    opts.rect = { width = opts.width or 60, height = opts.height or 30 }
  end

  opts.enter = opts.enter or false
  return opts
end

local function apply_highlight(view, opts)
  if view.buf ~= nil and vim.api.nvim_buf_is_valid(view.buf) then
    vim.api.nvim_buf_clear_namespace(view.buf, ns_id, 0, -1)
  end
  TextView.static.hl_id = nil
  TextView.static.hl_line = nil

  if opts.hl_line == nil then
    return
  end

  if opts.hl_line == 0 then
    opts.hl_line = 1
  end
  log('buf', view.buf, 'hl_line: ', opts.hl_line)
  TextView.static.hl_id = set_highlight(view.buf, opts.hl_line, 'GuihuaListSelHl')
  TextView.static.hl_line = opts.hl_line
end

local function apply_syntax(view, opts)
  if opts.syntax then
    view.syntax = opts.syntax
    log('hl ', view.buf, opts.syntax)
    require('guihua.util').highlighter(view.buf, opts.syntax, opts.lnum)
  end
end

local function can_update_preview(view, opts)
  if view == nil or opts == nil then
    return false
  end
  if view.win == nil or not vim.api.nvim_win_is_valid(view.win) then
    return false
  end
  if view.buf == nil or not vim.api.nvim_buf_is_valid(view.buf) then
    return false
  end
  if view.rect == nil or opts.rect == nil then
    return false
  end

  return view.rect.height == opts.rect.height
    and view.rect.width == opts.rect.width
    and view.rect.pos_x == opts.rect.pos_x
    and view.rect.pos_y == opts.rect.pos_y
end

local function resolve_preview_opts(opts)
  return TextViewData.resolve(normalize_textview_opts(opts))
end

function TextView:initialize(...)
  trace(debug.traceback())

  local opts = resolve_preview_opts(select(1, ...) or {})
  local setup = require('guihua').ensure_setup()

  log('ctor TextView start:')
  trace(opts)
  if opts.allow_edit then
    vim.api.nvim_command('autocmd InsertEnter ' .. " <buffer> ++once echo 'use <C-s> to save your changes'")
  end
  View.initialize(self, opts)

  trace('textview after super', self, opts)
  self.cursor_pos = { 1, 1 }
  self.file_info = opts.file_info
  apply_syntax(self, opts)

  if not opts.enter then
    -- currsor move will close textview. currently disabled because user can edit inside preview
    log('auto close on cursor move disabled')
  else
    -- for user case of symbol definition preview, <c-e> close win/buf
    local m = setup.maps
    util.close_view_event('n', m.close_view, self.win, self.buf, opts.enter)
    util.close_view_event('i', m.close_view, self.win, self.buf, opts.enter)
  end

  util.close_view_autocmd({ 'BufHidden', 'BufDelete' }, self.win)
  if opts.uri then
    log('ctor TextView: ctrl') -- , View.ActiveView)--, self)
    self:bind_ctrl(opts)
  end
  if opts.data then
    self:on_draw(opts.data, opts.status_line)
  end

  apply_highlight(self, opts)

  if opts.ft then
    vim.api.nvim_set_option_value('filetype', opts.ft, { buf = self.buf })
  end
  if opts.allow_edit then
    vim.api.nvim_set_option_value('readonly', false, { buf = self.buf })
  end

  local ns = vim.api.nvim_create_namespace(opts.ft or 'textview')
  vim.api.nvim_set_hl(ns, '@error', {}) -- clear error highlight
  vim.api.nvim_win_set_hl_ns(self.win, ns)
  TextView.static.ActiveTextView = self

  log('ctor TextView: end') -- , View.ActiveView)--, self)
  trace(self)
  return self
end

function TextView.preview_spec(opts)
  return {
    kind = PREVIEW_SPEC_KIND,
    opts = normalize_textview_opts(vim.deepcopy(opts or {})),
  }
end

function TextView.is_preview_spec(preview)
  return type(preview) == 'table' and preview.kind == PREVIEW_SPEC_KIND and type(preview.opts) == 'table'
end

function TextView:apply_preview(opts)
  opts = resolve_preview_opts(opts)

  self.file_info = opts.file_info
  apply_syntax(self, opts)

  if opts.uri ~= nil and self.ctrl == nil then
    self:bind_ctrl(opts)
  end

  self:on_draw(opts.data or {}, opts.status_line)

  apply_highlight(self, opts)

  if opts.ft then
    vim.api.nvim_set_option_value('filetype', opts.ft, { buf = self.buf })
  end
  if opts.allow_edit then
    vim.api.nvim_set_option_value('readonly', false, { buf = self.buf })
  end

  TextView.static.ActiveTextView = self
  return self
end

function TextView.open_preview(current_preview, preview)
  local opts = TextView.is_preview_spec(preview) and preview.opts or preview
  opts = resolve_preview_opts(opts)

  if can_update_preview(current_preview, opts) then
    return current_preview:apply_preview(opts)
  end

  if current_preview ~= nil then
    current_preview:close()
  end
  if TextView.ActiveTextView == current_preview then
    TextView.static.ActiveTextView = nil
  end

  return TextView:new(opts)
end

function TextView.open(opts)
  return TextView.open_preview(nil, TextView.preview_spec(opts))
end

function TextView.Active()
  if TextView.ActiveTextView ~= nil then
    return true
  end
  return false
end

---@opts: list of string, or table indicate uri and range of lines
---@status_line: string or nil, indicate if status line is needed
function TextView:on_draw(opts, status_line)
  if opts == nil then
    log(debug.traceback())
    return
  end
  local data = {}
  if not self or not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
    log('buf id invalid', self)
    return
  end
  data = opts
  local content = {}
  if type(data) == 'string' then
    content = { data }
  elseif type(data) == 'table' then
    content = data
  else
    log('invalid draw data', data, self.buf, self.win)
    return
  end

  log('draw data: ', data[1], ' size: ', #data, self.buf, self.win)
  if #data < 1 then
    log('nothing to redraw')
    return
  end
  local start = 0
  if self.header ~= nil then
    start = 1
  end
  local end_at = -1
  local bufnr = self.buf
  if bufnr == nil or bufnr == 0 then
    print('Error: plugin failure, please submit a issue')
    return
  end
  trace('bufnr', bufnr)

  vim.api.nvim_set_option_value('readonly', false, { buf = bufnr })
  -- vim.api.nvim_buf_set_lines(self.buf, start, end_at, true, content)
  vim.api.nvim_buf_set_lines(bufnr, start, end_at, true, content)
  -- vim.api.nvim_set_option_value("readonly", true, {buf=bufnr})
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  if TextView.static.hl_line ~= nil then
    -- TextView.static.hl_id =
    -- vim.api.nvim_buf_add_highlight(self.buf, -1, 'GuihuaListSelHl', TextView.hl_line - 1, 0, -1)
    TextView.static.hl_id = set_highlight(self.buf, TextView.static.hl_line, 'GuihuaListSelHl')
  end
  if status_line then
    -- add hl to last line
    TextView.static.hl_id = set_highlight(self.buf, #data, 'GuihuaListSelHl')
  end
  -- vim.fn.setpos(".", {0, 1, 1, 0})

  log('textview draw finished')
end

function TextView.on_close()
  trace(debug.traceback())
  local active_view = TextView.ActiveTextView
  if active_view == nil then
    log('view onclose nil')
    return
  end
  log('TextView onclose ', active_view.win)
  active_view:close()
  if TextView.ActiveTextView == active_view then
    TextView.static.ActiveTextView = nil
  end
end

function TextView:bind_ctrl(opts)
  if self.ctrl and self.ctrl.class_name == 'TextViewCtrl' then
    return false
  else
    self.ctrl = TextViewCtrl:new(self, opts)
    trace('textview ctrl', self.ctrl)
    return true
  end
end

return TextView
