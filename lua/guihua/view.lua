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
_GH_SEARCH_NS = _GH_SEARCH_NS or nil
function View:initialize(...)
  trace(debug.traceback())
  local opts = select(1, ...) or {}
  opts.data = opts.data or {}
  require('guihua.highlight').setup(opts)

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
  self.enter = opts.enter == true and true or false
  self.prompt_mode = opts.prompt_mode or 'insert'
  self.ft = opts.ft or 'guihua'
  self.syntax = opts.syntax or 'guihua'
  self.display_height = self.display_height or self.rect.height

  local floatbuf = require('guihua.floating').floating_buf
  local floatbuf_mask = require('guihua.floating').floating_buf_mask

  local wheight = api.nvim_get_option('lines')
  if wheight < self.rect.height + self.rect.pos_y + 2 then
    self.rect.height = math.max(2, wheight - self.rect.pos_y - 2)
    self.display_height = self.display_height or self.rect.height

    log('height offscreen: ', wheight, self.rect)
  end
  log('height:', self.rect.height, self.rect.pos_y)

  local float_opts = {
    win_width = self.rect.width,
    win_height = self.rect.height,
    x = self.rect.pos_x,
    y = self.rect.pos_y,
    loc = loc,
    prompt = self.prompt,
    prompt_mode = self.prompt_mode,
    enter = opts.enter,
    focus = opts.focus,
    border = opts.border,
    title = opts.title,
    title_pos = opts.title_pos,
    title_style = opts.title_style,
    ft = opts.ft,
    syntax = opts.syntax,
    relative = opts.relative,
    allow_edit = opts.allow_edit,
    external = opts.external,
    border_hl = opts.border_hl,
    bg_hl = opts.bg_hl,
  }
  trace('height: ', self.display_height, 'rect', self.rect, float_opts)
  -- listview should not have ft enabled
  self.buf, self.win, self.closer = floatbuf(float_opts)
  if opts.transparency and not opts.external then
    if vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'bg#') ~= '' then
      self.mask_buf, self.mask_win, self.mask_closer = floatbuf_mask(opts.transparency)
    end
  end

  if opts.transparency then
    api.nvim_set_option_value('winblend', math.min(opts.transparency, 15), { win = self.win })
  end
  if
    vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'bg#') == ''
    or vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('NormalFloat')), 'bg#') == ''
  then
    -- prevent you get black ground
    api.nvim_set_option_value('winblend', 0, { win = self.win })
  end

  api.nvim_set_option_value('virtualedit', 'block', { win = self.win })
  log('floatbuf created ', self.buf, self.win)
  self:set_hl(opts)
  if opts.data ~= nil and #opts.data >= 1 then
    self:on_draw(opts.data)
  end

  -- Optional: disable markdown/strikethrough highlights inside guihua views
  local gh_setup = require('guihua').ensure_setup()
  local disable_views = gh_setup.disable_strikethrough_in_views
  local util = require('guihua.util')
  self.ns = self.ns or api.nvim_create_namespace('guihua_view')
  local _strike_groups = { '@markup.strikethrough', '@text.strike', 'markdownStrike', 'markdownDeleted' }
  if disable_views then
    for _, g in ipairs(_strike_groups) do
      util.disable_win_strikethrough(self.win, self.ns, g)
    end

    -- Re-apply the window-local highlight override when the view/buffer regains focus.
    -- Some highlight updates (treesitter/syntax) may re-evaluate when the window becomes active
    -- so re-assert the window-local namespace on WinEnter/BufEnter/BufWinEnter.
    local aug_name = 'GuihuaDisableStrike' .. tostring(self.win)
    local aug = api.nvim_create_augroup(aug_name, { clear = true })
    api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter', 'BufEnter' }, {
      group = aug,
      buffer = self.buf,
      callback = function()
        if api.nvim_win_is_valid(self.win) and api.nvim_buf_is_valid(self.buf) then
          for _, g in ipairs(_strike_groups) do
            util.disable_win_strikethrough(self.win, self.ns, g)
          end
        end
      end,
    })
  end

  -- Provide a guihua-only double-tilde fallback when requested: disable existing
  -- strikethrough groups locally and add extmarks that only strike ~~...~~ spans.
  local patch_ts = gh_setup.patch_markdown_strikethrough_query
  if patch_ts and (self.ft == 'markdown' or (self.ft and self.ft:match('markdown'))) then
    -- ensure we have a namespace for window-local disables
    self.ns = self.ns or api.nvim_create_namespace('guihua_view')
    -- disable common strike groups in window namespace
    for _, g in ipairs(_strike_groups) do
      util.disable_win_strikethrough(self.win, self.ns, g)
    end

    -- apply extmarks for double-tilde spans
    local function apply_double_tilde_extmarks()
      if not api.nvim_buf_is_valid(self.buf) then
        return
      end
      pcall(vim.api.nvim_set_hl, 0, 'GuihuaDoubleTildeStrike', { default = true, strikethrough = true })
      self._double_ns = self._double_ns or api.nvim_create_namespace('guihua_double_tilde')
      api.nvim_buf_clear_namespace(self.buf, self._double_ns, 0, -1)
      local ok, lines = pcall(api.nvim_buf_get_lines, self.buf, 0, -1, false)
      if not ok or not lines then
        return
      end
      for i, line in ipairs(lines) do
        local start = 1
        while true do
          local s, e = string.find(line, '~~.-~~', start)
          if not s then
            break
          end
          -- set extmark with high priority so it survives other highlight updates
          api.nvim_buf_set_extmark(self.buf, self._double_ns, i - 1, s - 1, {
            end_row = i - 1,
            end_col = e,
            hl_group = 'GuihuaDoubleTildeStrike',
            priority = 2000,
          })
          start = e + 1
        end
      end
    end

    apply_double_tilde_extmarks()
    local aug_name2 = 'GuihuaDoubleTilde' .. tostring(self.win)
    local aug2 = api.nvim_create_augroup(aug_name2, { clear = true })
    api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter', 'BufEnter', 'CursorMoved', 'CursorMovedI', 'ModeChanged', 'TextChanged', 'TextChangedI' }, {
      group = aug2,
      buffer = self.buf,
      callback = function()
        if api.nvim_win_is_valid(self.win) and api.nvim_buf_is_valid(self.buf) then
          -- reapply window-local disables and extmarks; some highlight updates run after enter
          if disable_views then
            for _, g in ipairs(_strike_groups) do
              util.disable_win_strikethrough(self.win, self.ns, g)
            end
          end
          apply_double_tilde_extmarks()
        end
      end,
    })
  end

  if self.prompt and self.enter and self.prompt_mode == 'insert' then
    vim.cmd('startinsert!')
    log('create prompt view')
  end

  trace('ctor View: end')
