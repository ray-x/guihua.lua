local utils = require('guihua.util')
local log = require('guihua.log').info
local api = vim.api

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

local function strwidth(text)
  return vim.fn.strdisplaywidth(text or '')
end

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(value, max_value))
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
  local screen_max = math.max(20, columns - 4)
  local configured = ctx.opts.max_width or math.floor(columns * 0.9)
  return clamp(configured, 20, screen_max)
end

local function input_min_width(ctx)
  local preferred = ctx.opts.width or 20
  local seed = (ctx.prompt or '') .. (ctx.placeholder or '')
  return math.max(preferred, math.min(strwidth(seed) + 2, input_max_width(ctx)))
end

local function resize_input(ctx)
  if ctx == nil or ctx.win == nil or not api.nvim_win_is_valid(ctx.win) then
    return
  end

  local max_width = input_max_width(ctx)
  local max_line_width, line_count = display_metrics(ctx)
  local width = math.min(max_width, math.max(input_min_width(ctx), max_line_width + 1))
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
  if ctx.dynamic_row then
    cfg.row = -(height + 2)
  end
  api.nvim_win_set_config(ctx.win, cfg)
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

  local prompt = ctx.prompt or ''
  if prompt ~= '' and vim.startswith(lines[1], prompt) then
    lines[1] = lines[1]:sub(#prompt + 1, -1)
  end

  return vim.trim(table.concat(lines, '\n'))
end

local function close_input(ctx)
  if ctx == nil then
    return
  end
  if ctx.win ~= nil and api.nvim_win_is_valid(ctx.win) then
    api.nvim_win_close(ctx.win, true)
    return
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
  local bufnr = api.nvim_create_buf(false, true)
  local ctx = vim.tbl_deep_extend('force', {}, input_defaults, { opts = opts })

  local prompt = opts.prompt or ''
  local placeholder = opts.placeholder or opts.default or ''

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
  local width = opts.width or math.max(20, strwidth(prompt .. placeholder) + 2)
  local wopts = {
    relative = opts.relative or 'cursor',
    width = width,
    height = 1,
    row = opts.row or -3,
    col = opts.col or 0,
    style = 'minimal',
    border = 'single',
  }
  if opts.title or ctx.title or #prompt > 2 then
    local title = title_options(opts.title or ctx.title or prompt)
    if title then
      wopts.title = title
      wopts.title_pos = opts.title_pos or 'center'
    end
    prompt = ' '
  end

  ctx.prompt = prompt
  ctx.placeholder = placeholder
  ctx.dynamic_row = opts.row == nil and wopts.relative == 'cursor'
  vim.fn.prompt_setprompt(bufnr, prompt)
  local winnr = api.nvim_open_win(bufnr, true, wopts)
  ctx.buf = bufnr
  ctx.win = winnr
  input_contexts[bufnr] = ctx
  api.nvim_set_option_value('winhl', 'Normal:NormalFloat,NormalNC:Normal', { win = winnr })
  api.nvim_set_option_value('wrap', true, { win = winnr })
  api.nvim_set_option_value('linebreak', false, { win = winnr })
  ctx.hl_ns = utils.disable_win_strikethrough(winnr, ctx.hl_ns)
  api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    once = true,
    callback = function()
      input_contexts[bufnr] = nil
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
    end,
  })
  api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  api.nvim_set_option_value('buftype', 'prompt', { buf = bufnr })

  api.nvim_set_option_value('filetype', 'guihua', { buf = bufnr })
  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    log('confirm_callback')
    local new_text = current_text(ctx)
    vim.cmd([[stopinsert]])
    if #new_text == 0 or new_text == ctx.opts.default then
      log('no change')
      if type(ctx.on_cancel) == 'function' then
        log('on cancel called')
        pcall(ctx.on_cancel, new_text)
      end
      log('closing input')
      close_input(ctx)
      return
    end
    log('on_confirm: new text: ' .. new_text)
    if type(ctx.on_confirm) == 'function' then
      pcall(ctx.on_confirm, new_text)
    end
    close_input(ctx)
  end, { silent = true, buffer = bufnr })

  vim.keymap.set('n', '<ESC><ESC>', function()
    local new_text = current_text(ctx)
    if type(ctx.on_cancel) == 'function' then
      pcall(ctx.on_cancel, new_text)
    end
    close_input(ctx)
  end, { silent = true, buffer = bufnr })
  vim.keymap.set({ 'n', 'i' }, '<BS>', [[<ESC>"_cl]], { silent = true, buffer = bufnr })
  vim.cmd(string.format('normal i%s', placeholder))
  -- Enter insert mode and place cursor at end of default value by default.
  local start_insert = true
  if opts.startinsert ~= nil then
    start_insert = opts.startinsert
  end
  if start_insert then
    vim.cmd('startinsert!')
  end
  resize_input(ctx)
  -- vim.fn.feedkeys('A', 'n')
  return winnr
end

-- functional test
-- input({ prompt = 'replace: ', placeholder = 'old', title = 'title' }, function(text)
-- print('replace old' .. 'with: ' .. text)
-- print('on change: ' .. text)
-- local f, err = io.open('/tmp/log.txt', 'w')
-- print('file open result: ' .. tostring(f) .. ', error: ' .. tostring(err))
-- if not f then
-- print('Error opening file: ' .. tostring(err))
-- return nil, err
-- end
-- f:write(text)
-- f:close()
-- end)

return {
  setup = setup,
  input = input,
  onchange_callback = onchange_callback,
  input_callback = onchange_callback,
}
