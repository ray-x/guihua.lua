local utils = require('guihua.util')
local log = require('guihua.log').info
local api = vim.api
local win_title_width = 40

local input_defaults = {
  opts = {},
  title = nil,
  on_confirm = function(_)
    log('default on confirm')
  end,
  on_change = function(_, _, _)
    log('default on change')
  end,
  on_cancel = function(_) end,
}
local input_contexts = {}
local input_highlight_ns = api.nvim_create_namespace('guihua_input_user_highlight')

local function strwidth(text)
  return vim.fn.strdisplaywidth(text or '')
end

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(value, max_value))
end

local function split_lines(text)
  return vim.split(text or '', '\n', { plain = true })
end

local function normalize_input_text(text)
  text = text or ''
  text = text:gsub('\r\n', '\n')
  text = text:gsub('\r', '\n')
  return text
end

local function wrap_text(text, width)
  local lines = {}
  width = math.max(1, width)
  for _, paragraph in ipairs(split_lines(text)) do
    if paragraph == '' then
      table.insert(lines, '')
    elseif strwidth(paragraph) <= width then
      table.insert(lines, paragraph)
    else
      local current = ''
      for word in paragraph:gmatch('%S+') do
        if current == '' then
          current = word
        elseif strwidth(current .. ' ' .. word) <= width then
          current = current .. ' ' .. word
        else
          table.insert(lines, current)
          current = word
        end
      end
      if current ~= '' then
        table.insert(lines, current)
      end
    end
  end
  return lines
end

local function line_text(ctx)
  if ctx == nil or ctx.buf == nil or not api.nvim_buf_is_valid(ctx.buf) then
    return (ctx and ctx.prompt) or ''
  end
  return api.nvim_buf_get_lines(ctx.buf, 0, 1, false)[1] or ''
end

local function buffer_lines(ctx)
  if ctx == nil or ctx.buf == nil or not api.nvim_buf_is_valid(ctx.buf) then
    return {}
  end
  return api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
end

local function display_metrics(ctx)
  local lines = buffer_lines(ctx)
  if vim.tbl_isempty(lines) then
    return 0, 1
  end

  local max_line_width = 0
  for _, line in ipairs(lines) do
    max_line_width = math.max(max_line_width, strwidth(line))
  end
  return max_line_width, #lines
end

local function input_max_width(ctx)
  local columns = api.nvim_get_option_value('columns', {})
  local screen_max = math.max(win_title_width, columns - 4)
  local configured = ctx.opts.max_width or math.floor(columns * 0.9)
  return clamp(configured, win_title_width, screen_max)
end

local function should_use_content_box(ctx)
  local prompt = ctx.prompt_text or ''
  local title = ctx.explicit_title or ''
  if prompt:find('\n', 1, true) or title:find('\n', 1, true) then
    return true
  end
  return strwidth(prompt) > input_max_width(ctx) or strwidth(title) > input_max_width(ctx)
end

local function build_content_lines(ctx, width)
  local lines = {}
  local inner_width = math.max(1, width - 2)
  if ctx.prompt_text and ctx.prompt_text ~= '' then
    vim.list_extend(lines, wrap_text(ctx.prompt_text, inner_width))
  end
  return lines
end

local function build_separator_line(width)
  return string.rep('─', math.max(1, width - 2))
end

local function derive_window_title(ctx)
  local explicit = ctx.explicit_title or ''
  if explicit ~= '' then
    return explicit
  end
  local prompt = ctx.prompt_text or ''
  local first_line = split_lines(prompt)[1] or ''
  if first_line == '' then
    return nil
  end
  return vim.fn.strcharpart(first_line, 0, win_title_width)
end

local function input_min_width(ctx)
  local preferred = ctx.opts.width or win_title_width
  local seed = (ctx.prompt or '') .. (ctx.placeholder or '')
  return math.max(preferred, math.min(strwidth(seed) + 2, input_max_width(ctx)))
end

