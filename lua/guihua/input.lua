local utils = require('guihua.util')
local log = require('guihua.log').info

local input_ctx = {
  opts = {},
  on_confirm = function(_)
    log('default on confirm')
  end,
  on_change = function(_, _, _)
    log('default on change')
  end,
  on_cancel = function(_) end,
}

local setup = function(opts)
  if opts then
    input_ctx = vim.tbl_deep_extend('force', input_ctx, opts)
  end
end

local function onchange_callback()
  -- log(input_ctx)
  local new_text = vim.trim(vim.fn.getline('.'):sub(#input_ctx.opts.prompt + 1, -1))
  if #new_text == 0 or new_text == input_ctx.opts.default then
    return
  end
  log(new_text)
  input_ctx.on_change(new_text)
end

local function input(opts, on_confirm)
  log(opts)
  -- local preview_buf = vim.api.nvim_get_current_buf()
  -- local preview_ns = vim.api.nvim_create_namespace('guihua_input')
  local bufnr = vim.api.nvim_create_buf(false, true)

  input_ctx.opts = opts
  local prompt = opts.prompt or '﵀ '
  local placeholder = opts.default or ''
  local setup_confirm = input_ctx.on_confirm
  input_ctx.on_confirm = function(new_name)
    setup_confirm(new_name)
    on_confirm(new_name)
  end
  input_ctx.on_change = opts.on_change or input_ctx.on_change
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'prompt')
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_add_highlight(bufnr, -1, 'NGPreviewTitle', 0, 0, #prompt)
  vim.fn.prompt_setprompt(bufnr, prompt)
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

  local title_options = utils.title_options
  if opts.title or input_ctx.title and vim.fn.has('nvim-0.9') then
    local title = title_options(opts.title or input_ctx.title)
    print(vim.inspect(title))
    if title then
      wopts.title = title
      wopts.title = opts.title or input_ctx.title
      wopts.title_pos = opts.title_pos or 'center'
    end
  end

  local winnr = vim.api.nvim_open_win(bufnr, true, wopts)
  vim.api.nvim_win_set_option(winnr, 'winhl', 'Normal:NormalFloat,NormalNC:Normal')
  if input_ctx.on_change then
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      buffer = bufnr,
      callback = function()
        local new_text = vim.trim(vim.fn.getline('.'):sub(#prompt + 1, -1))
        log('text changed', new_text)
        if #new_text == 0 or new_text == input_ctx.opts.default then
          return
        end
        input_ctx.on_change(new_text)
      end,
    })
    -- vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, { buffer = bufnr, callback = function() end })
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'prompt')
  end

  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'guihua')
  utils.map('n', '<ESC>', '<cmd>bd!<CR>', { silent = true, buffer = true })
  utils.map({ 'n', 'i' }, '<CR>', function()
    log('confirm_callback')
    local new_text = vim.trim(vim.fn.getline('.'):sub(#input_ctx.opts.prompt + 1, -1))
    vim.cmd([[stopinsert]])
    vim.cmd([[bd!]])
    if #new_text == 0 or new_text == input_ctx.opts.default then
      log('no change')
      return
    end
    log('on_confirm: new text: ' .. new_text)
    input_ctx.on_confirm(new_text)
  end, { silent = true, buffer = true })

  utils.map({ 'n' }, '<ESC>', function()
    local new_text = vim.trim(vim.fn.getline('.'):sub(#prompt + 1, -1))
    input_ctx.on_cancel(new_text)
    -- close current floatwindow
    vim.api.nvim_win_close(0, true)
  end, { silent = true, buffer = true })
  utils.map({ 'n', 'i' }, '<BS>', [[<ESC>"_cl]], { silent = true, buffer = true })

  vim.cmd(string.format('normal i%s', placeholder))
  return winnr
end

-- input({ prompt = 'replace: ', placeholder = 'old', title = 'title' }, function(text)
--   print('replace old' .. 'with: ' .. text)
-- end, function(text)
--   print('on change: ' .. text)
-- end)

-- input({ prompt = 'replace: ', placeholder = 'old' }, function(text)
--   print('replace old' .. 'with: ' .. text)
-- end)

return {
  setup = setup,
  input = input,
  onchange_callback = onchange_callback,
}
