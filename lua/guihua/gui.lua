local M = {}
local ListView = require('guihua.listview')
local ListViewCtrl = require('guihua.listviewctrl')
local TextView = require('guihua.textview')
local util = require('guihua.util')
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local api = vim.api
local top_center = require('guihua.location').top_center

local ns_id = vim.api.nvim_create_namespace('guihua_gui')

-- Word-wrap `text` to `width` columns, honoring existing newlines.
local function word_wrap(text, width)
  local lines = {}
  for _, paragraph in ipairs(vim.split(text, '\n', { plain = true })) do
    if #paragraph == 0 then
      table.insert(lines, '')
    elseif #paragraph <= width then
      table.insert(lines, paragraph)
    else
      local current = ''
      for word in paragraph:gmatch('%S+') do
        if #current == 0 then
          current = word
        elseif #current + 1 + #word <= width then
          current = current .. ' ' .. word
        else
          table.insert(lines, current)
          current = word
        end
      end
      if #current > 0 then
        table.insert(lines, current)
      end
    end
  end
  return lines
end
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
  local syntax = api.nvim_get_option_value('ft', { buf = bufnr })
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
    preview_height = display_range['end'].line - display_range.start.line + 1, -- opts.preview_height or opts.height,
    pos_x = opts.offset_x,
    pos_y = opts.offset_y,
    range = opts.range,
    display_range = display_range,
    uri = uri,
    allow_edit = opts.enable_edit,
  }
  trace('height', win_opts.height, win_opts.preview_height, opts.height, win_opts.height)

  if opts.external then
    win_opts.external = true
    win_opts.relative = nil
  end

  -- win_opts.items = contents
  local target_lnum = opts.lnum
    or ((opts.range and opts.range.start and opts.range.start.line) or display_range.start.line)
  win_opts.hl_line = target_lnum - display_range.start.line
  if win_opts.hl_line < 0 then
    win_opts.hl_line = 1
  end
  local range_start = opts.range and opts.range.start and opts.range.start.line
  log(target_lnum, range_start, win_opts.hl_line)
  log(win_opts.uri, win_opts.syntax)
  local text_view_opts = {
    loc = win_opts.location,
    rect = {
      height = win_opts.preview_height,
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
    status_line = opts.status_line,
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
  opts.height = loc.range['end'].line - loc.range.start.line + 1
  opts.location = loc

  trace('uri', opts.uri, opts.lnum, opts.location.range.start.line, opts.location.range['end'].line)
  return M._preview_location(opts)
end

function M.new_list_view(opts)
  local items = opts.items
  local data = opts.data or opts.items or {}
  log('total items:', #(items or {}), 'data: ', #data)
  opts.height_ratio = opts.height_ratio or 0.9
  opts.width_ratio = opts.width_ratio or 0.9
  opts.preview_height_ratio = opts.preview_height_ratio or 0.4

  local wwidth = api.nvim_get_option_value('columns', {})
  local wheight = api.nvim_get_option_value('lines', {})

  local loc = 'top_center'

  local mwidth = opts.width_ratio
  local width = opts.width or math.floor(wwidth * mwidth)

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

  return ListView:new({
    loc = loc,
    prompt = prompt,
    prompt_mode = opts.prompt_mode,
    enter = opts.enter,
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
    title = opts.title,
    title_pos = opts.title_pos,
    title_style = opts.title_style,
    border_hl = opts.border_hl,
    bg_hl = opts.bg_hl,
    sel_line_hl = opts.sel_line_hl,
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
      trace(item, item.status_line, pheight)
      -- todo fix
      if item.uri == nil then
        item.uri = 'file:///' .. item.filename
      end
      return M.preview_uri({
        uri = item.uri,
        status_line = item.status_line,
        width_ratio = opts.width_ratio,
        preview_lines_before = opts.preview_lines_before or 3,
        width = width,
        preview_height = pheight + ((item.status_line and #item.status_line > 0 and 1) or 0),
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
  vim.validate('items', items, 'table')
  vim.validate('opts', opts, 'table')
  vim.validate('on_choice', on_choice, 'function')
  local prompt = opts.prompt or 'Select'
  local hint = '<C-o> Apply  <C-e> Exit'
  -- When the prompt is long or multi-line, render it inside the window instead
  -- of the title bar (which Neovim truncates to the window width).
  local PROMPT_TITLE_MAX = 60
  local prompt_in_content = #prompt > PROMPT_TITLE_MAX or prompt:find('\n') ~= nil
  local win_title = prompt_in_content and hint or (prompt .. '  ' .. hint)

  local data = {}
  if vim.fn.has('nvim-0.9') == 0 then
    win_title = ' ' .. win_title
    data = { { text = win_title } }
  end

  local width = #win_title + 8
  local max_width = math.floor(api.nvim_get_option_value('columns', {}) * (opts.width or 0.9))
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
            for _, ed in pairs(change.edits) do
              -- trace(ed)
              if ed.newText and ed.newText ~= '' then
                local newText = ed.newText:gsub('\n\t', ' â³ ')
                newText = newText:gsub('\n', 'â³')
                newText = newText:gsub('â³â³', 'â³')
                if #newText > 1 then
                  title = title .. ' (add ' .. newText
                  if ed.range then
                    title = title .. ' line: ' .. tostring(ed.range.start.line) .. ')'
                  else
                    title = title .. ')'
                  end
                end
              end
            end
          elseif change.newText and change.newText ~= '' then
            local newText = change.newText:gsub('"\n\t"', ' â³  ')
            newText = newText:gsub('\n', 'â³')
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

  -- Prepend wrapped prompt lines when the prompt is too long for the title bar.
  local header_count = 0
  if prompt_in_content then
    local inner_width = math.max(math.min(width, max_width) - 8, 30)
    local wrapped = word_wrap(prompt, inner_width)
    local header_lines = {}
    for _, l in ipairs(wrapped) do
      local entry = { text = '  ' .. l, header = true }
      table.insert(header_lines, entry)
      if #entry.text + 6 > width then
        width = #entry.text + 6
      end
    end
    -- Separator between prompt and items
    table.insert(header_lines, { text = '  ' .. string.rep('─', inner_width), header = true })
    header_count = #header_lines
    -- Rebuild data: headers first, then items
    local new_data = {}
    for _, h in ipairs(header_lines) do
      table.insert(new_data, h)
    end
    for _, d in ipairs(data) do
      table.insert(new_data, d)
    end
    data = new_data
  end

  if not win_title or #win_title <= 1 then
    local divider = string.rep('─', width + 4)
    table.insert(data, header_count + 2, divider)
  end
  -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'x', true)
  width = math.min(width + 4, max_width)
  local listview = M.new_list_view({
    items = data,
    title = win_title,
    border = 'single',
    width = width,
    loc = 'top_center',
    relative = 'cursor',
    rawdata = true,
    data = data,
    on_confirm = function(item, idx)
      if item.header then
        return -- non-selectable prompt header lines
      end
      return on_choice(item.value, item.idx or idx)
    end,
    on_move = function(pos)
      trace(pos)
      return pos
    end,
  })

  if listview == nil then
    return
  end
  -- Advance cursor past any header lines and land on the first real item.
  for _ = 1, 2 + header_count do
    ListViewCtrl:on_next()
  end

  return listview
end

-- Confirm dialog for yes/no questions.
--
-- opts:
--   prompt      (string)  The question to display. Supports plain text and
--                         markdown (set opts.markdown = true).
--   title       (string)  Window border title. Defaults to "Confirm".
--   default     (bool)    Pre-selected button. Defaults to true (Yes).
--   yes_label   (string)  Label for the affirmative button. Defaults to "Yes".
--   no_label    (string)  Label for the negative button. Defaults to "No".
--   markdown    (bool)    Render the prompt with markdown TreeSitter highlights.
--   width       (number)  Explicit window width (columns).
--
-- on_confirm(choice): called with true for Yes, false for No / cancel.
M.confirm = function(opts, on_confirm)
  vim.validate('opts', opts, 'table')
  vim.validate('on_confirm', on_confirm, 'function')

  local prompt = opts.prompt or 'Are you sure?'
  local title = opts.title or 'Confirm'
  local yes_label = opts.yes_label or 'Yes'
  local no_label = opts.no_label or 'No'
  local is_markdown = opts.markdown or false
  local selected_yes = opts.default ~= false -- default: Yes pre-selected

  local columns = api.nvim_get_option_value('columns', {})
  local max_width = opts.width or math.floor(columns * 0.6)
  max_width = math.min(math.max(max_width, 44), 80)

  local inner_width = max_width - 4 -- 2-char padding on each side
  local wrapped = word_wrap(prompt, inner_width)

  -- Button labels with shortcut hints
  local yes_btn = string.format('[y] %s', yes_label)
  local no_btn = string.format('[n] %s', no_label)
  local gap = math.max(inner_width - #yes_btn - #no_btn, 4)
  local btn_line = '  ' .. yes_btn .. string.rep(' ', gap) .. no_btn

  local separator = string.rep('─', inner_width)

  -- Assemble buffer lines
  local content_lines = { '' } -- top padding
  for _, l in ipairs(wrapped) do
    table.insert(content_lines, '  ' .. l)
  end
  table.insert(content_lines, '')
  table.insert(content_lines, '  ' .. separator)
  table.insert(content_lines, '')
  local btn_row = #content_lines - 1 -- 0-indexed row index of the button line
  table.insert(content_lines, btn_line)
  table.insert(content_lines, '') -- bottom padding

  local floating_buf_fn = require('guihua.floating').floating_buf
  local location_mod = require('guihua.location')

  local buf, win, closer = floating_buf_fn({
    win_width = max_width,
    win_height = #content_lines,
    title = title,
    enter = true,
    border = 'single',
    loc = location_mod.center,
  })

  -- Populate buffer
  api.nvim_set_option_value('modifiable', true, { buf = buf })
  api.nvim_set_option_value('readonly', false, { buf = buf })
  api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)

  -- Apply TreeSitter markdown highlights over the prompt region when requested
  if is_markdown then
    local ok = pcall(vim.treesitter.start, buf, 'markdown')
    if not ok then
      pcall(util.highlighter, buf, 'markdown', #wrapped + 2)
    end
  end

  -- Extmark columns for each button (btn_line layout: '  <yes_btn><gap><no_btn>')
  local yes_col_start = 2
  local yes_col_end = yes_col_start + #yes_btn
  local no_col_start = yes_col_end + gap
  local no_col_end = no_col_start + #no_btn

  local ns = api.nvim_create_namespace('guihua_confirm')

  local function highlight_buttons()
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local sel_hl = 'GuihuaListSelHl'
    local dim_hl = 'Comment'
    api.nvim_buf_set_extmark(buf, ns, btn_row, yes_col_start, {
      end_col = yes_col_end,
      hl_group = selected_yes and sel_hl or dim_hl,
    })
    api.nvim_buf_set_extmark(buf, ns, btn_row, no_col_start, {
      end_col = no_col_end,
      hl_group = selected_yes and dim_hl or sel_hl,
    })
    -- Place cursor on the active button so the user has visual feedback
    local cursor_col = selected_yes and yes_col_start or no_col_start
    pcall(api.nvim_win_set_cursor, win, { btn_row + 1, cursor_col })
  end

  highlight_buttons()

  local function do_confirm(choice)
    pcall(closer)
    on_confirm(choice)
  end

  local map_opts = { noremap = true, silent = true, buffer = buf }
  -- Direct yes / no shortcuts
  vim.keymap.set({ 'n', 'i' }, 'y', function()
    do_confirm(true)
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, 'Y', function()
    do_confirm(true)
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, 'n', function()
    do_confirm(false)
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, 'N', function()
    do_confirm(false)
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, 'q', function()
    do_confirm(false)
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, '<ESC>', function()
    do_confirm(false)
  end, map_opts)
  -- Enter confirms the currently highlighted button
  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    do_confirm(selected_yes)
  end, map_opts)
  -- Toggle selection between Yes and No
  vim.keymap.set({ 'n', 'i' }, '<Tab>', function()
    selected_yes = not selected_yes
    highlight_buttons()
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, '<S-Tab>', function()
    selected_yes = not selected_yes
    highlight_buttons()
  end, map_opts)
  -- Directional navigation: Left/h â Yes,  Right/l â No
  vim.keymap.set({ 'n', 'i' }, '<Left>', function()
    selected_yes = true
    highlight_buttons()
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, 'h', function()
    selected_yes = true
    highlight_buttons()
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, '<Right>', function()
    selected_yes = false
    highlight_buttons()
  end, map_opts)
  vim.keymap.set({ 'n', 'i' }, 'l', function()
    selected_yes = false
    highlight_buttons()
  end, map_opts)

  -- Close without confirming when the user leaves the buffer
  api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = function()
      pcall(closer)
    end,
  })

  return win, buf
end

M.input = require('guihua.input').input
M.input_callback = require('guihua.input').input_callback

--[[

M.select({ 'tabs', 'spaces', 'enter' }, {
  prompt = 'Select tabs or spaces:',
  format_item = function(item)
    return "I'd like to choose " .. item
  end,
}, function(choice)
  if choice == 'spaces' then
    print('space')
  else
    print('tab')
  end
end)

]]
return M
