local class = require('middleclass')
local ViewController = require('guihua.viewctrl')
local error = require('guihua.log').error
local util = require('guihua.util')

local log = require('guihua.log').info
local trace = require('guihua.log').trace
_GH_SETUP = _GH_SETUP or require('guihua.maps').setup()
ListView = ListView or nil
if _GH_SETUP == nil then
  _GH_SETUP = require('guihua.maps').setup()
end
TextView = TextView or require('guihua.textview')
if ListViewCtrl == nil then
  ListViewCtrl = class('ListViewCtrl', ViewController)
end

-- local function gh_jump_to_win()
--   local currentWinnr = vim.api.nvim_get_current_win()
--   local jumpto = TextView.ActiveTextView.win
--   if jumpto == currentWinnr then
--     jumpto = ListView.Winnr
--   end
--
--   if jumpto ~= nil and vim.api.nvim_win_is_valid(jumpto) then
--     log('jump from ', currentWinnr, 'to', jumpto)
--     vim.api.nvim_set_current_win(jumpto)
--   end
-- end

function ListViewCtrl:gh_jump_to_list()
  if ListView == nil then
    return
  end
  local jumpto = ListView.Winnr
  if jumpto ~= nil and vim.api.nvim_win_is_valid(jumpto) then
    log('jump to', jumpto)
    vim.cmd(string.format('noa call nvim_set_current_win(%s)', jumpto))
    return
  end
end

function ListViewCtrl:gh_jump_to_preview()
  if TextView == nil or TextView.ActiveTextView == nil then
    return
  end
  local jumpto = TextView.ActiveTextView.win
  if jumpto ~= nil and vim.api.nvim_win_is_valid(jumpto) then
    log('jump to', jumpto)
    vim.cmd(string.format('noa call nvim_set_current_win(%s)', jumpto))
    return
  end
end

local function on_preview()
  if TextView == nil or TextView.ActiveTextView == nil then
    return false
  end
  local jumpto = TextView.ActiveTextView.win
  return jumpto ~= nil and vim.api.nvim_win_is_valid(jumpto)
end

