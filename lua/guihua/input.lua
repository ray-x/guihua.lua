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
  local line = vim.fn.getline('.')
  return vim.trim(line:sub(#ctx.prompt + 1, -1))
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
  local setup_confirm = ctx.on_confirm
  ctx.on_confirm = function(new_name)
    setup_confirm(new_name)
    if on_confirm then
      on_confirm(new_name)
    end
  end

  ctx.on_change = opts.on_change or ctx.on_change
  ctx.on_cancel = opts.on_cancel or ctx.on_cancel
  api.nvim_set_option_value('buftype', 'prompt', { buf = bufnr })
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  local title_options = utils.title_options
  local width = #placeholder + #prompt + (opts.width or 20)
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
  vim.fn.prompt_setprompt(bufnr, prompt)
  local winnr = api.nvim_open_win(bufnr, true, wopts)
  ctx.buf = bufnr
  ctx.win = winnr
  input_contexts[bufnr] = ctx
  api.nvim_set_option_value('winhl', 'Normal:NormalFloat,NormalNC:Normal', { win = winnr })
  api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    once = true,
    callback = function()
      input_contexts[bufnr] = nil
    end,
  })

  if ctx.on_change then
    api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      buffer = bufnr,
      callback = function()
        local new_text = current_text(ctx)
        log('text changed', new_text)
        ctx.on_change(new_text)
      end,
    })
    api.nvim_set_option_value('modifiable', true, { buf = bufnr })
    api.nvim_set_option_value('buftype', 'prompt', { buf = bufnr })
  end

  api.nvim_set_option_value('filetype', 'guihua', { buf = bufnr })
  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    log('confirm_callback')
    local new_text = current_text(ctx)
    vim.cmd([[stopinsert]])
    close_input(ctx)
    if #new_text == 0 or new_text == ctx.opts.default then
      log('no change')
      ctx.on_cancel(new_text)
      return
    end
    log('on_confirm: new text: ' .. new_text)
    ctx.on_confirm(new_text)
  end, { silent = true, buffer = bufnr })

  vim.keymap.set('n', '<ESC><ESC>', function()
    local new_text = current_text(ctx)
    ctx.on_cancel(new_text)
    close_input(ctx)
  end, { silent = true, buffer = bufnr })
  vim.keymap.set({ 'n', 'i' }, '<BS>', [[<ESC>"_cl]], { silent = true, buffer = bufnr })
  vim.cmd(string.format('normal i%s', placeholder))
  vim.fn.feedkeys('A', 'n')
  return winnr
end

-- functional test
-- input({ prompt = 'replace: ', placeholder = 'old', title = 'title' }, function(text)
--   print('replace old' .. 'with: ' .. text)
-- end, function(text)
--   print('on change: ' .. text)
-- end)

-- input({ prompt = 'replace: ', placeholder = 'old text' }, function(text)
--   print('replace old' .. 'with: ' .. text)
-- end)

return {
  setup = setup,
  input = input,
  onchange_callback = onchange_callback,
}
