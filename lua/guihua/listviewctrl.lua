local class = require('middleclass')
local ViewController = require('guihua.viewctrl')
local error = require('guihua.log').error
local util = require('guihua.util')

local log = require('guihua.log').info
local trace = require('guihua.log').trace
local api = vim.api
local ListState = require('guihua.liststate')
local SessionRegistry = require('guihua.session_registry')
_GH_SETUP = _GH_SETUP or require('guihua.maps').setup()
ListView = ListView or nil
if _GH_SETUP == nil then
  _GH_SETUP = require('guihua.maps').setup()
end
TextView = TextView or require('guihua.textview')
if ListViewCtrl == nil then
  ListViewCtrl = class('ListViewCtrl', ViewController)
end

local current_delegate

local function current_preview(listobj)
  local session = listobj and listobj.session
  local preview = session and session.preview_view or nil
  if preview ~= nil and preview.win ~= nil and vim.api.nvim_win_is_valid(preview.win) then
    return preview
  end
  return nil
end

local function active_data(listobj)
  if listobj == nil or listobj.state == nil then
    return {}
  end
  return listobj.state:active_data()
end

function ListViewCtrl:gh_jump_to_list()
  local _, delegate = current_delegate(self)
  local jumpto = delegate and delegate.win or ListView.Winnr
  if jumpto ~= nil and vim.api.nvim_win_is_valid(jumpto) then
    log('jump to', jumpto)
    vim.cmd(string.format('noa call nvim_set_current_win(%s)', jumpto))
    return
  end
end

function ListViewCtrl:gh_jump_to_preview()
  local preview = current_preview(self)
  if preview == nil then
    return
  end
  local jumpto = preview.win
  if jumpto ~= nil and vim.api.nvim_win_is_valid(jumpto) then
    log('jump to', jumpto)
    vim.cmd(string.format('noa call nvim_set_current_win(%s)', jumpto))
    return
  end
end

local function on_preview(listobj)
  if listobj ~= nil and listobj.preview ~= true then
    return false
  end
  local preview = current_preview(listobj)
  if preview == nil then
    return false
  end
  local jumpto = preview.win
  return jumpto ~= nil and vim.api.nvim_win_is_valid(jumpto)
end

local function on_popup_window()
  local current_win = api.nvim_get_current_win()
  if current_win == nil or current_win == 0 or not api.nvim_win_is_valid(current_win) then
    return false
  end
  local current_buf = api.nvim_win_get_buf(current_win)
  if SessionRegistry.get_by_buf(current_buf) ~= nil then
    return true
  end
  local ok, cfg = pcall(api.nvim_win_get_config, current_win)
  if not ok or cfg.relative == nil or cfg.relative == '' then
    return false
  end
  local buftype = api.nvim_get_option_value('buftype', { buf = current_buf })
  local filetype = api.nvim_get_option_value('filetype', { buf = current_buf })
  return buftype == 'prompt' or filetype == 'guihua'
end

current_delegate = function(self_or_bufnr, bufnr)
  local session = nil
  local listobj = nil
  if type(self_or_bufnr) == 'table' and self_or_bufnr.class ~= nil and self_or_bufnr.m_delegate ~= nil then
    listobj = self_or_bufnr
    session = listobj.session or (listobj.m_delegate and listobj.m_delegate.session)
    bufnr = bufnr or (listobj.m_delegate and listobj.m_delegate.buf)
  elseif type(self_or_bufnr) == 'number' then
    bufnr = self_or_bufnr
    session = SessionRegistry.get_by_buf(bufnr)
  end
  if session == nil and bufnr ~= nil then
    session = SessionRegistry.get_by_buf(bufnr)
  end
  if session == nil then
    session = SessionRegistry.current()
  end
  if listobj == nil and session ~= nil then
    listobj = session.controller
  end
  if listobj == nil or listobj.m_delegate == nil then
    return nil, nil
  end
  local delegate = listobj.m_delegate
  if bufnr ~= nil and delegate.buf ~= bufnr then
    return nil, nil
  end
  if delegate.win == nil or not vim.api.nvim_win_is_valid(delegate.win) then
    SessionRegistry.detach_controller(listobj.session, listobj)
    SessionRegistry.detach_list_view(listobj.session, delegate)
    return nil, nil
  end
  return listobj, delegate
end