local function resize_input(ctx)
  if ctx == nil or ctx.win == nil or not api.nvim_win_is_valid(ctx.win) then
    return
  end

  local max_width = input_max_width(ctx)
  local max_line_width, line_count = display_metrics(ctx)
  local width = math.min(max_width, math.max(input_min_width(ctx), max_line_width + 1, ctx.min_width or 0))
  local wrapped_height = 0
  for _, line in ipairs(buffer_lines(ctx)) do
    wrapped_height = wrapped_height + math.max(1, math.ceil(strwidth(line) / math.max(width, 1)))
  end
  wrapped_height = math.max(wrapped_height, line_count, 1)

  local lines = api.nvim_get_option_value('lines', {})
  local screen_max_height = math.max(1, lines - 6)
  local configured_max_height = ctx.opts.max_height or screen_max_height
  local height = math.min(wrapped_height, clamp(configured_max_height, 1, screen_max_height))

  local cfg = api.nvim_win_get_config(ctx.win)
  cfg.width = width
  cfg.height = height
  if ctx.dynamic_row and not ctx.composite then
    cfg.row = -(height + 2)
  end
  api.nvim_win_set_config(ctx.win, cfg)

  if ctx.composite and ctx.content_win ~= nil and api.nvim_win_is_valid(ctx.content_win) then
    local content_cfg = api.nvim_win_get_config(ctx.content_win)
    content_cfg.width = width
    api.nvim_win_set_config(ctx.content_win, content_cfg)
  end
end

local function current_context(bufnr)
  return input_contexts[bufnr or api.nvim_get_current_buf()]
end

local setup = function(opts)
  if opts then
    input_defaults = vim.tbl_deep_extend('force', input_defaults, opts)
  end
end

