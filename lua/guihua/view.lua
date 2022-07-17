local Rect = require('guihua.rect')
local ViewController = require('guihua.viewctrl')
-- prevent view been generated multiple times

local class = require('middleclass')
local View = class('View', Rect)

local log = require('guihua.log').info
local trace = require('guihua.log').trace
local api = vim.api
local word_find = require('guihua.util').word_find
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

--]]
function View:initialize(...)
  trace(debug.traceback())
  local opts = select(1, ...) or {}
  opts.data = opts.data or {}

  _GH_SEARCH_NS = _GH_SEARCH_NS or api.nvim_create_namespace('guihua_search_namespace')
  log('ctor View start with #items', #opts.data)
  trace('ctor View items', opts)
  trace('view start opts', opts)
  Rect.initialize(self, opts)
  if opts.prompt == true then
    self.rect.height = self.rect.height + 1
  end
  self.cursor_pos = { 1, 1 }
  local loc = nil
  if opts.loc ~= nil and opts.loc ~= 'none' then
    local location = require('guihua.location')
    if type(opts.loc) == 'function' then
      loc = opts.loc
    elseif type(opts.loc) == 'string' then
      loc = location[opts.loc]
    end
  end
  self.prompt = opts.prompt == true and true or false
  self.ft = opts.ft or 'guihua'
  self.syntax = opts.syntax or 'guihua'
  self.display_height = self.rect.height

  local floatbuf = require('guihua.floating').floating_buf
  local floatbuf_mask = require('guihua.floating').floating_buf_mask

  local wheight = api.nvim_get_option('lines')
  if wheight < self.rect.height + self.rect.pos_y + 2 then
    self.rect.height = wheight - self.rect.pos_y - 2
    self.display_height = self.rect.height

    log('height offscreen: ', wheight, self.rect)
  end

  local float_opts = {
    win_width = self.rect.width,
    win_height = self.rect.height,
    x = self.rect.pos_x,
    y = self.rect.pos_y,
    loc = loc,
    prompt = self.prompt,
    enter = opts.enter,
    border = opts.border,
    ft = opts.ft,
    syntax = opts.syntax,
    relative = opts.relative,
    allow_edit = opts.allow_edit,
    external = opts.external,
    border_hl = opts.border_hl,
  }
  trace('height: ', self.display_height, 'rect', self.rect, float_opts)
  -- listview should not have ft enabled
  self.buf, self.win, self.closer = floatbuf(float_opts)
  if opts.transparency and not opts.external then
    self.mask_buf, self.mask_win, self.mask_closer = floatbuf_mask(opts.transparency)
  end
  log('floatbuf created ', self.buf, self.win)
  self:set_hl(opts)
  if opts.data ~= nil and #opts.data >= 1 then
    self:on_draw(opts.data)
  end
  if self.prompt then
    vim.cmd('startinsert!')
    log('create prompt view')
  end

  View.static.ActiveView = self
  self:bind_ctrl(opts)

  log('ctor View: end') -- , View.ActiveView)--, self)
end

function View.Active()
  if View.ActiveView ~= nil then
    return true
  end
  return false
end

