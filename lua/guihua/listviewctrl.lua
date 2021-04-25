local class = require "middleclass"
local ViewController = require "guihua.viewctrl"
local log = require "guihua.log".info
local util = require "guihua.util"
local verbose = require "guihua.log".debug

if ListViewCtrl == nil then
  ListViewCtrl = class("ListViewCtrl", ViewController)
end

function ListViewCtrl:initialize(delegate, ...)
  verbose(debug.traceback())
  ViewController:initialize(delegate, ...)
  self.m_delegate = delegate
  self.selected_line = 1

  local opts = select(1, ...) or {}
  verbose("listview ctrl opts", opts)
  self.data = opts.data or {}
  self.preview = opts.preview or false
  self.display_height = self.m_delegate.display_height or 10
  self.display_start_at = 1
  self.on_move = opts.on_move or function(...)
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
  verbose("init display: ", self.display_data, self.display_height, self.selected_line)
  -- ... is the view
  -- todo location, readonly? and filetype
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-p>", "<cmd> lua ListViewCtrl:on_prev()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-n>", "<cmd> lua ListViewCtrl:on_next()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<Enter>", "<cmd> lua ListViewCtrl:on_confirm()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<Enter>", "<cmd> lua ListViewCtrl:on_search()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<Up>", "<cmd> lua ListViewCtrl:on_prev()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<Down>", "<cmd> lua ListViewCtrl:on_next()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<Up>", "<cmd> lua ListViewCtrl:on_prev()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<Down>", "<cmd> lua ListViewCtrl:on_next()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-o>", "<cmd> lua ListViewCtrl:on_confirm()<CR>", {})
  log('bind close', self.m_delegate.win, delegate.buf)

  -- util.close_view_event("n", "<C-e>", self.m_delegate.win, delegate.buf, opts.enter)
  -- util.close_view_event("i", "<C-e>", self.m_delegate.win,  delegate.buf, opts.enter)
  -- vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<esc>", "<cmd> lua require'guihua.ListViewCtrl':on_close() <CR>", {})
  -- vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-c>", "<cmd> lua require'guihua.ListViewCtrl':on_close() <CR>", {})
  -- vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<CR>", "<cmd> lua require'guihua.ListViewCtrl':on_close() <CR>", {})

  vim.cmd([[ autocmd TextChangedI <buffer> lua  require'guihua.ListViewCtrl':on_search() ]])

  ListViewCtrl._viewctlobject = self
  -- self:on_draw(self.display_data)
  -- self.m_delegate:set_pos(self.selected_line)
  verbose("listview ctrl created ", self)
end

function ListViewCtrl:get_ui()
  return self.m_delegate
end

function ListViewCtrl:wrap_closer(o)
  if o.class and o.class.name == "TextView" then
    ListViewCtrl._viewctlobject.textview_winnr = o.winnr
  end
end