local function current_text(ctx)
  if ctx == nil then
    return ''
  end
  local lines = buffer_lines(ctx)
  if vim.tbl_isempty(lines) then
    return ''
  end
  local start_line = ctx.input_start or 1
  local prompt = ctx.prompt or ''
  local sliced = {}
  for i = start_line, #lines do
    sliced[#sliced + 1] = lines[i]
  end
  if #sliced == 0 then
    return ''
  end
  if prompt ~= '' and vim.startswith(sliced[1], prompt) then
    sliced[1] = sliced[1]:sub(#prompt + 1, -1)
  end
  return normalize_input_text(table.concat(sliced, '\n'))
end

local function input_line_bounds(ctx, line_idx, lines)
  local start_line = ctx.input_start or 1
  local prompt = ctx.prompt or ''
  local input_lines = lines or buffer_lines(ctx)
  if line_idx < 1 or line_idx > #input_lines then
    return nil
  end
  local row = start_line + line_idx - 2
  local start_col = (line_idx == 1 and prompt ~= '') and #prompt or 0
  local end_col = #input_lines[line_idx]
  return row, start_col, end_col
end

local function offset_to_line_col(lines, offset)
  local remaining = math.max(0, offset or 0)
  for i, line in ipairs(lines) do
    local line_len = #line
    if remaining <= line_len then
      return i, remaining
    end
    remaining = remaining - line_len
    if i < #lines then
      if remaining == 0 then
        return i + 1, 0
      end
      remaining = remaining - 1
    end
  end
  return #lines, #(lines[#lines] or '')
end

local function apply_highlight_range(ctx, lines, spec)
  if type(spec) ~= 'table' then
    return
  end

  local hl_group = spec.hl_group or spec.group or spec[3]
  if hl_group == nil then
    return
  end

  local has_named_lines = spec.line ~= nil or spec.lnum ~= nil or spec.row ~= nil
  local has_named_range = spec.start ~= nil or spec['end'] ~= nil
  local has_tuple_offsets = spec[1] ~= nil and spec[2] ~= nil and spec[3] ~= nil and not has_named_lines and not has_named_range

  local start_line = spec.line or spec.lnum or spec.row
  local start_col = spec.col_start or spec.start_col or spec.col or spec.from
  local end_line = spec.end_line or spec.end_lnum or spec.end_row
  local end_col = spec.col_end or spec.end_col or spec.to or spec.finish

  if has_named_range or has_tuple_offsets then
    local s = math.max(0, tonumber(has_tuple_offsets and spec[1] or spec.start) or 0)
    local e = math.max(s, tonumber(has_tuple_offsets and spec[2] or spec['end']) or s)
    start_line, start_col = offset_to_line_col(lines, s)
    end_line, end_col = offset_to_line_col(lines, e)
  else
    start_line = tonumber(start_line) or 1
    start_col = tonumber(start_col) or 0
    end_line = tonumber(end_line) or start_line
    end_col = tonumber(end_col) or start_col
  end

  local start_buf_row, start_buf_col = input_line_bounds(ctx, start_line, lines)
  local end_buf_row, end_buf_base_col = input_line_bounds(ctx, end_line, lines)
  if start_buf_row == nil or end_buf_row == nil then
    return
  end

  api.nvim_buf_set_extmark(ctx.buf, input_highlight_ns, start_buf_row, start_buf_col + start_col, {
    end_row = end_buf_row,
    end_col = end_buf_base_col + end_col,
    hl_group = hl_group,
  })
end

local function refresh_input_highlight(ctx)
  if ctx == nil or ctx.buf == nil or not api.nvim_buf_is_valid(ctx.buf) then
    return
  end
  api.nvim_buf_clear_namespace(ctx.buf, input_highlight_ns, 0, -1)
  if type(ctx.opts.highlight) ~= 'function' then
    return
  end

  local text = current_text(ctx)
  local ok, ranges = pcall(ctx.opts.highlight, text, ctx.prompt_text or '', {
    buf = ctx.buf,
    win = ctx.win,
  })
  if not ok or type(ranges) ~= 'table' then
    return
  end

  local lines = split_lines(text)
  if vim.tbl_isempty(lines) then
    lines = { '' }
  end
  if ranges.hl_group ~= nil or ranges.group ~= nil or ranges.start ~= nil or ranges.line ~= nil or ranges[3] ~= nil then
    ranges = { ranges }
  end
  for _, spec in ipairs(ranges) do
    apply_highlight_range(ctx, lines, spec)
  end
end

local function initial_input_lines(ctx)
  local initial = normalize_input_text(ctx.initial_text or '')
  local lines = split_lines(initial)
  if vim.tbl_isempty(lines) then
    lines = { '' }
  end
  local rendered = vim.deepcopy(lines)
  rendered[1] = (ctx.prompt or '') .. (rendered[1] or '')
  return rendered, lines
end

local function trigger_completion(ctx, direction)
  if ctx == nil or ctx.buf == nil or not api.nvim_buf_is_valid(ctx.buf) then
    return
  end
  if vim.fn.pumvisible() == 1 then
    local key = direction < 0 and '<C-p>' or '<C-n>'
    api.nvim_feedkeys(api.nvim_replace_termcodes(key, true, false, true), 'n', false)
    return
  end
  if ctx.completion == nil or ctx.win == nil or not api.nvim_win_is_valid(ctx.win) then
    return
  end

  local cursor = api.nvim_win_get_cursor(ctx.win)
  local line_no = cursor[1]
  local col = cursor[2]
  if line_no < (ctx.input_start or 1) then
    return
  end
  local line = api.nvim_buf_get_lines(ctx.buf, line_no - 1, line_no, false)[1] or ''
  local prefix_start = 1
  if line_no == (ctx.input_start or 1) then
    prefix_start = #(ctx.prompt or '') + 1
  end
  local current = line:sub(prefix_start, col)
  local matches = vim.fn.getcompletion(current, ctx.completion)
  if vim.tbl_isempty(matches) then
    return
  end
  vim.fn.complete(prefix_start, matches)
  if #matches > 0 then
    api.nvim_feedkeys(api.nvim_replace_termcodes(direction < 0 and '<C-p>' or '<C-n>', true, false, true), 'n', false)
  end
end

local function finish_input(ctx, text, aborted)
  if ctx == nil or ctx.finished == true then
    return
  end
  ctx.finished = true
  if aborted and type(ctx.on_cancel) == 'function' then
    pcall(ctx.on_cancel, text)
  end
  if type(ctx.on_confirm) == 'function' then
    pcall(ctx.on_confirm, aborted and nil or text)
  end
  close_input(ctx)
end

local function close_input(ctx)
  if ctx == nil then
    return
  end
  if ctx.closed then
    return
  end
  ctx.closed = true
  if ctx.win ~= nil and api.nvim_win_is_valid(ctx.win) then
    api.nvim_win_close(ctx.win, true)
  end
  if ctx.buf ~= nil and api.nvim_buf_is_valid(ctx.buf) then
    api.nvim_buf_delete(ctx.buf, { force = true })
  end
end

local function onchange_callback(bufnr)
  local ctx = current_context(bufnr)
  if ctx == nil then
    return
  end
  local new_text = current_text(ctx)
  if #new_text == 0 or new_text == ctx.opts.default then
    return
  end
  log(new_text)
  ctx.on_change(new_text)
end

local function input(opts, on_confirm)
  log(opts)
  opts = opts or {}
  local bufnr = api.nvim_create_buf(false, true)
  local ctx = vim.tbl_deep_extend('force', {}, input_defaults, { opts = opts })

  local prompt = opts.prompt or ''
  local placeholder = opts.placeholder or opts.default or ''
  local explicit_title = opts.title or ctx.title or ''
  local window_title = derive_window_title({
    explicit_title = explicit_title,
    prompt_text = prompt,
  })
  ctx.prompt_text = prompt
  ctx.explicit_title = explicit_title
  ctx.window_title = window_title
  ctx.initial_text = opts.default ~= nil and opts.default or placeholder
  ctx.completion = opts.completion

  local setup_confirm = type(ctx.on_confirm) == 'function' and ctx.on_confirm or nil
  ctx.on_confirm = function(new_name)
    if type(setup_confirm) == 'function' then
      local ok, err = pcall(setup_confirm, new_name)
      if not ok then
        log('input: setup_confirm error: ' .. tostring(err))
      end
    end
    if type(on_confirm) == 'function' then
      local ok2, err2 = pcall(on_confirm, new_name)
      if not ok2 then
        log('input: on_confirm error: ' .. tostring(err2))
      end
    end
  end

  ctx.on_change = opts.on_change or ctx.on_change
  ctx.on_cancel = opts.on_cancel or ctx.on_cancel
  api.nvim_set_option_value('buftype', 'prompt', { buf = bufnr })
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  local title_options = utils.title_options
  local use_content_box = should_use_content_box(ctx)
  local prompt_icon = ' '
  local prompt_prefix = use_content_box and '│  ' or prompt_icon
  local width = opts.width or math.max(win_title_width, strwidth(prompt .. placeholder) + 2)
  local content_lines = {}
  local separator_line = nil
  if use_content_box then
    width = math.max(width, strwidth(prompt) + 4, strwidth(window_title or '') + 4)
  end
  width = math.min(width, input_max_width(ctx))

  if use_content_box then
    content_lines = build_content_lines(ctx, width)
    separator_line = build_separator_line(width)
    for _, line in ipairs(content_lines) do
      width = math.min(input_max_width(ctx), math.max(width, strwidth(line) + 2))
    end
  end
  ctx.min_width = width
  ctx.input_start = #content_lines + (separator_line and 2 or 1)

  local input_row = opts.row or -3
  prompt = prompt_prefix
  ctx.prompt = prompt
  ctx.placeholder = placeholder
  ctx.dynamic_row = opts.row == nil and not use_content_box and true or false
  local wopts = {
    relative = opts.relative or 'cursor',
    width = width,
    height = math.max(1, #content_lines + 1),
    row = input_row,
    col = opts.col or 0,
    style = 'minimal',
    border = 'rounded',
  }
  if window_title ~= nil and window_title ~= '' then
    local title = title_options(window_title)
    if title then
      wopts.title = title
      wopts.title_pos = opts.title_pos or 'center'
    end
  end

  vim.fn.prompt_setprompt(bufnr, prompt)
  local winnr = api.nvim_open_win(bufnr, true, wopts)
  ctx.buf = bufnr
  ctx.win = winnr
  input_contexts[bufnr] = ctx
  api.nvim_set_option_value('winhl', 'Normal:NormalFloat,NormalNC:Normal', { win = winnr })
  api.nvim_set_option_value('wrap', true, { win = winnr })
  api.nvim_set_option_value('linebreak', false, { win = winnr })
  ctx.hl_ns = utils.disable_win_strikethrough(winnr, ctx.hl_ns)
  local buf_lines = { '' }
  if use_content_box then
    buf_lines = vim.tbl_extend('force', {}, content_lines)
    table.insert(buf_lines, separator_line or '')
  end
  local initial_lines = initial_input_lines(ctx)
  vim.list_extend(buf_lines, initial_lines)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, buf_lines)
  api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    once = true,
    callback = function()
      input_contexts[bufnr] = nil
      close_input(ctx)
    end,
  })

  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = bufnr,
    callback = function()
      resize_input(ctx)
      local new_text = current_text(ctx)
      log('text changed', new_text)
      if type(ctx.on_change) == 'function' then
        ctx.on_change(new_text)
      end
      refresh_input_highlight(ctx)
    end,
  })
  api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  api.nvim_set_option_value('buftype', 'prompt', { buf = bufnr })

  api.nvim_set_option_value('filetype', 'guihua', { buf = bufnr })
  local function close_all()
    close_input(ctx)
  end
  api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(winnr),
    once = true,
    callback = close_all,
  })
  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    log('confirm_callback')
    vim.cmd([[stopinsert]])
    local new_text = current_text(ctx)
    log('on_confirm: new text: ' .. new_text)
    finish_input(ctx, new_text, false)
  end, { silent = true, buffer = bufnr })

  local function abort_input()
    vim.cmd([[stopinsert]])
    finish_input(ctx, current_text(ctx), true)
  end
  vim.keymap.set({ 'n', 'i' }, '<Esc>', abort_input, { silent = true, buffer = bufnr })
  vim.keymap.set({ 'n', 'i' }, '<C-c>', abort_input, { silent = true, buffer = bufnr })
  vim.keymap.set('n', '<ESC><ESC>', abort_input, { silent = true, buffer = bufnr })
  vim.keymap.set({ 'n', 'i' }, '<BS>', [[<ESC>"_cl]], { silent = true, buffer = bufnr })
  if ctx.completion ~= nil and ctx.completion ~= '' then
    vim.keymap.set('i', '<Tab>', function()
      trigger_completion(ctx, 1)
    end, { silent = true, buffer = bufnr })
    vim.keymap.set('i', '<S-Tab>', function()
      trigger_completion(ctx, -1)
    end, { silent = true, buffer = bufnr })
  end
  -- Enter insert mode and place cursor at end of default value by default.
  local start_insert = true
  if opts.startinsert ~= nil then
    start_insert = opts.startinsert
  end
  local input_lines = split_lines(normalize_input_text(ctx.initial_text or ''))
  if vim.tbl_isempty(input_lines) then
    input_lines = { '' }
  end
  api.nvim_win_set_cursor(winnr, {
    (ctx.input_start or 1) + #input_lines - 1,
    (#input_lines == 1 and #(ctx.prompt or '') or 0) + #(input_lines[#input_lines] or ''),
  })
  if start_insert then
    vim.cmd('startinsert!')
  end
  resize_input(ctx)
  refresh_input_highlight(ctx)
  -- vim.fn.feedkeys('A', 'n')
  return winnr
end

-- functional test, do not remove
if false then
  input({ prompt = 'replace: abc with \n def', placeholder = 'old' }, function(text)
    print('replace old' .. 'with: ' .. text)
    print('on change: ' .. text)
    local f, err = io.open('/tmp/log.txt', 'w')
    print('file open result: ' .. tostring(f) .. ', error: ' .. tostring(err))
    if not f then
      print('Error opening file: ' .. tostring(err))
      return nil, err
    end
    f:write(text)
    f:close()
  end)
end
return {
  setup = setup,
  input = input,
  onchange_callback = onchange_callback,
  input_callback = onchange_callback,
}