function ListViewCtrl:initialize(delegate, ...)
  trace(debug.traceback())
  ViewController:initialize(delegate, ...)
  self.m_delegate = delegate
  self.selected_line = 1
  self.selected_lines = {}
  --
  local opts = select(1, ...) or {}
  trace('listview ctrl opts', opts)
  self.data = opts.data or {}
  self.preview = opts.preview or false
  self.prompt = opts.prompt
  self.prompt_mode = opts.prompt_mode
  self.enter = opts.enter
  self.on_input_filter = opts.on_input_filter
  self.display_height = self.m_delegate.display_height or 10
  self.display_start_at = 1
  self.on_move = opts.on_move or function(...)
    _ = { ... }
  end
  self.on_confirm = opts.on_confirm
  if #self.data <= self.display_height then
    self.display_data = opts.data
  else
    self.display_data = {}
    for i = 1, self.display_height, 1 do
      table.insert(self.display_data, self.data[i])
    end
  end

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
    { mode = 'n', key = m.prev, cmd = function() ListViewCtrl:on_prev() end, desc = 'ListViewCtrl:on_prev()' },
    { mode = 'i', key = m.prev, cmd = function() ListViewCtrl:on_prev() end, desc = 'ListViewCtrl:on_prev()' },
    { mode = 'n', key = m.next, cmd = function() ListViewCtrl:on_next() end, desc = 'ListViewCtrl:on_next()' },
    { mode = 'i', key = m.next, cmd = function() ListViewCtrl:on_next() end, desc = 'ListViewCtrl:on_next()' },
    { mode = 'n', key = '<Enter>', cmd = function() ListViewCtrl:on_confirm() end, desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'i', key = '<Enter>', cmd = function() ListViewCtrl:on_confirm() end, desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'n', key = '<C-w>j', cmd = function () ListViewCtrl:gh_jump_to_preview() end, desc = 'jump to preview' },
    { mode = 'n', key = 'k', cmd = function() ListViewCtrl:on_prev() end, desc = 'ListViewCtrl:on_prev()' },
    { mode = 'n', key = 'j', cmd = function() ListViewCtrl:on_next() end, desc = 'ListViewCtrl:on_next()' },
    { mode = 'n', key = '<Tab>', cmd = function() ListViewCtrl:on_toggle() end, desc = 'ListViewCtrl:on_toggle()' },
    { mode = 'i', key = '<Tab>', cmd = function() ListViewCtrl:on_toggle() end, desc = 'ListViewCtrl:on_toggle()' },
    { mode = 'n', key = '<Up>', cmd = function() ListViewCtrl:on_prev() end, desc = 'ListViewCtrl:on_prev()' },
    { mode = 'n', key = '<Down>', cmd = function() ListViewCtrl:on_next() end, desc = 'ListViewCtrl:on_next()' },
    { mode = 'i', key = '<Up>', cmd = function() ListViewCtrl:on_prev() end, desc = 'ListViewCtrl:on_prev()' },
    { mode = 'i', key = '<Down>', cmd = function() ListViewCtrl:on_next() end, desc = 'ListViewCtrl:on_next()' },
    { mode = 'i', key = m.pageup, cmd = function() ListViewCtrl:on_pageup() end, desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'i', key = m.pagedown, cmd = function() ListViewCtrl:on_pagedown() end, desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'i', key = '<PageUp>', cmd = function() ListViewCtrl:on_pageup() end, desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'i', key = '<PageDown>', cmd = function() ListViewCtrl:on_pagedown() end, desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'n', key = m.pageup, cmd = function() ListViewCtrl:on_pageup() end, desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'n', key = m.pagedown, cmd = function() ListViewCtrl:on_pagedown() end, desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'n', key = '<PageUp>', cmd = function() ListViewCtrl:on_pageup() end, desc = 'ListViewCtrl:on_pageup()' },
    { mode = 'n', key = '<PageDown>', cmd = function() ListViewCtrl:on_pagedown() end, desc = 'ListViewCtrl:on_pagedown()' },
    { mode = 'n', key = m.confirm, cmd = function() ListViewCtrl:on_confirm() end, desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'n', key = m.vsplit, cmd = function() ListViewCtrl:on_confirm({ split = 'v' }) end, desc = 'ListViewCtrl:on_confirm {split = v}'},
    { mode = 'n', key = m.split, cmd = function() ListViewCtrl:on_confirm({ split = 's' }) end, desc = 'ListViewCtrl:on_confirm {split = s}'},
    { mode = 'n', key = m.tabnew, cmd = function() ListViewCtrl:on_confirm({ split = 't' }) end, desc = 'ListViewCtrl:on_confirm {split = t}'},
    { mode = 'i', key = m.tabnew, cmd = function() ListViewCtrl:on_confirm({ split = 't' }) end, desc = 'ListViewCtrl:on_confirm {split = t}'},
    { mode = 'i', key = m.confirm, cmd = function() ListViewCtrl:on_confirm() end, desc = 'ListViewCtrl:on_confirm()' },
    { mode = 'n', key = m.close_view, cmd = function() ListViewCtrl:on_close() end, desc = 'ListViewCtrl:on_close()' },
    { mode = 'n', key = m.send_qf, cmd = function() ListViewCtrl:on_quickfix() end, desc = 'ListViewCtrl:on_quickfix()' },
    { mode = 'n', key = '<C-c>', cmd = function() ListViewCtrl:on_close() end, desc = 'ListViewCtrl:on_close()' },
    { mode = 'n', key = '<ESC>', cmd = function() ListViewCtrl:on_close() end, desc = 'ListViewCtrl:on_close()' },
    { mode = 'i', key = '<BS>', cmd = function() ListViewCtrl:on_backspace() end, desc = 'ListViewCtrl:on_backspace()' },
    { mode = 'i', key = '<C-W>', cmd = function() ListViewCtrl:on_backspace(true) end, desc = 'ListViewCtrl:on_backspace()' },
  }

  for i = 1, 9 do
    keymaps[#keymaps + 1] = {
      -- stylua: ignore
      mode = 'n', key = tostring(i), cmd = function() ListViewCtrl:on_item(i) end, desc = 'list on item num'}
  end

  if vim.keymap == nil then
    vim.notify('please use neovim 0.7 or later')
    return
  end
  for _, v in ipairs(keymaps) do
    vim.keymap.set(v.mode, v.key, v.cmd, { desc = v.desc, noremap = true, silent = true, buffer = delegate.buf })
  end

  -- stylua: ignore end
  vim.cmd([[ autocmd TextChangedI,TextChanged <buffer> lua  ListViewCtrl:on_search() ]])
  vim.cmd([[ autocmd WinLeave <buffer> ++once lua  ListViewCtrl:on_leave() ]])

  --
  ListViewCtrl._viewctlobject = self
  log('listview ctrl created ')
end

