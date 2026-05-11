local class = require('middleclass')
local View = require('guihua.view')
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local util = require('guihua.util')
local ListViewCtrl = require('guihua.listviewctrl')
local SessionRegistry = require('guihua.session_registry')
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

  log('listview ctor ') -- , self)
  local opts = select(1, ...) or {}
  local setup = require('guihua').ensure_setup()
  self.session = SessionRegistry.ensure(opts.session)
  opts.session = self.session

  -- vim.cmd([[hi default GuihuaListDark guifg=#e0d8f4 guibg=#272755]])
  -- vim.cmd([[hi default GuihuaListDark guifg=#e0d8f4 guibg=#103234]])

  local listviewHl = self.list_hl or 'PmenuSel'
  util.selcolor(listviewHl)

  opts.bg = opts.bg or 'GuihuaListDark'

  if opts.enter == nil then
    opts.enter = true
  end
  View.initialize(self, opts)
  SessionRegistry.attach_list_view(self.session, self)
  -- preserve explicit persist flag for controllers
  self.persist = opts.persist == true and true or false
  self:bind_ctrl(opts)
  -- ListView.static.active_view = self
  log('listview created')
  -- trace(self.win, self.class)
  local ft = opts.ft or 'guihua'
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
  -- Disable markdown strikethrough highlights inside listview windows to avoid
  -- accidental strike rendering for single-tilde characters (e.g. paths).
  -- Apply to common groups used by markdown / treesitter: @markup.strikethrough,
  -- @text.strike, markdownStrike, markdownDeleted. Use util helper to set
  -- window-local namespace overrides.
  local ft = opts.ft or self.ft or ''
  if ft == 'markdown' or opts.disable_strikethrough then
    util.disable_win_strikethrough(self.win, self.ns, '@markup.strikethrough')
    util.disable_win_strikethrough(self.win, self.ns, '@text.strike')
    util.disable_win_strikethrough(self.win, self.ns, 'markdownStrike')
    util.disable_win_strikethrough(self.win, self.ns, 'markdownDeleted')
  end

  ListView.static.Winnr = self.win
  ListView.static.Bufnr = self.buf
  ListView.static.Closer = self.closer
  ListView.static.ns = self.ns

  if opts.transparency then
    ListView.static.MaskWinnr = self.mask_win
    ListView.static.MaskBufnr = self.mask_buf
    ListView.static.MaskCloser = self.mask_closer
  end

  local m = setup.maps
  vim.keymap.set({ 'n', 'i' }, m.close_view, function()
    local ctrl = self:get_ctrl()
    if ctrl then
      ctrl:on_close()
      return
    end
    self:close()
  end, { buffer = self.buf, noremap = true, silent = true })
  vim.api.nvim_set_hl(self.ns, '@error', { undercurl = false, underdouble = false, underline = false })
  vim.api.nvim_win_set_hl_ns(self.win, self.ns)
  return self
end

function ListView:bind_ctrl(opts)
  opts = opts or {}
  opts.session = opts.session or self.session
  if self.ctrl and self.ctrl.class_name == 'ListViewCtrl' then
    log('already binded', self.ctrl)
    return false
  else
    self.ctrl = ListViewCtrl:new(self, opts)
    return true
  end
end

function ListView:unbind_ctrl()
  if View.unbind_ctrl then
    View.unbind_ctrl(self)
  end
  if self.ctrl then
    self.ctrl = nil
  end
end

local function clear_static_refs(view)
  if view == nil then
    return
  end
  if ListView.static.Bufnr == view.buf then
    ListView.static.Bufnr = nil
  end
  if ListView.static.Winnr == view.win then
    ListView.static.Winnr = nil
  end
  if ListView.static.Closer == view.closer then
    ListView.static.Closer = nil
  end
  if ListView.static.MaskBufnr == view.mask_buf then
    ListView.static.MaskBufnr = nil
  end
  if ListView.static.MaskWinnr == view.mask_win then
    ListView.static.MaskWinnr = nil
  end
  if ListView.static.MaskCloser == view.mask_closer then
    ListView.static.MaskCloser = nil
  end
end

-- Next time the ListView object will be re-create
-- But I still feel that it is better to de-reference so it will demalloc early
function ListView.close(self)
  if type(self) == 'table' and self.class ~= nil and self.class.name == 'ListView' then
    SessionRegistry.close_preview(self.session)
    clear_static_refs(self)
    View.close(self)
    SessionRegistry.detach_list_view(self.session, self)
    return
  end

  local active_session = SessionRegistry.get_active()
  if active_session ~= nil and active_session.list_view ~= nil then
    active_session.list_view:close()
    return
  end

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

  ListView:unbind_ctrl()
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
  else
    self.selected_line = i
  end
  local selhighlight = vim.api.nvim_create_namespace('guihua_selhighlight')

  vim.schedule(function()
    log('setpos', self.buf, self.selected_line)

    if not vim.api.nvim_buf_is_valid(self.buf) then
      log('setpos error buf not valid')
      return
    end
    if self.prompt ~= true and self.win ~= nil and vim.api.nvim_win_is_valid(self.win) then
      vim.api.nvim_win_set_cursor(self.win, { self.selected_line, 0 })
    end
    vim.api.nvim_buf_clear_namespace(self.buf, selhighlight, 0, -1)
    local ListviewHl = 'GuihuaListSelHl'
    vim.api.nvim_buf_set_extmark(self.buf, selhighlight, self.selected_line - 1, 0, {
      hl_group = ListviewHl,
      end_row = self.selected_line - 1,
      line_hl_group = 'GuihuaListSelHl', -- Highlight the whole line
      priority = 1000,
    })
  end)
end

function ListView:set_data(data)
  vim.validate({ data = { data, 't' } })
  self.ctrl:on_data_update(data)
  -- updata view?
end

return ListView
