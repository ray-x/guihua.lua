local M = {}
local ListView = require('guihua.listview')
local TextView = require('guihua.textview')
local util = require('guihua.util')
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local api = vim.api

local top_center = require('guihua.location').top_center

-- local path_sep = require('navigator.util').path_sep()
-- local path_cur = require('navigator.util').path_cur()
function M._preview_location(opts) -- location, width, pos_x, pos_y
  trace(opts)
  local uri = opts.uri
  if uri == nil then
    log('invalid/nil uri ')
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  --

  local display_range = opts.location.range
  local syntax = api.nvim_buf_get_option(bufnr, 'ft')
  if syntax == nil or #syntax < 1 then
    syntax = 'c'
  end
  local s = display_range.start.line
  local e = display_range['end'].line
  if e == s then
    if s < 2 then
      s = 0
    else
      s = s - 2
    end
    e = s + opts.rect.height
  end
  display_range.start.line = s
  display_range['end'].line = e

  -- trace(syntax, contents)
  local win_opts = {
    relative = opts.relative,
    location = opts.loc or 'offset_center',
    syntax = syntax,
    width = opts.width,
    height = display_range['end'].line - display_range.start.line + 1,
    preview_height = opts.height,
    pos_x = opts.offset_x,
    pos_y = opts.offset_y,
    range = opts.range,
    display_range = display_range,
    uri = uri,
    allow_edit = opts.enable_edit,
  }

  if opts.external then
    win_opts.external = true
    win_opts.relative = nil
  end

  -- win_opts.items = contents
  win_opts.hl_line = opts.lnum - display_range.start.line
  if win_opts.hl_line < 0 then
    win_opts.hl_line = 1
  end
  log(opts.lnum, opts.range.start.line, win_opts.hl_line)
  log(win_opts.uri, win_opts.syntax)
  local hl
  if vim.fn.hlID('TelescopePreviewBorder') > 0 then
    hl = 'TelescopePreviewBorder'
  end
  local text_view_opts = {
    loc = win_opts.location,
    rect = {
      height = win_opts.height, -- opts.preview_heigh or 12, -- TODO 12
      width = win_opts.width,
      pos_x = win_opts.pos_x,
      pos_y = win_opts.pos_y,
    },
    list_view_height = win_opts.height,
    -- data = display_data,
    relative = win_opts.relative,
    -- data = opts.items, -- either items or uri
    uri = win_opts.uri,
    syntax = win_opts.syntax,
    enter = win_opts.enter or false,
    range = win_opts.range,
    border = opts.border,
    display_range = win_opts.display_range,
    hl_line = win_opts.hl_line,
    allow_edit = win_opts.allow_edit,
    external = win_opts.external,
    border_hl = hl,
  }

  log(text_view_opts)
  local w = TextView:new(text_view_opts)
  return w
end