function ListViewCtrl:on_next()
  local listobj = ListViewCtrl._viewctlobject

  if listobj.selected_line == nil then
    listobj.selected_line = 1
  end
  local l = listobj.selected_line + 1
  local data_collection = listobj.data
  if listobj.filter_applied then
    data_collection = listobj.filtered_data
  end
  local disp_h = listobj.display_height
  if listobj.m_delegate.prompt == true then
    disp_h = disp_h - 1
  end

  verbose("next: ", listobj.selected_line, listobj.display_start_at, listobj.display_height, l, disp_h)

  if l > #data_collection then
    listobj.m_delegate:set_pos(disp_h)
    listobj.on_move(#data_collection)
    log("next should show at: ", #listobj.data, "set: ", disp_h, listobj.display_height)
    return
  end

  if l > listobj.display_start_at + disp_h - 1 then
    -- need to scroll next
    listobj.display_start_at = listobj.display_start_at + 1
    listobj.display_data = {unpack(data_collection, listobj.display_start_at, listobj.display_start_at + disp_h - 1)}
    verbose("disp", listobj.display_data, disp_h, listobj.display_start_at)
    listobj.m_delegate:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(disp_h)
  else
    -- preview here
    -- listobj.m_delegate:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(l - listobj.display_start_at + 1)
  end

  -- log("next should show: ", listobj.display_data[l].text or listobj.display_data[l], listobj.display_start_at)
  listobj.selected_line = l
  self:wrap_closer(listobj.on_move(l))
  return data_collection[listobj.selected_line]
end



function ListViewCtrl:on_prev()
  local listobj = ListViewCtrl._viewctlobject

  local disp_h = listobj.display_height
  if listobj.m_delegate.prompt == true then
    disp_h = disp_h - 1
  end
  log(
    "pre: ",
    listobj.selected_line,
    listobj.display_start_at,
    disp_h,
    listobj.display_height,
    listobj.m_delegate.prompt
  )

  local data_collection = listobj.data
  if listobj.filter_applied then
    data_collection = listobj.filtered_data
  end

  if listobj.selected_line == nil then
    listobj.selected_line = 1
  end
  local l = listobj.selected_line - 1
  if l < 1 then
    listobj.m_delegate:set_pos(1)
    self:wrap_closer(listobj.on_move(1))
    return
  end
  if l < listobj.display_start_at and listobj.display_start_at >= 1 then
    -- need to scroll back
    listobj.display_start_at = listobj.display_start_at - 1
    listobj.display_data = {unpack(data_collection, listobj.display_start_at, listobj.display_start_at + disp_h - 1)}

    verbose("dispdata", listobj.display_data)
    listobj.m_delegate:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(1)
  else
    -- listobj:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(l - listobj.display_start_at + 1)
  end

  log("prev: ", l)
  -- log("prev: ", l, listobj.display_data[l].text or listobj.display_data[l])
  listobj.selected_line = l
  self:wrap_closer(listobj.on_move(l))
  return listobj.data[listobj.selected_line]
end

function ListViewCtrl:on_confirm()
  local listobj = ListViewCtrl._viewctlobject
  listobj.m_delegate:close()
  -- verbose(listobj.m_delegate)
  listobj.on_confirm(listobj.selected_line)
end

function ListViewCtrl:on_search()
  -- local cursor = vim.api.nvim_win_get_cursor(0)
  local fzy = require "fzy".fzy
  if fzy == nil then
    print("[ERR] fzy not found")
    return
  end
  local listobj = ListViewCtrl._viewctlobject
  local buf = listobj.m_delegate.buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local filter_input = vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1]
  -- get string after prompt

  local filter_input_trim = string.sub(filter_input, 5, #filter_input)
  verbose("filter input", filter_input_trim, filter_input)
  if #filter_input_trim == 0 or #listobj.data == nil or #listobj.data == 0 then
    return
  end
  listobj.filtered_data = fzy(filter_input_trim, listobj.data)
  --
  -- verbose("filtered data", listobj.filtered_data)
  --
  listobj.display_data = {unpack(listobj.filtered_data, 1, listobj.display_height)}
  listobj.filter_applied = true
  listobj.display_start_at = 1 -- reset
  --
  verbose("filtered data", listobj.display_data)
  listobj:on_draw(listobj.display_data)
  listobj.selected_line = 1
  listobj.m_delegate:set_pos(1)

  vim.api.nvim_buf_set_lines(buf, -2, -1, true, {filter_input})
  -- log(cursor)
  -- vim.api.nvim_win_set_cursor(0, cursor)
  vim.cmd([[normal! A]])
  vim.cmd('startinsert!')
  log("on search ends")
end

function ListViewCtrl:on_close()
  log("closer listview") --, ListViewCtrl._viewctlobject.m_delegate)
  ListViewCtrl._viewctlobject.m_delegate.close()
  ListViewCtrl._viewctlobject.m_delegate:on_close()
  ListViewCtrl._viewctlobject = nil
end

return ListViewCtrl
