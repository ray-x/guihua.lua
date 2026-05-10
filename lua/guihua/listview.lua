local class = require('middleclass')
local View = require('guihua.view')
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local util = require('guihua.util')
local ListViewCtrl = require('guihua.listviewctrl')

_GH_SETUP = _GH_SETUP or nil
if _GH_SETUP == nil then
  require('guihua').setup()
end
-- _VT_GHLIST = vim.api.nvim_create_namespace("guihua_listview")

if ListView == nil then
  ListView = class('ListView', View)
end

--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  bg = background
  prompt = true|false
}

--]]
function ListView:initialize(...)
  trace(debug.traceback())

  if ListView.win and vim.api.nvim_win_is_valid(ListView.win) then
    ListView.close()
  end

  log('listview ctor ') -- , self)
  local opts = select(1, ...) or {}

  -- vim.cmd([[hi default GuihuaListDark guifg=#e0d8f4 guibg=#272755]])
  -- vim.cmd([[hi default GuihuaListDark guifg=#e0d8f4 guibg=#103234]])

  local listviewHl = self.list_hl or 'PmenuSel'
  util.selcolor(listviewHl)

  opts.bg = opts.bg or 'GuihuaListDark'

  if opts.enter == nil then
    opts.enter = true
  end
  View.initialize(self, opts)
  self:bind_ctrl(opts)
  -- ListView.static.active_view = self
  log('listview created')
  -- trace(self.win, self.class)
  local ft = 'guihua'
  if opts.ft == 'rust' then
    ft = 'guihua_rust'
  end

  trace('listview ft:', opts)

  vim.api.nvim_set_option_value('ft', ft, { buf = self.buf })
  if not opts.wrap then
    vim.api.nvim_set_option_value('wrap', false, { win = self.win })
  end

  if not opts.prompt or opts.enter then
    vim.cmd('normal! 1gg')
    vim.fn.setpos('.', { self.win, 1, 1, 0 })
  else
    vim.cmd('normal! zvzb')
  end
  if opts.hl_group then
    self.hl_group = opts.hl_group
  end
  self.ns = self.ns or vim.api.nvim_create_namespace('guihua_listview')

  ListView.static.Winnr = self.win
  ListView.static.Bufnr = self.buf
  ListView.static.Closer = self.closer
  ListView.static.ns = self.ns

  if opts.transparency then
    ListView.static.MaskWinnr = self.mask_win
    ListView.static.MaskBufnr = self.mask_buf
    ListView.static.MaskCloser = self.mask_closer
  end

  local m = _GH_SETUP.maps
  vim.keymap.set({ 'n', 'i' }, m.close_view, '<cmd> lua ListView.close() <CR>', { buffer = self.buf })
  vim.api.nvim_set_hl(self.ns, '@error', { undercurl = false, underdouble = false, underline = false })
  vim.api.nvim_win_set_hl_ns(self.win, self.ns)
  return self
end

function ListView:bind_ctrl(opts)
  if self.ctrl and self.ctrl.class_name == 'ListViewCtrl' then
    log('already binded', self.ctrl)
    return false
  else
    self.ctrl = ListViewCtrl:new(self, opts)
    return true
  end
end

function ListView:unbind_ctrl()
  if self.super.unbind_ctrl then
    self.super.unbind_ctrl()
  end
  if self.ctrl then
    self.ctrl = nil
  end
end

-- Next time the ListView object will be re-create
-- But I still feel that it is better to de-reference so it will demalloc early
function ListView.close()
  log('closing listview', ListView.name)
  trace('callback', debug.traceback())

  local closer = ListView.Closer
  if closer then
    closer()
  else
    log('fallback closer')

    local buf = ListView.static.Bufnr
    local win = ListView.static.Winnr

    if buf == nil and win == nil then
      return
    end
    if buf and vim.api.nvim_buf_is_valid(buf) and win and vim.api.nvim_win_is_valid(win) then
      -- fallback
      vim.api.nvim_win_close(win, true)
    end
  end

  -- ListView.on_close() -- parent view closer
  ListView.static.Bufnr = nil
  ListView.static.Winnr = nil
  ListView.static.Closer = nil

  -- close mask
  local mask_closer = ListView.MaskCloser
  if mask_closer then
    mask_closer(ListView.mask_win)
  else
    log('fallback mask closer')
    local mask_buf = ListView.MaskBufnr
    local mask_win = ListView.MaskWinnr
    if mask_buf and vim.api.nvim_buf_is_valid(mask_buf) and mask_win and vim.api.nvim_win_is_valid(mask_win) then
      vim.api.nvim_win_close(mask_win, true)
    end
  end

  ListView.static.MaskBufnr = nil
  ListView.static.MaskWinnr = nil
  ListView.static.MaskCloser = nil

  if ListView.ActiveView and ListView.ActiveView.win then
    ListView.ActiveView.on_close()
    ListView.static.Bufnr = nil
    ListView.static.Winnr = nil
  end

  ListView:unbind_ctrl()
  if ListView.ActiveView ~= nil then
    ListView.ActiveView.data = nil
  end
  ListView.data = nil
  View.data = nil
  vim.cmd([[stopinsert]])
  -- ListView = class("ListView", View)
  log('listview destroyed', ListView.win)
end

function ListView:set_pos(i)
  if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
    return
  end

  if not self.win or not vim.api.nvim_win_is_valid(self.win) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(self.buf)

  if line_count < 1 then
    return
  end

  i = math.max(1, math.min(i, line_count))

  self.selected_line = i

  vim.api.nvim_win_set_cursor(self.win, { i, 0 })

  vim.api.nvim_set_option_value('cursorline', true, { win = self.win })

  vim.wo[self.win].winhighlight = 'CursorLine:GuihuaListSelHl'

  vim.api.nvim_win_call(self.win, function()
    vim.cmd('normal! zz')
  end)
end

function ListView:set_data(data)
  vim.validate({ data = { data, 't' } })
  self.ctrl:on_data_update(data)
  -- updata view?
end

return ListView