local function clear_autocmds(listobj)
  if listobj == nil or listobj.augroup == nil then
    return
  end
  pcall(api.nvim_del_augroup_by_id, listobj.augroup)
  listobj.augroup = nil
end

local function close_controller(listobj)
  if listobj == nil or listobj.closed then
    return
  end
  listobj.closed = true
  clear_autocmds(listobj)
  local delegate = listobj.m_delegate
  SessionRegistry.detach_controller(listobj.session, listobj)
  SessionRegistry.close_preview(listobj.session)
  if delegate ~= nil and delegate.close ~= nil and delegate.win ~= nil and api.nvim_win_is_valid(delegate.win) then
    delegate:close()
  end
end

function ListViewCtrl:initialize(delegate, ...)
  trace(debug.traceback())
  ViewController:initialize(delegate, ...)
  self.m_delegate = delegate
  --
  local opts = select(1, ...) or {}
  trace('listview ctrl opts', opts)
  self.session = SessionRegistry.ensure(opts.session or delegate.session)
  delegate.session = self.session
  self.preview = opts.preview or false
  self.prompt = opts.prompt
  self.prompt_mode = opts.prompt_mode
  self.enter = opts.enter
  self.on_input_filter = opts.on_input_filter
  self.state = ListState.new({
    data = opts.data or {},
    display_height = self.m_delegate.display_height or 10,
    prompt = opts.prompt,
  })
  self.on_move = opts.on_move or function(...)
    _ = { ... }
  end
  self.confirm_cb = opts.on_confirm
  self:sync_state()

  log('init display: ', self.display_height, self.selected_line)
  trace('init display: ', self.display_data, self.display_height, self.selected_line)
  -- ... is the view
  -- todo location, readonly? and filetype
  if delegate.buf == nil or delegate.buf == 0 then
    log('should not bind to current buffer')
  end
  local m = _GH_SETUP.maps
  if m == nil then
    return
  end
  --  stylua: ignore start
  local keymaps = {
    { mode = 'n', key = m.prev,       cmd = function() self:on_prev() end,                   desc = 'ListViewCtrl:on_prev()' },
    { mode = 'i', key = m.prev,       cmd = function() self:on_prev() end,                   desc = 'ListViewCtrl:on_prev()' },
    { mode = 'n', key = m.next,       cmd = function() self:on_next() end,                   desc = 'ListViewCtrl:on_next()' },
    { mode = 'i', key = m.next,       cmd = function() self:on_next() end,                   desc = 'ListViewCtrl:on_next()' },
    { mode = 'n', key = '<Enter>',    cmd = function() self:on_confirm() end,                desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'i', key = '<Enter>',    cmd = function() self:on_confirm() end,                desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'n', key = '<C-w>j',     cmd = function() self:gh_jump_to_preview() end,        desc = 'jump to preview' },
    { mode = 'n', key = 'k',          cmd = function() self:on_prev() end,                   desc = 'ListViewCtrl:on_prev()' },
    { mode = 'n', key = 'j',          cmd = function() self:on_next() end,                   desc = 'ListViewCtrl:on_next()' },
    { mode = 'n', key = '<Tab>',      cmd = function() self:on_toggle() end,                 desc = 'ListViewCtrl:on_toggle()' },
    { mode = 'i', key = '<Tab>',      cmd = function() self:on_toggle() end,                 desc = 'ListViewCtrl:on_toggle()' },
    { mode = 'n', key = '<Up>',       cmd = function() self:on_prev() end,                   desc = 'ListViewCtrl:on_prev()' },
    { mode = 'n', key = '<Down>',     cmd = function() self:on_next() end,                   desc = 'ListViewCtrl:on_next()' },
    { mode = 'i', key = '<Up>',       cmd = function() self:on_prev() end,                   desc = 'ListViewCtrl:on_prev()' },
    { mode = 'i', key = '<Down>',     cmd = function() self:on_next() end,                   desc = 'ListViewCtrl:on_next()' },
    { mode = 'i', key = m.pageup,     cmd = function() self:on_pageup() end,                 desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'i', key = m.pagedown,   cmd = function() self:on_pagedown() end,               desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'i', key = '<PageUp>',   cmd = function() self:on_pageup() end,                 desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'i', key = '<PageDown>', cmd = function() self:on_pagedown() end,               desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'n', key = m.pageup,     cmd = function() self:on_pageup() end,                 desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'n', key = m.pagedown,   cmd = function() self:on_pagedown() end,               desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'n', key = '<PageUp>',   cmd = function() self:on_pageup() end,                 desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'n', key = '<PageDown>', cmd = function() self:on_pagedown() end,               desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'n', key = m.confirm,    cmd = function() self:on_confirm() end,                desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'n', key = m.vsplit,     cmd = function() self:on_confirm({ split = 'v' }) end, desc = 'ListViewCtrl:on_confirm {split = v}' },
    { mode = 'n', key = m.split,      cmd = function() self:on_confirm({ split = 's' }) end, desc = 'ListViewCtrl:on_confirm {split = s}' },
    { mode = 'n', key = m.tabnew,     cmd = function() self:on_confirm({ split = 't' }) end, desc = 'ListViewCtrl:on_confirm {split = t}' },
    { mode = 'i', key = m.tabnew,     cmd = function() self:on_confirm({ split = 't' }) end, desc = 'ListViewCtrl:on_confirm {split = t}' },
    { mode = 'i', key = m.confirm,    cmd = function() self:on_confirm() end,                desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'n', key = m.close_view, cmd = function() self:on_close() end,                  desc = 'ListViewCtrl:on_close()' },
    { mode = 'n', key = m.send_qf,    cmd = function() self:on_quickfix() end,               desc = 'ListViewCtrl:on_quickfix()' },
    { mode = 'n', key = '<C-c>',      cmd = function() self:on_close() end,                  desc = 'ListViewCtrl:on_close()' },
    { mode = 'n', key = '<ESC><ESC>',      cmd = function() self:on_close() end,                  desc = 'ListViewCtrl:on_close()' },
    { mode = 'i', key = '<BS>',       cmd = function() self:on_backspace() end,              desc = 'ListViewCtrl:on_backspace()' },
    { mode = 'i', key = '<C-W>',      cmd = function() self:on_backspace(true) end,          desc = 'ListViewCtrl:on_backspace()' },
  }

  for i = 1, 9 do
    local idx = i
    keymaps[#keymaps + 1] = {
      -- stylua: ignore
      mode = 'n',
      key = tostring(idx),
      cmd = function() self:on_item(idx) end,
      desc = 'list on item num'
    }
  end

  if vim.keymap == nil then
    vim.notify('please use neovim 0.7 or later')
    return
  end
  for _, v in ipairs(keymaps) do
    vim.keymap.set(v.mode, v.key, v.cmd, { desc = v.desc, noremap = true, silent = true, buffer = delegate.buf })
  end

  -- stylua: ignore end
  self.augroup = vim.api.nvim_create_augroup('guihua_listview_' .. tostring(delegate.buf), { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
    buffer = delegate.buf,
    group = self.augroup,
    callback = function()
      self:on_search()
    end,
  })
  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = delegate.buf,
    group = self.augroup,
    callback = function()
      self:on_leave()
    end,
  })
  vim.api.nvim_create_autocmd('FocusGained', {
    group = self.augroup,
    callback = function()
      self:on_focus_gained(delegate.buf)
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = self.augroup,
    pattern = tostring(delegate.win),
    callback = function()
      SessionRegistry.close_preview(self.session)
      SessionRegistry.detach_controller(self.session, self)
      SessionRegistry.detach_list_view(self.session, delegate)
      self.closed = true
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufHidden', 'BufDelete' }, {
    buffer = delegate.buf,
    group = self.augroup,
    callback = function()
      SessionRegistry.close_preview(self.session)
    end,
  })

  SessionRegistry.attach_controller(self.session, self)
  SessionRegistry.activate(self.session)
  log('listview ctrl created ')