end

local function get_active_session()
  local SessionRegistry = require('guihua.session_registry')
  return SessionRegistry.get_active()
end

function View.Active()
  return get_active_session() ~= nil
end

function View:is_valid()
  return self ~= nil
    and self.win ~= nil
    and api.nvim_win_is_valid(self.win)
    and self.buf ~= nil
    and api.nvim_buf_is_valid(self.buf)
end

function View:focus()
  if not self:is_valid() then
    return false
  end
  if api.nvim_get_current_win() ~= self.win then
    api.nvim_set_current_win(self.win)
  end
  return true
end

function View:set_hl(opts)
  local bg = opts.bg_hl or 'GuihuaBgDark'
  local cmd = 'Normal:' .. bg .. ',NormalNC:' .. bg
  if opts.border_hl ~= nil then
    cmd = cmd .. ',FloatBorder:' .. opts.border_hl
  end
  api.nvim_set_option_value('winhl', cmd, { win = self.win })
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
  local head = ''
  if item.selected then
    head = ''
  end
  api.nvim_buf_set_lines(buf, pos, pos, true, { head .. item.text })
  -- if item.symbol_name is not nil highlight it
  if item.symbol_name and #item.symbol_name > 0 then
    -- lets find all
    local s, e = word_find(item.text, item.symbol_name)
    -- log('hl', pos, s, e, item.text, item.Symbol_name)
    while s ~= nil do
      api.nvim_buf_set_extmark(buf, _GH_SEARCH_NS, pos, s - 1, { end_row = pos, end_col = e, hl_group = 'Warnings' })
      local next_start = e + 1
      if next_start > #item.text then
        break
      end
      s, e = word_find(item.text:sub(next_start), item.symbol_name)
      if s then
        s = s + next_start - 1
        e = e + next_start - 1
      end
    end
  end
  if item.pos ~= nil then
    for _, v in pairs(item.pos) do
      -- vim.fn.matchaddpos("IncSearch", {{pos + 1, v}})

      log('hl', pos, v)
      api.nvim_buf_set_extmark(buf, _GH_SEARCH_NS, pos, v - 1, { end_row = pos, end_col = v, hl_group = 'IncSearch' })
    end
  end
  if item.fzy ~= nil then
    for _, v in pairs(item.fzy.pos) do
      api.nvim_buf_set_extmark(buf, _GH_SEARCH_NS, pos, v - 1, { end_row = pos, end_col = v, hl_group = 'IncSearch' })
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

  buf = buf or 0
  api.nvim_buf_clear_namespace(buf, _GH_SEARCH_NS, 0, -1)
  -- trace('draw_lines', buf, start, end_at, #data, data)

  vim.fn.clearmatches()
  api.nvim_buf_set_lines(buf, start, end_at, false, {})
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
        -- trace(i, v, l, line)
        api.nvim_buf_set_extmark(buf, _GH_SEARCH_NS, i, v - 1, {
          end_row = i,
          end_col = v,
          hl_group = 'IncSearch',
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

  api.nvim_set_option_value('readonly', false, { buf = self.buf })
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
  draw_lines(self.buf, start, end_at, content)
  if self.prompt ~= true then
    api.nvim_set_option_value('readonly', true, { buf = self.buf })
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
  trace(debug.traceback())
  if self == nil then
    return
  end
  -- api.nvim_win_close(self.win, true)
  if self.closer ~= nil then
    self:closer()
    self.closer = nil
    self.win = nil
  else
    if self.win and api.nvim_win_is_valid(self.win) then
      api.nvim_win_close(self.win, true)
    end
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
  log('view closed ')
  -- trace("Viewobj after close", View)
end

function View.on_close()
  trace(debug.traceback())
  local active_session = get_active_session()
  local active_view = active_session and active_session.list_view or nil
  if active_view == nil then
    log('view onclose nil')
    return
  end
  log('view onclose ', active_view.win)
  active_view:close()
  trace(View)
end

return View
