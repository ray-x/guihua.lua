local viewctrl = require "guihua.viewctrl"
local log = require'luakit.utils.log'.log
local verbose = require'luakit.utils.log'.verbose
if listviewctrl == nil then
listviewctrl = class(viewctrl)
listviewctrl._class_name = "listviewctrl"
end

function listviewctrl:ctor(delegate, ...)
  self.m_delegate = delegate
  self.selected_line = 1

  local opts = select(1, ...) or {}
  verbose("listview ctrl opts", opts)
  self.data = opts.data or {}
  self.preview = opts.preview or false
  self.display_height = self.m_delegate.rect.height or 10
  self.display_start_at = 1
  if self.m_delegate.header ~= nil then
    self.display_height = self.display_height - 1
  end -- if need header will be - 2
  if self.m_delegate.prompt ~= nil then
    self.display_height = self.display_height - 1
  end -- if need header will be - 2
  if #self.data <= self.display_height then
    self.display_data = opts.data
  else
    self.display_data = {}
    for i = 1, self.display_height, 1 do
      table.insert(self.display_data, self.data[i])
    end
  end
  log("init display: ", self.display_data, self.display_height, self.selected_line)
  -- ... is the view
  -- todo location, readonly? and filetype
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-p>", "<cmd> lua listviewctrl:on_prev()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-n>", "<cmd> lua listviewctrl:on_next()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<Up>", "<cmd> lua listviewctrl:on_prev()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<Down>", "<cmd> lua listviewctrl:on_next()<CR>", {})
  -- vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<esc>", "<cmd> lua require'guihua.listviewctrl':on_close() <CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-c>", "<cmd> lua require'guihua.listviewctrl':on_close() <CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<CR>", "<cmd> lua require'guihua.listviewctrl':on_close() <CR>", {})

  vim.cmd([[ autocmd TextChangedI <buffer> lua  require'guihua.listviewctrl':on_search() ]])

  listviewctrl._viewctlobject = self
  -- self:on_draw(self.display_data)
  -- self.m_delegate:set_pos(self.selected_line)
  log("listview ctrl created ")
end

function listviewctrl:get_ui()
  return self.m_delegate
end

function listviewctrl:previewfile(line)
  if self.preview ~= nil then
    -- todo preview
    return
  end
end

function listviewctrl:on_next()
  local listobj = listviewctrl._viewctlobject

  log("next: ",  listobj.selected_line, listobj.display_start_at, listobj.display_height)
  if listobj.selected_line == nil then listobj.selected_line = 1 end
  local l = listobj.selected_line + 1
  local data_collection = listobj.data
  if listobj.filter_applied then data_collection = listobj.filtered_data end

  if l > #data_collection then
    listobj.m_delegate:set_pos(listobj.display_height)
    listobj:previewfile(data_collection[#data_collection])
    return
  end
  if l > listobj.display_start_at + listobj.display_height - 1 and l <= #data_collection then
    -- need to scroll next
    listobj.display_start_at = listobj.display_start_at + 1
    listobj.display_data = {unpack(data_collection, listobj.display_start_at, listobj.display_start_at + listobj.display_height -
    1)}
    listobj:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(listobj.display_height)
  else
    -- preview here
    listobj:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(l - listobj.display_start_at + 1)
  end

  log("next should show: ", listobj.display_data )
  listobj.selected_line = l
  listobj:previewfile(data_collection[listobj.selected_line])
  log("next:  ",  listobj.selected_line, listobj.display_start_at )
  return data_collection[listobj.selected_line]
end

function listviewctrl:on_prev(data)
  local listobj = listviewctrl._viewctlobject

  log("pre: ",  listobj.selected_line, listobj.display_start_at )

  local data_collection = listobj.data
  if listobj.filter_applied then data_collection = listobj.filtered_data end

  if listobj.selected_line == nil then listobj.selected_line = 1 end
  local l = listobj.selected_line - 1
  if l < 1 then
    listobj.m_delegate:set_pos(1)
    listobj:previewfile(data_collection[l])
    return
  end
  if l < listobj.display_start_at and listobj.display_start_at >= 1 then
    -- need to scroll back
    listobj.display_start_at = listobj.display_start_at - 1
    listobj.display_data = {unpack(data_collection, listobj.display_start_at, listobj.display_start_at + listobj.display_height - 1 )}
    listobj:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(1)
  else
    listobj:on_draw(listobj.display_data)
    listobj.m_delegate:set_pos(l - listobj.display_start_at + 1)
  end

  log("prev: ", l, listobj.display_data )
  listobj.selected_line = l
  listobj:previewfile(data_collection[l])
  return listobj.data[listobj.selected_line]
end

function listviewctrl:on_search()
  local fzy = require'fzy'.fzy
  if fzy == nil then return end
  local listobj = listviewctrl._viewctlobject
  local buf = listobj.m_delegate.buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local filter_input = vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1]
  -- get string after prompt

  filter_input = string.sub(filter_input, 5, #filter_input)
  log('input', filter_input)
  listobj.filtered_data = fzy(filter_input, listobj.data)

  log('filtered data', listobj.filtered_data)

  listobj.filter_applied = true
  listobj.display_data = {unpack(listobj.filtered_data, 1, listobj.display_height)}

  log('filtered data', listobj.display_data)
  listobj:on_draw(listobj.display_data)
  listobj.selected_line = 1
  listobj.m_delegate:set_pos(1)
  log('on search ends')
end


function listviewctrl:dtor(...)
  log("listviewctrl dtor ")
  self.m_delegate = nil
end

function listviewctrl:on_close()
  listviewctrl._viewctlobject.m_delegate:on_close()
  listviewctrl._viewctlobject = nil
end

return listviewctrl