end

function ListViewCtrl:sync_state()
  if self.state == nil then
    return
  end

  self.selected_line = self.state.selected_line
  self.selected_lines = self.state.selected_lines
  self.display_start_at = self.state.display_start_at
  self.display_data = self.state.display_data
  self.data = self.state.data
  self.filtered_data = self.state.filtered_data
  self.filter_applied = self.state.filter_applied
  self.display_height = self.state.display_height
  self.search_item = self.state.search_item
end

function ListViewCtrl:apply_state_result(result, opts)
  if result == nil then
    return nil
  end

  self:sync_state()
  if result.redraw then
    self.m_delegate:on_draw(self.state.display_data)
  end

  self.m_delegate:set_pos(result.cursor_line or self.state:cursor_line())
  if opts == nil or opts.preview ~= false then
    local item = result.item
    if item ~= nil then
      self:wrap_closer(self.on_move(item))
    end
    return item
  end

  return result.item
end

function ListViewCtrl:get_ui()
  return self.m_delegate
end

function ListViewCtrl:wrap_closer(o)
  if o == nil then
    log('nil closer', debug.traceback())
    return
  end
  local _, delegate = current_delegate(self)
  if delegate ~= nil then
    SessionRegistry.attach_preview(self.session or delegate.session, o)
  end
  if o.class and o.class.name == 'TextView' then
    log('bind closer', o.class.name)
  end
