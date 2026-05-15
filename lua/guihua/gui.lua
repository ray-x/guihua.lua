local M = {}
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local api = vim.api

local ns_id = vim.api.nvim_create_namespace('guihua_gui')

local function get_listview()
  return require('guihua.listview')
end

local function get_textview()
  return require('guihua.textview')
end

local function get_diffview()
  return require('guihua.diffview')
end

local function get_util()
  return require('guihua.util')
end

local function top_center(...)
  return require('guihua.location').top_center(...)
end

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

local function first_selectable_index(data)
  for i, item in ipairs(data) do
    if type(item) == 'table' and item.header ~= true and (item.value ~= nil or item.idx ~= nil) then
      return i
    end
  end
  return 1
end

local function preselect_first_item(listview)
  local ctrl = listview:get_ctrl()
  local state = ctrl and ctrl.state or nil
  local data = state and state.data or (ctrl and ctrl.data) or nil
  if ctrl == nil or data == nil or #data == 0 then
    return
  end

  local selected_line = first_selectable_index(data)
  if state ~= nil then
    local result = state:set_selection(selected_line)
    ctrl:sync_state()
    if result.redraw then
      listview:on_draw(state.display_data)
    end
    listview:set_pos(result.cursor_line)
    return
  end

  ctrl.selected_line = selected_line
  listview:set_pos(selected_line)
end
-- local path_sep = require('navigator.util').path_sep()
-- local path_cur = require('navigator.util').path_cur()
local function build_preview_location_opts(opts)
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
  local target_lnum = opts.lnum or ((opts.range and opts.range.start and opts.range.start.line) or display_range.start.line)
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

  return text_view_opts
end

function M._preview_location(opts) -- location, width, pos_x, pos_y
  local text_view_opts = build_preview_location_opts(opts)
  log(text_view_opts)
  return get_textview().open(text_view_opts)
end