function ListViewCtrl:get_ui()
  return self.m_delegate
end

function ListViewCtrl:wrap_closer(o)
  if o == nil then
    log('nil closer', debug.traceback())
    return
  end
  if o.class and o.class.name == 'TextView' then
    -- ListViewCtrl._viewctlobject.win = o.ActiveView.win -- ListViewCtrl._viewctlobject.buf = o.ActiveView.buf
    log('bind closer', o.class.name)
  end
end

function ListViewCtrl:on_next()
  local listobj = ListViewCtrl._viewctlobject
  if listobj == nil then
    log('failed to find ListViewObject')
    return
  end

  if listobj.selected_line == nil then
    listobj.selected_line = 1
  end
  local l = listobj.selected_line + 1
  local data_collection = listobj.data
  if listobj.filter_applied == true then
    log('filter applied')
    data_collection = listobj.filtered_data
  end
  if #data_collection == 0 then
    return {}
  end

  local disp_h = listobj.display_height
  if listobj.m_delegate.prompt == true then
    disp_h = disp_h - 1
  end

  trace(
    'next: ',
    listobj.selected_line,
    listobj.display_start_at,
    listobj.display_height,
    l,
    disp_h
  )

  if l > #data_collection then
    -- stylua: ignore
    log(
      'out of boundary next should show at: ',
      #listobj.data, 'set: l', l, 'collection', #data_collection,
      'disp_h', disp_h, listobj.display_height)
    return {}
  end
  local skipped_fn = 1
  if data_collection[l].filename_only and not listobj.filter_applied == true then
    if l + 1 <= #data_collection then
      l = l + 1
      skipped_fn = 2
    else
      return {}
    end
  end

  if l + 1 > listobj.display_start_at + disp_h then
    -- need to scroll next
    listobj.display_start_at = listobj.display_start_at + skipped_fn
    listobj.display_data = {
      unpack(data_collection, listobj.display_start_at, listobj.display_start_at + disp_h - 1),
    }
    trace('disp', listobj.display_data, disp_h, listobj.display_start_at)
    listobj.m_delegate:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(disp_h)
  else
    -- preview here
    -- listobj.m_delegate:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(l - listobj.display_start_at + 1)
  end

  -- log("next should show: ", listobj.display_data[l].text or listobj.display_data[l], listobj.display_start_at)
  listobj.selected_line = l
  self:wrap_closer(listobj.on_move(data_collection[l]))
  return data_collection[listobj.selected_line]
end