end

function ListViewCtrl:clear_autocmds()
  local listobj = current_delegate(self)
  clear_autocmds(listobj)
end

function ListViewCtrl:on_focus_gained(bufnr)
  local listobj, delegate = current_delegate(self, bufnr)
  if listobj == nil or delegate == nil or on_preview(listobj) then
    return
  end
  SessionRegistry.activate(listobj.session)

  if vim.api.nvim_get_current_win() ~= delegate.win then
    vim.api.nvim_set_current_win(delegate.win)
  end

  if delegate.prompt and listobj.prompt_mode == 'insert' then
    vim.cmd('startinsert!')
  end
end

function ListViewCtrl:on_next()
  local listobj = current_delegate(self)
  if listobj == nil then
    log('failed to find ListViewObject')
    return
  end
  trace(
    'next: ',
    listobj.selected_line,
    listobj.display_start_at,
    listobj.display_height,
    listobj.selected_line + 1,
    listobj.state:visible_height()
  )
  return listobj:apply_state_result(listobj.state:move_next())
end

-- if list start with [i] then select the [i], otherwise return ith item
function ListViewCtrl:on_item(i)
  if i < 1 then
    i = 1
  end
  local listobj = current_delegate(self)
  if listobj == nil then
    log('incorrect on_prev context', ListViewCtrl)
    return
  end
  local item = listobj:apply_state_result(listobj.state:select_item(i))
  log('select ', listobj.selected_line, item)
  return item
end

function ListViewCtrl:on_prev()
  local listobj = current_delegate(self)
  if listobj == nil then
    log('incorrect on_prev context', ListViewCtrl)
    return
  end

  log(
    'on prev: ',
    listobj.selected_line,
    listobj.display_start_at,
    listobj.state:visible_height(),
    listobj.display_height,
    listobj.m_delegate.prompt
  )
  return listobj:apply_state_result(listobj.state:move_prev())
end

function ListViewCtrl:on_pagedown()
  self:draw_page(1)
end

function ListViewCtrl:on_pageup()
  self:draw_page(-1)
end

-- offset can be 1: page down, -1: page up or 0: doing nothing and redraw
function ListViewCtrl:draw_page(offset_direction)
  local listobj = current_delegate(self)
  if listobj == nil then
    return
  end
  trace(
    'pagedown: ',
    listobj.selected_line,
    listobj.display_start_at,
    listobj.display_height,
    listobj.display_start_at + offset_direction * listobj.state:visible_height(),
    listobj.state:visible_height()
  )
  return listobj:apply_state_result(listobj.state:draw_page(offset_direction))
end

function ListViewCtrl:on_toggle()
  local listobj = current_delegate(self)
  if listobj == nil then
    log('on_toggle failed, no listviewCTRL')
    return
  end
  local item = listobj:apply_state_result(listobj.state:toggle_current(), { preview = false })
  log('selected lines: ', listobj.selected_lines, item)
end

function ListViewCtrl:on_confirm(opts)
  local listobj = current_delegate(self)
  if listobj == nil then
    log('on_confirm failed, no listviewCTRL')
    return
  end
  local selection = listobj.state:current_item()
  close_controller(listobj)
  -- trace(listobj.m_delegate)
  if listobj.confirm_cb == nil or listobj.confirm_cb == ListViewCtrl.on_confirm then
    log('no on_confirm listobj and listviewctl is same')
    return
  end
  listobj.confirm_cb(selection, opts)
end

