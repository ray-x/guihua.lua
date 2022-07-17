local class = require('middleclass')
local View = require('guihua.view')
local log = require('guihua.log').info
local util = require('guihua.util')
local trace = require('guihua.log').trace

local TextViewCtrl = require('guihua.textviewctrl')
-- local TextView = {}

if TextView == nil then
  TextView = class('TextView', View)
end

if _GH_SETUP == nil then
  require('guihua.maps').setup()
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
function TextView:initialize(...)
  trace(debug.traceback())

  local opts = select(1, ...) or {}

  log('ctor TextView start:')
  trace(opts)
  local bg = util.bgcolor(0x050812)

  if vim.fn.hlexists('GuihuaTextViewDark') == 0 then
    vim.cmd([[hi default GuihuaTextViewDark guifg=#e0d8f4  guibg=]] .. bg)
  end

  opts.bg = opts.bg or 'GuihuaTextViewDark'

  if opts.width or opts.height then
    opts.rect = { widht = opts.widht or 60, height = opts.height or 30 }
  end

  if vim.fn.hlexists('GuihuaListHl') == 0 then
    vim.cmd([[highlight default link GuihuaListHl PmenuSel]])
  end
  if TextView.ActiveTextView ~= nil then
    if
      TextView.ActiveTextView.win ~= nil
      and vim.api.nvim_win_is_valid(TextView.ActiveTextView.win)
      and vim.api.nvim_buf_is_valid(TextView.ActiveTextView.buf)
    then
      log('active view ', TextView.ActiveTextView.buf, TextView.ActiveTextView.win)
      if TextView.hl_id ~= nil then
        vim.api.nvim_buf_clear_namespace(0, TextView.hl_id, 0, -1)
        TextView.static.hl_id = nil
        TextView.static.hl_line = nil
      end
      trace('active view already existed')
      self = TextView.ActiveTextView
      TextView.ActiveTextView.ctrl.file_info = opts
      -- TODO: delegate, on_load
      if opts.data then
        TextView.ActiveTextView:on_draw(opts.data)
      else
        TextView.ActiveTextView:on_draw(opts)
      end
      if opts.hl_line ~= nil then
        if opts.hl_line == 0 then
          opts.hl_line = 1
        end
        log('hl buf', self.buf, 'l ', opts.hl_line)
        TextView.static.hl_id = vim.api.nvim_buf_add_highlight(self.buf, -1, 'GuihuaListHl', opts.hl_line - 1, 0, -1)
        TextView.static.hl_line = opts.hl_line
      end
      log('ctor TextView: end, already existed') -- , View.ActiveView)--, self)
      return TextView.ActiveTextView
    end
  end
  if opts.allow_edit then
    -- log("map au Insert")
    vim.api.nvim_command('autocmd InsertEnter ' .. " <buffer> ++once echo 'use <C-s> to save your changes'")
  end

  opts.enter = opts.enter or false
  View.initialize(self, opts)

  trace('textview after super', self)
  self.cursor_pos = { 1, 1 }
  if opts.syntax then
    self.syntax = opts.syntax
    log('hl ', self.buf, opts.syntax)
    require('guihua.util').highlighter(self.buf, opts.syntax, opts.lnum)
  end

  if not opts.enter then
    -- currsor move will close textview. currently disabled because user can edit inside preview
    log('auto close on cursor move disabled')
  else
    -- for user case of symbol definition preview, <c-e> close win/buf
    local m = _GH_SETUP.maps
    util.close_view_event('n', m.close_view, self.win, self.buf, opts.enter)
    util.close_view_event('i', m.close_view, self.win, self.buf, opts.enter)
  end

  util.close_view_autocmd({ 'BufHidden', 'BufDelete' }, self.win)
  -- controller and data
  if opts.uri then -- well this is a feature flag for early phase dev
    log('ctor TextView: ctrl') -- , View.ActiveView)--, self)
    self:bind_ctrl(opts)

    local content = self.ctrl:on_load(opts)
    self:on_draw(content)
  end

  if opts.hl_line ~= nil then
    if opts.hl_line == 0 then
      opts.hl_line = 1
    end
    log('buf', self.buf, 'hl_line: ', opts.hl_line)
    TextView.static.hl_id = vim.api.nvim_buf_add_highlight(self.buf, -1, 'GuihuaListHl', opts.hl_line - 1, 0, -1)
    TextView.static.hl_line = opts.hl_line
  end

  if opts.allow_edit then
    vim.api.nvim_buf_set_option(self.buf, 'readonly', false)
  end

  TextView.static.ActiveTextView = self

  log('ctor TextView: end') -- , View.ActiveView)--, self)
  trace(self)
  return self
end

function TextView.Active()
  if TextView.ActiveTextView ~= nil then
    return true
  end
  return false
end

function TextView:on_draw(opts)
  if opts == nil then
    log(debug.traceback())
    return
  end
  local data = {}
  if not self or not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
    log('buf id invalid', self)
    return
  end
  if opts.uri ~= nil then
    data = self.ctrl:on_load(opts)
  else
    data = opts
  end
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
  local bufnr = self.buf or TextView.ActiveTextView.buf
  if bufnr == 0 then
    print('Error: plugin failure, please submit a issue')
  end
  trace('bufnr', bufnr)

  vim.api.nvim_buf_set_option(bufnr, 'readonly', false)
  -- vim.api.nvim_buf_set_lines(self.buf, start, end_at, true, content)
  vim.api.nvim_buf_set_lines(bufnr, start, end_at, true, content)
  -- vim.api.nvim_buf_set_option(bufnr, "readonly", true)
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  if TextView.hl_line ~= nil then
    TextView.static.hl_id = vim.api.nvim_buf_add_highlight(self.buf, -1, 'GuihuaListHl', TextView.hl_line - 1, 0, -1)
  end
  -- vim.fn.setpos(".", {0, 1, 1, 0})

  log('textview draw finished')
end

function TextView.on_close()
  trace(debug.traceback())
  if TextView.ActiveTextView == nil then
    log('view onclose nil')
    return
  end
  log('TextView onclose ', TextView.ActiveTextView.win)
  TextView.ActiveTextView:close()
  TextView.static.ActiveView = nil
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
