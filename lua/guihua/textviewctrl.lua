local class = require('middleclass')

local ViewController = require('guihua.viewctrl')
local util = require('guihua.util')
local api = vim.api
local log = require('guihua.log').info

local trace = require('guihua.log').trace

if _GH_SETUP == nil then
  require('guihua.maps').setup()
end
if TextViewCtrl == nil then
  TextViewCtrl = class('TextViewCtrl')
end -- no need to subclass from viewctrl

function TextViewCtrl:initialize(delegate, ...)
  trace(debug.traceback())
  ViewController:initialize(delegate, ...)
  self.m_delegate = delegate

  local opts = select(1, ...) or {}
  log('textview ctrl opts', opts.uri)

  self.file_info = opts
  self.display_height = self.m_delegate.display_height or 10
  self.file_info.lines = self.display_height
  if opts.data == nil or opts.data == {} or #opts.data < 1 and opts.uri == nil then
    log('data not provided opts', opts)
    -- self.on_load(opts)
    -- local data = self:on_load(opts)
    -- log("will displaying", data)
    -- self.m_delegate:on_draw(data)
  end

  local m = _GH_SETUP.maps
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
  vim.api.nvim_buf_set_keymap(delegate.buf, 'n', m.save, '<cmd>lua TextViewCtrl:on_save()<CR>', {})
  vim.api.nvim_buf_set_keymap(delegate.buf, 'n', m.jump_to_list, '<cmd>lua gh_jump_to_list()<CR>', {})

  log('bind close', self.m_delegate.win, delegate.buf)
  if opts.edit then
    vim.cmd([[ autocmd TextChangedI <buffer> lua ListViewCtrl:on_search() ]])
  end
  TextViewCtrl._viewctlobject = self
  -- self:on_draw(self.display_data)
  -- self.m_delegate:set_pos(self.selected_line)
  log('textview ctrl created ')
end

-- load file uri if data is nil
-- need to call after floatwind is created or caller need pass the winnr
function TextViewCtrl:on_load(opts) -- location, width, pos_x, pos_y
  opts = opts or {}
  trace(opts)
  local uri = opts.uri
  if opts.uri == nil then
    log('invalid/nil uri ', opts)
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    log('load buf', uri, bufnr)
    vim.fn.bufload(bufnr)
  end
  --

  local range = opts.display_range or opts.range
  if range.start == nil then
    print('error invalid range')
    return
  end
  log(bufnr, range.start.line, uri)
  local s = range.start.line
  local e = range['end'].line
  if e == s then
    if s < 2 then
      s = 0
    else
      s = s - 2
    end
    e = math.max(e + 2, s + opts.rect.height)

    log('not going to show 1 line range:', s, e)
  end
  range.start.line = s
  range['end'].line = e
  local contents = api.nvim_buf_get_lines(bufnr, s, e, false)
  local lines = #contents
  local syntax = opts.syntax
  if syntax == nil or #syntax < 1 then
    syntax = api.nvim_buf_get_option(bufnr, 'ft')
  end

  -- TODO: for saving, need update file_info based on data loaded, e.g. if we only load 1 line, but display_height is 10
  self.file_info.lines = lines
  -- TODO should we create a float win based on opened buffer?
  trace(syntax, contents, self.file_info)
  return contents, syntax -- allow contents be handled by caller
end

-- call from event
-- get floatwin bufnr, get content, get file range and write to file range
function TextViewCtrl:on_save()
  local txtbufnr = TextViewCtrl._viewctlobject.m_delegate.buf

  local file_info = TextViewCtrl._viewctlobject.file_info
  local contents = api.nvim_buf_get_lines(txtbufnr, 0, file_info.lines, false)
  log(contents, file_info)

  if not file_info.allow_edit then
    return
  end
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
