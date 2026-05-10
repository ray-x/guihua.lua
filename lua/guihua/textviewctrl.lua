local class = require('middleclass')

local ViewController = require('guihua.viewctrl')
local util = require('guihua.util')
local api = vim.api

local log = require('guihua.log').info
local trace = require('guihua.log').trace

if TextViewCtrl == nil then
  TextViewCtrl = class('TextViewCtrl')
end -- no need to subclass from viewctrl

function TextViewCtrl:initialize(delegate, ...)
  ViewController:initialize(delegate, ...)
  self.m_delegate = delegate

  local opts = select(1, ...) or {}
  log('textview ctrl opts', opts.uri)
  self.display_height = self.m_delegate.display_height or 10

  local m = require('guihua').ensure_setup().maps
  if not opts.enter then
    -- currsor move will close textview. currently disabled because user can edit inside preview
    log('auto close on cursor move disabled')
  else
    -- for user case of symbol definition preview, <c-e> close win/buf
    log('winnr bufnr closer', self.m_delegate.win, self.m_delegate.buf)

    util.close_view_event('n', m.close_view, self.m_delegate.win, self.m_delegate.buf, opts.enter)
    util.close_view_event('i', m.close_view, self.m_delegate.win, self.m_delegate.buf, opts.enter)
  end
  trace('init display: ', self.display_data, self.display_height, self.selected_line)
  -- ... is the view
  -- todo location, readonly? and filetype
  vim.keymap.set('n', m.save, '<cmd>lua TextViewCtrl:on_save()<CR>', { buffer = delegate.buf, noremap = true })
  vim.keymap.set(
    'n',
    m.jump_to_list,
    '<cmd>lua ListViewCtrl:gh_jump_to_list()<CR>',
    { buffer = delegate.buf, noremap = true }
  )

  log('bind close', self.m_delegate.win, delegate.buf)
  if opts.edit then
    vim.cmd([[ autocmd TextChangedI <buffer> lua ListViewCtrl:on_search() ]])
  end
  TextViewCtrl._viewctlobject = self
  -- self:on_draw(self.display_data)
  -- self.m_delegate:set_pos(self.selected_line)
  log('textview ctrl created ')
end

-- call from event
-- get floatwin bufnr, get content, get file range and write to file range
function TextViewCtrl:on_save()
  local txtbufnr = TextViewCtrl._viewctlobject.m_delegate.buf

  local file_info = TextViewCtrl._viewctlobject.m_delegate.file_info
  if file_info == nil or file_info.uri == nil then
    log('on_save: invalid file_info')
    return
  end

  if not file_info.allow_edit then
    return
  end

  local contents = api.nvim_buf_get_lines(txtbufnr, 0, file_info.lines, false)
  log(contents, file_info)
  log('save file info', file_info)
  local bufnr = vim.uri_to_bufnr(file_info.uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  local range = file_info.display_range
  if range == nil then
    log('incorrect file info, can not save')
  end

  log(bufnr, range, file_info.lines, contents)
  if range == nil or range.start == nil or file_info == nil then
    return
  end
  vim.api.nvim_buf_set_lines(bufnr, range.start.line, range.start.line + file_info.lines, true, contents)
end

return TextViewCtrl