function M.preview_uri_spec(opts)
  local line_beg = (opts.lnum or 2) - 1
  if line_beg >= (opts.preview_lines_before or 1) then
    line_beg = line_beg - (opts.preview_lines_before or 1)
  elseif line_beg >= 2 then
    line_beg = line_beg - 2
  end
  local loc = { uri = opts.uri, range = { start = { line = line_beg } } }

  loc.range['end'] = { line = opts.lnum + (opts.preview_height or opts.height) }
  opts.height = loc.range['end'].line - loc.range.start.line + 1
  opts.location = loc

  trace('uri', opts.uri, opts.lnum, opts.location.range.start.line, opts.location.range['end'].line)
  return get_textview().preview_spec(build_preview_location_opts(opts))
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
  local _ = get_util().fzy_idx
  local transparency = opts.transparency
  if transparency == 100 then
    transparency = nil
  end
  local ext = opts.external or false
  if ext then
    opts.relative = nil
  end

  return get_listview():new({
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
        vim.schedule(function()
          get_util().open_file_at(item.filename, item.lnum, item.col, split_opts.split)
        end)
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
      return M.preview_uri_spec({
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
                local newText = ed.newText:gsub('\n\t', ' ↳ ')
                newText = newText:gsub('\n', '↳')
                newText = newText:gsub('↳↳', '↳')
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
  -- Determine whether this select should behave as a prompt (insert/fuzzy)
  local should_prompt = false
  if opts.prompt == true then
    should_prompt = true
  elseif opts.prompt == nil and #items > 10 then
    should_prompt = true
  end
  -- By default, focus (enter) the popup so the cursor is in the popup buffer.
  -- If opts.enter is explicitly provided, respect it; otherwise default to true.
  local enter_mode = (opts.enter ~= nil) and opts.enter or true

  local listview = M.new_list_view({
    items = data,
    title = win_title,
    border = 'single',
    width = width,
    loc = 'top_center',
    relative = 'cursor',
    rawdata = true,
    data = data,
    prompt = should_prompt,
    enter = enter_mode,
    persist = true,
    ft = opts.ft or 'markdown',
    disable_strikethrough = true,
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
  preselect_first_item(listview)

  return listview
end

-- format_markdown preserves code/diff fences verbatim and word-wraps prose.
local function format_markdown(text, width)
  local result = {}
  local in_fence = false
  local fence_pat = '^%s*```'
  for _, raw in ipairs(vim.split(text, '\n', { plain = true })) do
    if raw:match(fence_pat) then
      in_fence = not in_fence
      table.insert(result, raw)
    elseif in_fence then
      table.insert(result, raw) -- code / diff content: preserve as-is
    elseif #raw == 0 or #raw <= width then
      table.insert(result, '')
    else
      local current = ''
      for word in raw:gmatch('%S+') do
        if #current == 0 then
          current = word
        elseif #current + 1 + #word <= width then
          current = current .. ' ' .. word
        else
          table.insert(result, current)
          current = word
        end
      end
      if #current > 0 then
        table.insert(result, current)
      end
    end
  end
  return result
end

-- Confirm dialog for yes/no questions.
--
-- Renders the question in a scrollable content window with full markdown /
-- diff syntax highlighting (TreeSitter with injected languages), and pins a
-- dedicated button bar beneath it so the Yes / No choice is always visible.
--
-- opts:
--   prompt      (string)  Question text (plain text or markdown).
--   title       (string)  Content-window border title.  Default: "Confirm".
--   default     (bool)    Pre-selected button.  Default: true (Yes).
--   yes_label   (string)  Affirmative label.  Default: "Yes".
--   no_label    (string)  Negative label.     Default: "No".
--   markdown    (bool)    Enable markdown + injected-language TS highlights.
--   border      (string)  nvim_open_win border style.  Default: "rounded".
--   width       (number)  Explicit window width override (columns).
--
-- on_confirm(choice): called with true for Yes, false for No / dismiss.
--
-- Navigation (button window):
--   y/Y          → confirm Yes immediately
--   n/N/q/Esc    → confirm No / dismiss
--   Enter        → confirm highlighted button
--   Tab/S-Tab    → toggle button
--   Left/h       → select Yes     Right/l → select No
--   j/Down       → scroll content down 3 lines
--   k/Up         → scroll content up   3 lines
--   C-d / C-u    → scroll half page
--   C-f / C-b    → scroll full page
--   e            → enter content window (free scroll; q / Enter returns focus)
M.confirm = function(opts, on_confirm)
  vim.validate('opts', opts, 'table')
  vim.validate('on_confirm', on_confirm, 'function')

  local prompt = opts.prompt or 'Are you sure?'
  local title = opts.title or 'Confirm'
  local yes_label = opts.yes_label or 'Yes'
  local no_label = opts.no_label or 'No'
  local is_markdown = opts.markdown or false
  local selected_yes = opts.default ~= false
  local border = opts.border or 'rounded'

  -- ── Dimensions ──────────────────────────────────────────────────────────
  local columns = api.nvim_get_option_value('columns', {})
  local screen_h = api.nvim_get_option_value('lines', {})
  local max_win_w = opts.width or math.floor(columns * 0.88)
  max_win_w = math.min(math.max(max_win_w, 44), math.floor(columns * 0.95))
  local prose_width = max_win_w - 6 -- leave 2-char padding + border

  -- ── Format content ──────────────────────────────────────────────────────
  local fmt_lines = is_markdown and format_markdown(prompt, prose_width) or word_wrap(prompt, prose_width)

  -- Compute actual window width from the longest formatted line
  local max_line_w = 0
  for _, l in ipairs(fmt_lines) do
    if #l > max_line_w then
      max_line_w = #l
    end
  end
  local win_w = math.min(math.max(max_line_w + 6, 44), max_win_w)

  -- Build content buffer lines (with 1-line padding top/bottom)
  local cbuf_lines = { '' }
  for _, l in ipairs(fmt_lines) do
    table.insert(cbuf_lines, '  ' .. l)
  end
  table.insert(cbuf_lines, '')

  -- ── Button bar ──────────────────────────────────────────────────────────
  local BTN_H = 3
  local yes_btn = string.format('[y] %s', yes_label)
  local no_btn = string.format('[n] %s', no_label)
  local inner_btn_w = win_w - 4
  local btn_gap = math.max(inner_btn_w - #yes_btn - #no_btn, 4)
  local btn_line = '  ' .. yes_btn .. string.rep(' ', btn_gap) .. no_btn
  local bbuf_lines = { '', btn_line, '' }
  local BTN_ROW = 1 -- 0-indexed row of btn_line in btn_buf

  -- ── Window positions ────────────────────────────────────────────────────
  -- content_h + 2 (borders) + BTN_H + 2 (borders) stacked together
  local max_content_h = screen_h - BTN_H - 6
  local content_h = math.min(#cbuf_lines, math.max(4, max_content_h))
  local total_h = content_h + 2 + BTN_H + 2
  local start_row = math.max(0, math.ceil((screen_h - total_h) / 2) - 1)
  local start_col = math.max(0, math.ceil((columns - win_w) / 2))
  local btn_row_abs = start_row + content_h + 2 -- below content bottom border

  -- ── Content window ──────────────────────────────────────────────────────
  local content_buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = content_buf })
  api.nvim_set_option_value('buflisted', false, { buf = content_buf })
  api.nvim_buf_set_lines(content_buf, 0, -1, false, cbuf_lines)
  api.nvim_set_option_value('modifiable', false, { buf = content_buf })
  api.nvim_set_option_value('readonly', true, { buf = content_buf })

  local cwin_opts = {
    relative = 'editor',
    style = 'minimal',
    row = start_row,
    col = start_col,
    width = win_w,
    height = content_h,
    border = border,
    zindex = 50,
  }
  if vim.fn.has('nvim-0.9') == 1 then
    local t = get_util().title_options(title)
    if t then
      cwin_opts.title = t
      cwin_opts.title_pos = 'center'
    end
  end
  local content_win = api.nvim_open_win(content_buf, false, cwin_opts)
  api.nvim_set_option_value('winhl', 'Normal:NormalFloat,NormalNC:Normal', { win = content_win })
  api.nvim_set_option_value('wrap', true, { win = content_win })
  api.nvim_set_option_value('linebreak', true, { win = content_win })
  api.nvim_set_option_value('number', false, { win = content_win })
  api.nvim_set_option_value('cursorline', false, { win = content_win })
  api.nvim_set_option_value('signcolumn', 'no', { win = content_win })

  -- TreeSitter highlighting for markdown (enables injected-language grammars
  -- so ```diff, ```lua, ```python blocks are highlighted in their own syntax)
  if is_markdown then
    local ok = pcall(vim.treesitter.start, content_buf, 'markdown')
    if not ok then
      -- Fall back to Vim's built-in markdown syntax
      api.nvim_set_option_value('filetype', 'markdown', { buf = content_buf })
    end
  end

  -- ── Button window ────────────────────────────────────────────────────────
  local btn_buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = btn_buf })
  api.nvim_set_option_value('buflisted', false, { buf = btn_buf })
  api.nvim_set_option_value('filetype', 'guihua', { buf = btn_buf })
  api.nvim_buf_set_lines(btn_buf, 0, -1, false, bbuf_lines)

  local bwin_opts = {
    relative = 'editor',
    style = 'minimal',
    row = btn_row_abs,
    col = start_col,
    width = win_w,
    height = BTN_H,
    border = 'single',
    zindex = 50,
  }
  local btn_win = api.nvim_open_win(btn_buf, true, bwin_opts) -- enter=true
  api.nvim_set_option_value('winhl', 'Normal:NormalFloat,NormalNC:Normal', { win = btn_win })

  -- ── Button highlight ─────────────────────────────────────────────────────
  local ns = api.nvim_create_namespace('guihua_confirm')
  local yes_col_start = 2
  local yes_col_end = yes_col_start + #yes_btn
  local no_col_start = yes_col_end + btn_gap
  local no_col_end = no_col_start + #no_btn

  local function highlight_buttons()
    api.nvim_buf_clear_namespace(btn_buf, ns, 0, -1)
    local sel_hl, dim_hl = 'GuihuaListSelHl', 'Comment'
    api.nvim_buf_set_extmark(btn_buf, ns, BTN_ROW, yes_col_start, {
      end_col = yes_col_end,
      hl_group = selected_yes and sel_hl or dim_hl,
    })
    api.nvim_buf_set_extmark(btn_buf, ns, BTN_ROW, no_col_start, {
      end_col = no_col_end,
      hl_group = selected_yes and dim_hl or sel_hl,
    })
    local cursor_col = selected_yes and yes_col_start or no_col_start
    pcall(api.nvim_win_set_cursor, btn_win, { BTN_ROW + 1, cursor_col })
  end

  highlight_buttons()

  -- ── Close helpers ────────────────────────────────────────────────────────
  local closed = false
  local finalized = false
  local function close_all()
    if closed then
      return
    end
    closed = true
    pcall(api.nvim_win_close, content_win, true)
    pcall(api.nvim_win_close, btn_win, true)
  end

  local function finalize(choice)
    if finalized then
      return
    end
    finalized = true
    close_all()
    on_confirm(choice)
  end

  -- Cascade close: closing one window closes the other
  api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(content_win),
    once = true,
    callback = function()
      finalize(false)
    end,
  })
  api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(btn_win),
    once = true,
    callback = function()
      finalize(false)
    end,
  })

  -- ── Scroll helper (called from btn_win keymaps) ──────────────────────────
  local function scroll_content(delta)
    if not api.nvim_win_is_valid(content_win) then
      return
    end
    api.nvim_win_call(content_win, function()
      local dir = delta > 0 and 'j' or 'k'
      vim.cmd('normal! ' .. math.abs(delta) .. dir)
    end)
  end

  -- ── Keymaps: button window ───────────────────────────────────────────────
  local bmap = { noremap = true, silent = true, buffer = btn_buf }

  vim.keymap.set({ 'n', 'i' }, 'y', function()
    finalize(true)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, 'Y', function()
    finalize(true)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, 'n', function()
    finalize(false)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, 'N', function()
    finalize(false)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, 'q', function()
    finalize(false)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<ESC><ESC>', function()
    finalize(false)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    finalize(selected_yes)
  end, bmap)

  vim.keymap.set({ 'n', 'i' }, '<Tab>', function()
    selected_yes = not selected_yes
    highlight_buttons()
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<S-Tab>', function()
    selected_yes = not selected_yes
    highlight_buttons()
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<Left>', function()
    selected_yes = true
    highlight_buttons()
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, 'h', function()
    selected_yes = true
    highlight_buttons()
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<Right>', function()
    selected_yes = false
    highlight_buttons()
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, 'l', function()
    selected_yes = false
    highlight_buttons()
  end, bmap)

  -- Scroll content from the button window
  vim.keymap.set({ 'n', 'i' }, 'j', function()
    scroll_content(3)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<Down>', function()
    scroll_content(3)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, 'k', function()
    scroll_content(-3)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<Up>', function()
    scroll_content(-3)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<C-d>', function()
    scroll_content(math.ceil(content_h / 2))
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<C-u>', function()
    scroll_content(-math.ceil(content_h / 2))
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<C-f>', function()
    scroll_content(content_h)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<PageDown>', function()
    scroll_content(content_h)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<C-b>', function()
    scroll_content(-content_h)
  end, bmap)
  vim.keymap.set({ 'n', 'i' }, '<PageUp>', function()
    scroll_content(-content_h)
  end, bmap)

  -- Enter content window for free scroll; press q / Enter to return
  vim.keymap.set({ 'n', 'i' }, 'e', function()
    if api.nvim_win_is_valid(content_win) then
      api.nvim_set_current_win(content_win)
    end
  end, bmap)

  -- ── Keymaps: content window ──────────────────────────────────────────────
  local cmap = { noremap = true, silent = true, buffer = content_buf }
  local function return_to_btn()
    if api.nvim_win_is_valid(btn_win) then
      api.nvim_set_current_win(btn_win)
    end
  end
  vim.keymap.set('n', '<CR>', return_to_btn, cmap)
  vim.keymap.set('n', 'q', return_to_btn, cmap)
  vim.keymap.set('n', 'ZQ', function()
    finalize(false)
  end, cmap)
  vim.keymap.set('n', '<ESC><ESC>', function()
    finalize(false)
  end, cmap)

  return content_win, btn_win
end

M.input = function(...)
  return require('guihua.input').input(...)
end

M.input_callback = function(...)
  return require('guihua.input').input_callback(...)
end

-- Open a tabbed catalog browser popup.
--
-- opts:
--   title                (string)  Popup title.
--   tabs                 (table)   Catalog tabs and items.
--   tab_order / order    (table)   Explicit tab order for keyed tabs.
--   loc                  (string|function) List location. Default: "top_center".
--   rect                 (table)   Explicit list rect { width, height }.
--   width / height       (number)  List size shortcut when rect is omitted.
--                                  Default height auto-fits item count.
--   list_height_ratio    (number)  Max list height ratio. Default: 0.45.
--   width_ratio          (number)  Max list width ratio. Default: 0.9.
--   root                 (string)  Project root used for relative display paths.
--   item_icon            (string)  Icon prefix for non-current items. Default: "".
--   current_item_icon    (string)  Icon prefix for current item. Default: "".
--   close_hint           (string)  Optional custom close hint text in the title.
--   border               (string)  Border style. Default: "rounded".
--   ft                   (string)  List buffer filetype. Default: "guihua".
--   preview_height_ratio (number)  Preview size ratio. Default: 0.4.
--   session              (table)   Optional session to reuse.
--   on_confirm           (function) Callback(item, active_tab) on Enter.
--
-- Keymaps:
--   <Left>/<Right> cycle tabs, tab hotkeys jump directly, Enter confirms.
M.catalog = function(...)
  return require('guihua.catalog').open(...)
end

function M.diffview(opts)
  -- opts:
  --   title            (string)  Border title.
  --   description      (string)  Rendered at the top of the diff popup.
  --   diff             (string)  Unified diff text (git diff / diff -u).
  --   syntax           (string)  Optional syntax for the diff body.
  --   close_keymap     (string|false) Buffer-local close mapping, default <C-c>.
  --   autoclose        (string|table|boolean) Neovim event name(s): string, list,
  --                               or { events = {...}, timeout = ms }.
  --                               Use { focus_moved = true } for WinLeave/BufLeave.
  return get_diffview().open(opts)
end

M.diff = M.diffview

-- test, do not remove
-- M.select({ '[1] aaa', '* bbb', '1. ccc', '*ddd*', '~eee~', '~~fff~~' }, {}, print)

return M
