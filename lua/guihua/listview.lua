local class = require('middleclass')
local View = require('guihua.view')
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local util = require('guihua.util')
local ListViewCtrl = require('guihua.listviewctrl')
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
  background
  prompt
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

  local listviewHl = self.hl_group or 'PmenuSel'
  util.selcolor(listviewHl)
  local normalbg = tonumber(string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('NormalFloat')), 'bg#'), 2), 16)
    or tonumber(string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'bg#'), 2), 16)
    or 0x232323

  local bg
  if
    not vim.fn.hlexists('GuihuaListDark') or vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('GuihuaListDark')), 'bg#') == ''
  then
    bg = util.bgcolor(0x051012)
    local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'fg#')
    vim.cmd([[hi default GuihuaListDark guifg=]] .. fg .. [[ guibg=]] .. bg)
  end
  opts.bg = opts.bg or 'GuihuaListDark'

  opts.enter = true
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

  vim.api.nvim_buf_set_option(self.buf, 'ft', ft)
  vim.api.nvim_win_set_option(self.win, 'wrap', false)

  if not opts.prompt or opts.enter then
    vim.cmd('normal! 1gg')
    vim.fn.setpos('.', { self.win, 1, 1, 0 })
  else
    vim.cmd('normal! zvzb')
  end
  if opts.hl_group then
    self.hl_group = opts.hl_group
  end
  ListView.static.Winnr = self.win
  ListView.static.Bufnr = self.buf
  ListView.static.Closer = self.closer

  if opts.transparency then
    ListView.static.MaskWinnr = self.mask_win
    ListView.static.MaskBufnr = self.mask_buf
    ListView.static.MaskCloser = self.mask_closer
  end

  local m = _GH_SETUP.maps
  vim.api.nvim_buf_set_keymap(self.buf, 'n', m.close_view, '<cmd> lua ListView.close() <CR>', {})
  vim.api.nvim_buf_set_keymap(self.buf, 'i', m.close_view, '<cmd> lua ListView.close() <CR>', {})
  -- vim.fn.setpos('.', {self.win, i, 1, 0})
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
  if not vim.api.nvim_buf_is_valid(self.buf) then
    log('invalid bufid', self.buf)
    return
  end
  if #vim.api.nvim_buf_get_lines(self.buf, 0, -1, false) < 2 then
    log('empty buf')
    return
  end
  if i < 0 then
    log('incorrect select_line -1', self.display_height, self.selected_line, self.display_start_at)
    log(debug.traceback())
    self.selected_line = 1
  end
  self.selected_line = i
  local selhighlight = vim.api.nvim_create_namespace('selhighlight')
  local cursor = vim.api.nvim_win_get_cursor(self.win)
  cursor[1] = i
  -- vim.api.nvim_win_set_cursor(self.win, cursor)

  -- vim.api.nvim_buf_clear_namespace(self.buf, _VT_GHLIST, 0, -1)
  -- _VT_GHLIST = vim.api.nvim_buf_set_virtual_text(self.buf, _VT_GHLIST, i - 1, {{"<-", "Sting"}}, {})
  -- log("set virtual text on ", i, "buf", self.buf, _VT_GHLIST)
  vim.schedule(function()
    log('setpos', self.buf, self.selected_line)

    if not vim.api.nvim_buf_is_valid(self.buf) then
      log('setpos error buf not valid')
      return
    end
    vim.api.nvim_buf_clear_namespace(self.buf, selhighlight, 0, -1)
    local ListviewHl = 'GuihuaListHl'
    vim.api.nvim_buf_add_highlight(self.buf, selhighlight, ListviewHl, self.selected_line - 1, 0, -1)
  end)
end

function ListView:set_data(data)
  vim.validate({ data = { data, 't' } })
  self.ctrl:on_data_udpate(data)
  -- updata view?
end

return ListView
