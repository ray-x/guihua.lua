local class = require "middleclass"

local ViewController = require "guihua.viewctrl"
local util = require "guihua.util"
local api = vim.api
local log = require"guihua.log".info

local trace = require"guihua.log".trace

if TextViewCtrl == nil then TextViewCtrl = class("TextViewCtrl") end -- no need to subclass from viewctrl

function TextViewCtrl:initialize(delegate, ...)
  trace(debug.traceback())
  ViewController:initialize(delegate, ...)
  self.m_delegate = delegate

  local opts = select(1, ...) or {}
  log("textview ctrl opts")
  trace(opts)

  self.file_info = opts
  self.display_height = self.m_delegate.display_height or 10
  self.file_info.lines = self.display_height
  if opts.data == nil or opts.data == {} or #opts.data < 1 and opts.uri ~= nil then
    log("data not provided opts", opts)
    -- self.on_load(opts)
    -- local data = self:on_load(opts)
    -- log("will displaying", data)
    -- self.m_delegate:on_draw(data)
  end

  trace("init display: ", self.display_data, self.display_height, self.selected_line)
  -- ... is the view
  -- todo location, readonly? and filetype
  vim.api
      .nvim_buf_set_keymap(delegate.buf, "n", "<C-s>", "<cmd> lua TextViewCtrl:on_save()<CR>", {})
  log("bind close", self.m_delegate.win, delegate.buf)

  vim.cmd([[ autocmd TextChangedI <buffer> lua  require'guihua.ListViewCtrl':on_search() ]])

  TextViewCtrl._viewctlobject = self
  -- self:on_draw(self.display_data)
  -- self.m_delegate:set_pos(self.selected_line)
  log("textview ctrl created ")
end

-- load file uri if data is nil
-- need to call after floatwind is created or caller need pass the winnr
function TextViewCtrl:on_load(opts) -- location, width, pos_x, pos_y
  opts = opts or {}
  local uri = opts.uri
  if opts.uri == nil then
    log("invalid/nil uri ", opts)
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    log("load buf", uri, bufnr)
    vim.fn.bufload(bufnr)
  end
  --

  local range = opts.display_range or opts.range
  if range.start == nil then
    print("error invalid range")
    return
  end
  -- if range.start.line == nil then
  --   range.start.line = range["end"].line - 1
  --   opts.lnum = range["end"].line + 1
  -- end
  -- if range["end"].line == nil then
  --   range["end"].line = range.start.line + 1
  --   opts.lnum = range.start.line + 1
  -- end
  -- local lines = range['end'].line - range.start.line + 1
  trace(bufnr, range)
  local contents = api.nvim_buf_get_lines(bufnr, range.start.line, range['end'].line, false)
  local lines = #contents
  local syntax = opts.syntax
  if syntax == nil or #syntax < 1 then syntax = api.nvim_buf_get_option(bufnr, "ft") end

  -- TODO: for saving, need update file_info based on data loaded, e.g. if we only load 1 line, but display_height is 10
  self.file_info.lines = lines
  -- TODO should we create a float win based on opened buffer?
  trace(syntax, contents, self.file_info)
  return contents, syntax -- allow contents be handled by caller
end

-- call from event
-- get floatwin bufnr, get content, get file range and write to file range
function TextViewCtrl:on_save()
  log(TextViewCtrl._viewctlobject)
  local txtbufnr = TextViewCtrl._viewctlobject.bufnr

  local file_info = TextViewCtrl._viewctlobject.file_info
  local contents = api.nvim_buf_get_lines(txtbufnr, 0, file_info.lines, false)
  log(contents)

  -- local contents =
  --   api.nvim_buf_get_lines(txtbufnr, range.start.line, (range["end"].line or 1) + load_opts.display_height, false)
  --

  -- local contents =
  --   api.nvim_buf_get_lines(txtbufnr, range.start.line, (range["end"].line or 1) + load_opts.display_height, false)
  log("save file info", file_info)
  local bufnr = vim.uri_to_bufnr(file_info.uri)
  if not api.nvim_buf_is_loaded(bufnr) then vim.fn.bufload(bufnr) end
  local range = file_info.display_range
  if range == nil then log("incorrect file info, can not save") end

  log(bufnr, range, file_info.lines, contents)
  vim.api.nvim_buf_set_lines(bufnr, range.start.line, range.start.line + file_info.lines, true,
                             contents)
end

return TextViewCtrl