local function item_text(data_collection, idx)
  local text
  if idx < 1 or idx > #data_collection then
    error('error: idx out of range', #data_collection, idx)
  end
  if type(data_collection[idx]) == 'string' then
    text = data_collection[idx]
  elseif data_collection[idx].display_data ~= nil then
    text = data_collection[idx].display_data
  elseif data_collection[idx].text ~= nil then
    text = data_collection[idx].text
  end
  return text
end
-- if list start with [i] then select the [i], otherwise return ith item
function ListViewCtrl:on_item(i)
  if i < 1 then
    i = 1
  end
  local listobj = ListViewCtrl._viewctlobject
  if listobj == nil then
    log('incorrect on_prev context', ListViewCtrl)
    return
  end

  local data_collection = listobj.data

  if i > #data_collection then
    i = #data_collection
  end

  local idx
  for j = i, i + 3 do
    log(data_collection[j])
    if j > #data_collection then
      break
    end
    if data_collection[j] and data_collection[j].idx == i then
      idx = j
      break
    end
    local t = item_text(data_collection, j)
    local f = string.find(t or '', tostring(i))
    if f ~= nil and f < 4 then
      idx = j
      break
    end
  end

  if idx then
    i = idx
  end

  listobj.m_delegate:set_pos(i)
  listobj.selected_line = i
  log('select ', i, data_collection[listobj.selected_line])
  self:wrap_closer(listobj.on_move(data_collection[i]))

  return data_collection[listobj.selected_line]
end

function ListViewCtrl:on_prev()
  local listobj = ListViewCtrl._viewctlobject
  if listobj == nil then
    log('incorrect on_prev context', ListViewCtrl)
    return
  end

  local disp_h = listobj.display_height
  if listobj.m_delegate.prompt == true then
    disp_h = disp_h - 1
  end

  log(
    'on prev: ',
    listobj.selected_line,
    listobj.display_start_at,
    disp_h,
    listobj.display_height,
    listobj.m_delegate.prompt
  )

  local data_collection = listobj.data
  if listobj.filter_applied == true then
    data_collection = listobj.filtered_data
  end

  if #data_collection == 0 then
    return {}
  end
  if listobj.selected_line == nil then
    listobj.selected_line = 1
  end

  local l = listobj.selected_line - 1
  if l < 1 then
    listobj.m_delegate:set_pos(1)
    self:wrap_closer(listobj.on_move(data_collection[1]))
    return
  end
  local skipped_fn = 1
  if data_collection[l].filename_only and l > 1 then
    trace('skip filename')
    skipped_fn = 2
    l = l - 1
  end
  if l < listobj.display_start_at and listobj.display_start_at >= 1 then
    -- need to scroll back
    log('roll back to ', listobj.display_start_at - 1)
    listobj.display_start_at = listobj.display_start_at - skipped_fn
    listobj.display_data = {
      unpack(data_collection, listobj.display_start_at, listobj.display_start_at + disp_h - 1),
    }

    trace('dispdata', listobj.display_data)
    listobj.m_delegate:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(1)
  else
    log('move to', l, listobj.display_start_at, l - listobj.display_start_at + 1)
    listobj.m_delegate:set_pos(l - listobj.display_start_at + 1)
  end
  log('prev: ', l)
  -- log("prev: ", l, listobj.display_data[l].text or listobj.display_data[l])
  listobj.selected_line = l
  self:wrap_closer(listobj.on_move(data_collection[l]))
  return data_collection[listobj.selected_line]
end

function ListViewCtrl:on_pagedown()
  ListViewCtrl:draw_page(1)
end

function ListViewCtrl:on_pageup()
  ListViewCtrl:draw_page(-1)
end

-- offset can be 1: page down, -1: page up or 0: doing nothing and redraw
function ListViewCtrl:draw_page(offset_direction)
  local listobj = ListViewCtrl._viewctlobject

  local disp_h = listobj.display_height

  if listobj.selected_line == nil then
    listobj.selected_line = 1
  end
  local data_collection = listobj.data
  if listobj.filter_applied == true then
    data_collection = listobj.filtered_data
  end
  -- local disp_h = listobj.display_height
  if listobj.m_delegate.prompt == true then
    disp_h = disp_h - 1
  end

  local l = listobj.display_start_at + offset_direction * disp_h

  trace(
    'pagedown: ',
    listobj.selected_line,
    listobj.display_start_at,
    listobj.display_height,
    l,
    disp_h
  )

  if l < 1 then
    listobj.m_delegate:set_pos(1)
    listobj.on_move(data_collection[1])
    log('prev should show at: ', #listobj.data, 'set: ', disp_h, listobj.display_height)
    return
  end

  if l > #data_collection then
    listobj.m_delegate:set_pos(disp_h)
    listobj.on_move(data_collection[#data_collection])
    log('next should show at: ', #listobj.data, 'set: ', disp_h, listobj.display_height)
    return
  end

  listobj.display_start_at = l
  listobj.display_data = {
    unpack(data_collection, listobj.display_start_at, listobj.display_start_at + disp_h - 1),
  }
  trace('disp', listobj.display_data, disp_h, listobj.display_start_at)
  listobj.m_delegate:on_draw(listobj.display_data)
  if offset_direction ~= 0 then
    listobj.m_delegate:set_pos(disp_h)
    listobj.selected_line = l
    self:wrap_closer(listobj.on_move(data_collection[l]))
  end

  -- log("next should show: ", listobj.display_data[l].text or listobj.display_data[l], listobj.display_start_at)
  return data_collection[listobj.selected_line]
end

function ListViewCtrl:on_toggle()
  local listobj = ListViewCtrl._viewctlobject
  -- local data_collection = listobj.data
  if listobj.selected_lines == nil then
    listobj.selected_lines = {}
  end
  local on = false
  if vim.tbl_contains(listobj.selected_lines, listobj.selected_line) then
    util.tbl_remove(listobj.selected_lines, listobj.selected_line)
  else
    on = true
  end

  if listobj.filter_applied == true then
    listobj.filtered_data[listobj.selected_line].selected = on
  else
    listobj.data[listobj.selected_line].selected = on
  end

  listobj.selected_lines[#listobj.selected_lines + 1] = listobj.selected_line
  log('selected lines: ', listobj.selected_lines, listobj.data[listobj.selected_line])
  listobj:draw_page(0)
end

function ListViewCtrl:on_confirm(opts)
  local listobj = ListViewCtrl._viewctlobject
  local data_collection = listobj.data
  if listobj.filter_applied == true then
    data_collection = listobj.filtered_data
  end
  listobj.m_delegate:close()
  -- trace(listobj.m_delegate)
  if listobj.on_confirm == ListViewCtrl.on_confirm then
    log('no on_confirm listobj and listviewctl is same')
    return
  end
  listobj.on_confirm(data_collection[listobj.selected_line], opts)
end

function ListViewCtrl:on_search()
  -- local cursor = vim.api.nvim_win_get_cursor(0)
  trace(debug.traceback())
  -- trace = log

  local listobj = ListViewCtrl._viewctlobject
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

  local filter_input_trim = string.sub(filter_input, 6, #filter_input)  -- hardcode 6 '󱩾 ' is 5 chars
  log('filter input:', filter_input_trim, 'input:', filter_input)

  if listobj.search_item == filter_input_trim then
    return -- same filter may caused by none-search field change
  end
  listobj.search_item = filter_input_trim

  if #filter_input_trim == 0 or #listobj.data == nil or #listobj.data == 0 then
    log('no filter')
    listobj.filter_applied = false
    listobj.filtered_data = vim.deepcopy(listobj.data) -- filter is not applied, clean up cache data

    listobj.display_data = { unpack(listobj.filtered_data, 1, listobj.display_height) }
    listobj.display_start_at = 1 -- reset
    listobj:on_draw(listobj.display_data)
    _GH_SEARCH_NS = _GH_SEARCH_NS or nil
    if _GH_SEARCH_NS == nil then
      return
    end
    vim.api.nvim_buf_clear_namespace(buf, _GH_SEARCH_NS, 0, -1)
    return
  else
    log('filter applied ', filter_input_trim)
    listobj.filtered_data = filter(filter_input_trim, listobj.data)
  end
  trace('filtered data', listobj.filtered_data)
  listobj.display_data = { unpack(listobj.filtered_data, 1, listobj.display_height) }
  listobj.filter_applied = true
  listobj.display_start_at = 1 -- reset
  --
  trace('filtered data', listobj.display_data)
  listobj:on_draw(listobj.display_data)
  listobj.selected_line = 1
  listobj.m_delegate:set_pos(1)

  vim.api.nvim_buf_set_lines(buf, -2, -1, true, { filter_input })

  -- log(cursor)
  -- vim.api.nvim_win_set_cursor(0, cursor)
  vim.cmd([[normal! A]])
  vim.cmd('startinsert!')
  log('on search ends')
end

function ListViewCtrl:on_backspace(deleteword)
  local listobj = ListViewCtrl._viewctlobject
  local buf = listobj.m_delegate.buf or vim.api.nvim_get_current_buf()
  local filter_input = vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1]
  local filter_input_trim = string.sub(filter_input, 6, #filter_input)  -- hardcode 6 '󱩾 ' is 5 chars

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
  ListViewCtrl:on_search()

  -- log(filter_input)
  -- vim.api.nvim_buf_set_lines(buf, -2, -1, true, {filter_input})
  -- log(filter_input)
  -- log("on search ends")
end

function ListViewCtrl:on_quickfix()
  local listobj = ListViewCtrl._viewctlobject
  local data = listobj.filtered_data or listobj.data

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
  ListViewCtrl:on_close()
  vim.cmd('copen')
end

function ListViewCtrl:on_close()
  log('closer listview') -- , ListViewCtrl._viewctlobject.m_delegate)
  if ListViewCtrl._viewctlobject == nil then
    log('closer listview', debug.traceback()) --  ListViewCtrl._viewctlobject.m_delegate)
    return
  end
  ListViewCtrl._viewctlobject.m_delegate.close()

  ListViewCtrl._viewctlobject.m_delegate:on_close()
  ListViewCtrl:on_leave(true)
  ListViewCtrl._viewctlobject = nil
end

function ListViewCtrl:on_leave(force)
  log('closer background') -- , ListViewCtrl._viewctlobject.m_delegate)
  vim.defer_fn(function()
    -- return
    if ListViewCtrl._viewctlobject and ListViewCtrl._viewctlobject.m_delegate then
      if force then
        ListViewCtrl._viewctlobject.m_delegate.close()
      end
      if not on_preview() then
        ListViewCtrl._viewctlobject.m_delegate.close()
      end
    end
  end, 10)
end

function ListViewCtrl:on_data_update(data)
  local listobj = ListViewCtrl._viewctlobject
  if listobj then
    listobj.data = data
  end
end

return ListViewCtrl
