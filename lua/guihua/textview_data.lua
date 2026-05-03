local api = vim.api
local log = require('guihua.log').info
local trace = require('guihua.log').trace

local M = {}

function M.resolve(opts)
  opts = vim.deepcopy(opts or {})
  if opts.uri == nil or opts.data ~= nil then
    return opts
  end

  trace(opts)
  local bufnr = vim.uri_to_bufnr(opts.uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    log('load buf', opts.uri, bufnr)
    vim.fn.bufload(bufnr)
  end

  local range = opts.display_range or opts.range
  if range == nil or range.start == nil then
    log('error: invalid/missing range')
    return opts
  end

  local start_line = range.start.line
  local end_line = range['end'].line
  if end_line == start_line then
    if start_line < 2 then
      start_line = 0
    else
      start_line = start_line - 2
    end
    end_line = math.max(end_line + 2, start_line + ((opts.rect and opts.rect.height) or 0))
  end

  range.start.line = start_line
  range['end'].line = end_line
  local contents = api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local line_count = #contents

  local syntax = opts.syntax
  if syntax == nil or #syntax < 1 then
    syntax = api.nvim_get_option_value('ft', { buf = bufnr })
  end

  if opts.status_line then
    table.insert(contents, opts.status_line)
  end

  opts.display_range = range
  opts.data = contents
  opts.syntax = syntax
  opts.file_info = {
    uri = opts.uri,
    allow_edit = opts.allow_edit,
    display_range = range,
    lines = line_count,
  }

  return opts
end

return M