function View:set_hl(opts)
  local bg = opts.bg or 'GuihuaBgDark'
  if vim.fn.hlexists('GuihuaBgDark') == 0 then
    vim.cmd([[hi default GuihuaBgDark guifg=#d0c8e4 guibg=#1a101f]])
  end

  local cmd = 'Normal:' .. bg .. ',NormalNC:' .. bg
  if opts.border_hl ~= nil then
    cmd = cmd .. ',FloatBorder:' .. opts.border_hl
  end
  api.nvim_win_set_option(self.win, 'winhl', cmd)
  -- def_icon = opts.finder_definition_icon or ' '
  -- self.prompt = opts.prompt or " "
  -- api.nvim_buf_add_highlight(self.contents_buf,-1,"TargetWord",0,#def_icon,self.param_length+#def_icon+3)
end

function View:bind_ctrl(opts)
  if self.ctrl then
    return false
  else
    self.ctrl = ViewController:new(self, opts)
    return true
  end
end

function View:get_ctrl(...)
  return self.ctrl
end

local function draw_table_item(buf, item, pos)
  -- deal with filtered data
  trace('draw_table', buf, item.text, pos)
  if item.text == nil then
    log('draw nil lines', buf, item.text, pos)
    return
  end

  item.text = item.text:gsub('\n', '->')
  api.nvim_buf_set_lines(buf, pos, pos, true, { item.text })
  -- if item.symbol_name is not nil highlight it
  if item.symbol_name and #item.symbol_name > 0 then
    -- lets find all
    local s, e = word_find(item.text, item.symbol_name)
    -- log('hl', pos, s, e, item.text, item.Symbol_name)
    while s ~= nil do
      -- vim.fn.matchaddpos("IncSearch", {{pos + 1, s, e - s + 1}})
      api.nvim_buf_set_extmark(buf, _GH_SEARCH_NS, pos, s - 1, { end_line = pos, end_col = e, hl_group = 'Warnings' })

      s, e = word_find(item.text, item.sybol_name)
    end
  end
  -- api.nvim_buf_set_lines(buf, 0, 1, true, '{item.text}')
  if item.pos ~= nil then
    for _, v in pairs(item.pos) do
      -- vim.fn.matchaddpos("IncSearch", {{pos + 1, v}})

      log('hl', pos, v)
      api.nvim_buf_set_extmark(buf, _GH_SEARCH_NS, pos, v - 1, { end_line = pos, end_col = v, hl_group = 'IncSearch' })
    end
  end
  if item.fzy ~= nil then
    for _, v in pairs(item.fzy.pos) do
      -- vim.fn.matchaddpos("IncSearch", {{pos + 1, v}})
      api.nvim_buf_set_extmark(buf, _GH_SEARCH_NS, pos, v - 1, { end_line = pos, end_col = v, hl_group = 'IncSearch' })
    end
  end
end

-- draw text line by line
local function draw_lines(buf, start, end_at, data)
  -- the #data should match or < start~end_at
  if data == nil or #data < 1 then
    log('empty body')
    return
  end

  api.nvim_buf_clear_namespace(0, _GH_SEARCH_NS, 0, -1)
  trace('draw_lines', buf, start, end_at, #data, data)

  vim.fn.clearmatches()
  api.nvim_buf_set_lines(buf, start, end_at, false, {})
  -- api.nvim_buf_set_lines(buf, start, end_at, true, data)
  local draw_end = math.min(end_at - 1, #data - 1)
  for i = start, draw_end, 1 do
    local l = data[i + 1]
    if l == nil then
      log('draw at failed ', i, data)
    end
    if type(l) == 'string' then -- plain text display
      api.nvim_buf_set_lines(buf, i, i, true, { l })
    elseif type(l) == 'table' and l.text == nil then -- filtered text
      local line = l[1]
      api.nvim_buf_set_lines(buf, i, i, true, { line })
      local pos = l[2]
      for _, v in pairs(pos) do
        -- vim.fn.matchaddpos("IncSearch", {{i + 1, v}})

        api.nvim_buf_set_extmark(0, _GH_SEARCH_NS, i, v, {
          end_line = i,
          end_col = v + 1,
          hl_group = 'IncSearch',
          -- hl_group = _LSP_SIG_CFG.hint_scheme
        })
      end
    else
      draw_table_item(buf, l, i)
    end
  end
end

function View:on_draw(data)
  trace(debug.traceback())
  trace('on_draw', data)
  if not api.nvim_buf_is_valid(self.buf) then
    log('buf id invalid', self.buf)
    return
  end
  if data == nil then
    log('on_draw data nil')
    if self.display_data == nil or #self.display_data == 0 then
      log('on_draw nothing to be draw')
    end
    data = self.display_data
  end

  api.nvim_buf_set_option(self.buf, 'readonly', false)
  local content = {}
  if type(data) == 'string' then
    content = { data }
  else
    content = data
  end

  trace('draw', data[1])
  local start = 0
  if self.header ~= nil then
    start = 1
  end
  local end_at = self.display_height -- C index
  if self.prompt == true then
    end_at = end_at - 1
  end
  -- api.nvim_buf_set_lines(self.buf, start, end_at, true, content)
  draw_lines(self.buf, start, end_at, content)
  if self.prompt ~= true then
    api.nvim_buf_set_option(self.buf, 'readonly', true)
  end
  -- vim.fn.setpos(".", {0, 1, 1, 0})
end

function View:unbind_ctrl(...)
  if self and self.ctrl then
    self.ctrl = nil
  end
end

function View:close(...)
  log('close View ', self.class.name)
  if self == nil then
    return
  end
  -- api.nvim_win_close(self.win, true)
  if self.closer ~= nil then
    -- vim.api.nvim_win_close
    self:closer()
    self.closer = nil
    self.win = nil
  else
    api.nvim_win_close(self.win, true)
    self.win = nil
  end

  if self.mask_closer ~= nil then
    self:mask_closer()
    self.mask_closer = nil
    self.mask_win = nil
  else
    if self.mask_win ~= nil and self.mask_win ~= 0 then
      api.nvim_win_close(self.mask_win, true)
    end
    self.mask_win = nil
  end

  self:unbind_ctrl()
  -- View = class("View", Rect)
  -- View.ActiveView = nil
  View.static.ActiveView = nil
  log('view closed ')
  -- trace("Viewobj after close", View)
end

function View.on_close()
  trace(debug.traceback())
  if View.ActiveView == nil then
    log('view onclose nil')
    return
  end
  log('view onclose ', View.ActiveView.win)
  View.ActiveView:close()
  trace(View)
end

return View