function ListViewCtrl:on_search()
  -- local cursor = vim.api.nvim_win_get_cursor(0)
  trace(debug.traceback())
  -- trace = log

  local listobj = current_delegate(self)
  if listobj == nil then
    log('on search failed, no listviewCTRL')
    -- why on_search bind here?
    return
  end
  if listobj.m_delegate.prompt ~= true then
    return
  end

  local filter = listobj.on_input_filter
  if filter == nil then
    filter = require('fzy').fzy
    if filter == nil then
      vim.notify('[ERR] fzy not found')
      return
    end
  else
    log('filter: ', listobj.on_input_filter, type(listobj.on_input_filter))
  end

  local buf = listobj.m_delegate.buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local filter_input = vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1]
  -- get string after prompt

  local filter_input_trim = string.sub(filter_input, 6, #filter_input) -- hardcode 6 '󱩾 ' is 5 chars
  log('filter input:', filter_input_trim, 'input:', filter_input)

  if listobj.search_item == filter_input_trim then
    return -- same filter may caused by none-search field change
  end
  if #filter_input_trim == 0 or #listobj.data == nil or #listobj.data == 0 then
    log('no filter')
    listobj:apply_state_result(listobj.state:apply_filter(nil, filter_input_trim), { preview = false })
    _GH_SEARCH_NS = _GH_SEARCH_NS or nil
    if _GH_SEARCH_NS == nil then
      return
    end
    vim.api.nvim_buf_clear_namespace(buf, _GH_SEARCH_NS, 0, -1)
    return
  else
    log('filter applied ', filter_input_trim)
    listobj:apply_state_result(listobj.state:apply_filter(filter(filter_input_trim, listobj.data), filter_input_trim), {
      preview = false,
    })
  end

  vim.api.nvim_buf_set_lines(buf, -2, -1, true, { filter_input })

  -- log(cursor)
  -- vim.api.nvim_win_set_cursor(0, cursor)
  vim.cmd([[normal! A]])
  vim.cmd('startinsert!')
  log('on search ends')
end

function ListViewCtrl:on_backspace(deleteword)
  local listobj = current_delegate(self)
  if listobj == nil then
    return
  end
  local buf = listobj.m_delegate.buf or vim.api.nvim_get_current_buf()
  local filter_input = vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1]
  local filter_input_trim = string.sub(filter_input, 6, #filter_input) -- hardcode 6 '󱩾 ' is 5 chars

  if #filter_input_trim == 0 then
    -- filter_input = string.sub(filter_input, 1, -2)
    return
  end

  vim.cmd([[stopi]])
  if deleteword then
    vim.cmd([[normal! diw]])
  else
    vim.cmd([[normal! cl]])
  end
  vim.cmd([[normal! A]])
  vim.cmd('startinsert!')
  self:on_search()

  -- log(filter_input)
  -- vim.api.nvim_buf_set_lines(buf, -2, -1, true, {filter_input})
  -- log(filter_input)
  -- log("on search ends")
end

function ListViewCtrl:on_quickfix()
  local listobj = current_delegate(self)
  if listobj == nil then
    return
  end
  local data = active_data(listobj)

  if listobj.selected_lines and next(listobj.selected_lines) then
    local data_sel = {}
    for i in ipairs(data) do
      if data[i].selected then
        data_sel[#data_sel + 1] = data[i]
      end
    end
    data = data_sel
  end

  log(data)
  local qf = require('guihua.util').symbols_to_items(data)
  if qf == nil or next(qf) == nil then
    return
  end
  log(qf)
  vim.fn.setqflist(qf)
  self:on_close()
  vim.cmd('copen')
end

function ListViewCtrl:on_close()
  log('closer listview') -- , ListViewCtrl._viewctlobject.m_delegate)
  local listobj = current_delegate(self)
  if listobj == nil then
    log('closer listview', debug.traceback()) --  ListViewCtrl._viewctlobject.m_delegate)
    return
  end
  close_controller(listobj)
end

function ListViewCtrl:on_leave(force)
  log('closer background')
  -- Capture delegate NOW (at call time), not at deferred-fire time.
  -- If _viewctlobject is replaced by a new M.select() call within the 10ms window,
  -- we must only close the old delegate, not the new one.
  local listobj, delegate = current_delegate(self)
  vim.defer_fn(function()
    if delegate and listobj and not listobj.closed and delegate.win ~= nil and api.nvim_win_is_valid(delegate.win) then
      if force then
        close_controller(listobj)
        return
      end
      if not on_preview(listobj) and not on_popup_window() then
        close_controller(listobj)
      end
    end
  end, 10)
end

function ListViewCtrl:on_data_update(data)
  local listobj = current_delegate(self)
  if listobj then
    listobj.state:set_data(data)
    listobj:sync_state()
  end
end

return ListViewCtrl