function M.preview_uri(opts) -- uri, width, line, col, offset_x, offset_y
  -- local handle = vim.loop.new_async(vim.schedule_wrap(function()
  local line_beg = (opts.lnum or 2) - 1
  if line_beg >= (opts.preview_lines_before or 1) then
    line_beg = line_beg - (opts.preview_lines_before or 1)
  elseif line_beg >= 2 then
    line_beg = line_beg - 2
  end
  local loc = { uri = opts.uri, range = { start = { line = line_beg } } }

  -- TODO: preview height
  loc.range['end'] = { line = opts.lnum + (opts.preview_height or opts.height) }
  opts.location = loc

  trace('uri', opts.uri, opts.lnum, opts.location.range.start.line, opts.location.range['end'].line)
  return M._preview_location(opts)
end

function M.new_list_view(opts)
  local items = opts.items
  local data = opts.data or opts.items or {}
  log('total items:', #items, 'data: ', #data)
  opts.height_ratio = opts.height_ratio or 0.8
  opts.width_ratio = opts.width_ratio or 0.8
  opts.preview_height_ratio = opts.preview_height_ratio or 0.4

  local wwidth = api.nvim_get_option('columns')
  local wheight = api.nvim_get_option('lines')

  local loc = 'top_center'

  local mwidth = opts.width_ratio
  local width = math.floor(wwidth * mwidth)
  width = math.min(120, width)

  local prompt = opts.prompt or false
  if opts.rawdata then
    data = items
  end

  local border = opts.border or 'shadow'

  if not data or vim.tbl_isempty(data) then
    return
  end

  -- replace
  -- TODO: 10 vimrc opt
  if #data > 10 and opts.prompt == nil then
    loc = 'top_center'
    prompt = true
  end

  local lheight = math.min(#data, math.floor(wheight * opts.height_ratio))

  local r, _ = top_center(lheight, width)

  local offset_y = r + lheight
  local pheight = math.min(wheight - lheight - 3, math.floor(wheight * opts.preview_height_ratio))
  -- style shadow took 1 lines
  if border ~= 'none' then
    if border == 'shadow' then
      offset_y = offset_y + 1
    else
      offset_y = offset_y + 2 -- single?
    end
  end
  -- if border is not set, this should be r+lheigh
  if prompt then
    offset_y = offset_y + 1 -- need to check this out
  end

  log(r, lheight, #data, wheight, opts.height_ratio, offset_y)
  local _ = require('guihua.util').fzy_idx
  local transparency = opts.transparency
  if transparency == 100 then
    transparency = nil
  end
  local ext = opts.external or false
  if ext then
    opts.relative = nil
  end
  local hl
  if vim.fn.hlID('TelescopePromptBorder') > 0 then
    hl = 'TelescopePromptBorder'
  end
  return ListView:new({
    loc = loc,
    prompt = prompt,
    relative = opts.relative,
    style = opts.style,
    api = opts.api,
    total = opts.total,

    width_ratio = opts.width_ratio,
    rect = { height = lheight, width = width, pos_x = 0, pos_y = 0 },
    -- preview_height = pheight,
    ft = opts.ft or 'guihua',
    -- data = display_data,
    data = data,
    border = border,
    external = ext,
    border_hl = hl,
    on_confirm = opts.on_confirm or function(item, split_opts)
      log(split_opts)
      split_opts = split_opts or {}
      if item.filename ~= nil then
        log('openfile ', item.filename, item.lnum, item.col)
        util.open_file_at(item.filename, item.lnum, item.col, split_opts.split)
      end
    end,
    transparency = transparency,
    on_move = opts.on_move or function(item)
      trace('on move', item)
      trace('on move', item.text or item, item.uri, item.filename)
      -- todo fix
      if item.uri == nil then
        item.uri = 'file:///' .. item.filename
      end
      return M.preview_uri({
        uri = item.uri,
        width_ratio = opts.width_ratio,
        preview_lines_before = opts.preview_lines_before or 3,
        width = width,
        preview_height = pheight,
        lnum = item.lnum,
        col = item.col,
        range = item.range,
        offset_x = 0,
        offset_y = offset_y,
        border = border,
        external = ext,
        enable_edit = opts.enable_preview_edit or false,
      })
    end,
  })
end

M.select = function(items, opts, on_choice)
  log('select called')
  local data = { { text = '  select ' .. opts.prompt .. ' <C-o> Apply <C-e> Exit' } }

  local width = #data[1].text + 4
  opts.format_item = opts.format_item or function(item)
    return item
  end
  for i, item in ipairs(items) do
    trace(i, item)
    table.insert(data, {
      text = ' [' .. tostring(i) .. '] ' .. opts.format_item(item),
      value = item,
      idx = i,
    })
    if item and item[2] and item[2].edit then
      local edit = item[2].edit
      local title = ''
      if edit.documentChanges or edit.changes then
        local changes = edit.documentChanges or edit.changes
        -- trace(action.edit.documentChanges)
        for _, change in pairs(changes or {}) do
          -- trace(change)
          if change.edits then
            title = title .. ' [newText:]'
            for _, ed in pairs(change.edits) do
              -- trace(ed)
              if ed.newText and ed.newText ~= '' then
                local newText = ed.newText:gsub('\n\t', ' ↳ ')
                newText = newText:gsub('\n', '↳')
                newText = newText:gsub('↳↳', '↳')
                title = title .. ' (' .. newText
                if ed.range then
                  title = title .. ' line: ' .. tostring(ed.range.start.line) .. ')'
                else
                  title = title .. ')'
                end
              end
            end
          elseif change.newText and change.newText ~= '' then
            local newText = change.newText:gsub('"\n\t"', ' ↳  ')
            newText = newText:gsub('\n', '↳')
            title = title .. ' (newText: ' .. newText
            if change.range then
              title = title .. ' line: ' .. tostring(change.range.start.line) .. ')'
            else
              title = title .. ')'
            end
          end
        end
      end
      if #title > 1 then
        data[#data].text = data[#data].text .. ' ' .. title
      end
    end

    if #data[#data].text + 6 > width then
      width = #data[#data].text + 6
    end
  end

  local divider = string.rep('─', width + 2)
  table.insert(data, 2, divider)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'x', true)
  log(data)
  local listview = M.new_list_view({
    items = data,
    border = 'single',
    width = width + 4,
    loc = 'top_center',
    relative = 'cursor',
    rawdata = true,
    data = data,
    on_confirm = function(item)
      log(item)
      return on_choice(item.value)
    end,
    on_move = function(pos)
      trace(pos)
      return pos
    end,
  })

  vim.api.nvim_buf_add_highlight(listview.buf, -1, 'Title', 0, 0, -1)
  ListViewCtrl:on_next()
  ListViewCtrl:on_next()

  return listview
end

M.input = require('guihua.input').input
M.input_callback = require('guihua.input').input_callback
return M
