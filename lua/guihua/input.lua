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
  on_concel = function(_) end,
}

local setup = function(opts)
  if opts then
    input_ctx = vim.tbl_deep_extend('force', input_ctx, opts)
  end
end

local function input_callback()
  -- log(input_ctx)
  local new_text = vim.trim(vim.fn.getline('.'):sub(#input_ctx.opts.prompt + 1, -1))
  vim.cmd([[stopinsert]])
  vim.cmd([[bd!]])
  if #new_text == 0 or new_text == input_ctx.opts.default then
    return
  end
  input_ctx.on_confirm(new_text)
end

local function onchange_callback()
  -- log(input_ctx)
  local new_text = vim.trim(vim.fn.getline('.'):sub(#input_ctx.opts.prompt + 1, -1))
  if #new_text == 0 or new_text == input_ctx.opts.default then
    return
  end
  log(new_text)
  -- input_ctx.on_change(new_text)
end

local function input(opts, on_confirm, on_change)
  log(opts)
  local preview_buf = vim.api.nvim_get_current_buf()
  local preview_ns = vim.api.nvim_create_namespace('guihua_input')
  local bufnr = vim.api.nvim_create_buf(false, true)

  input_ctx.opts = opts
  local prompt = opts.prompt or '﵀ '
  local placeholder = opts.default or ''
  input_ctx.on_confirm = on_confirm or input_ctx.on_confirm
  input_ctx.on_change = on_change or input_ctx.on_change
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'prompt')
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_add_highlight(bufnr, -1, 'NGPreviewTitle', 0, 0, #prompt)
  vim.fn.prompt_setprompt(bufnr, prompt)
  local width = #placeholder + #prompt + 10
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = 'cursor',
    width = width,
    height = 1,
    row = -3,
    col = 1,
    style = 'minimal',
    border = 'single',
  })
  vim.api.nvim_win_set_option(winnr, 'winhl', 'Normal:Floating')
  if input_ctx.on_change then
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      buffer = bufnr,
      callback = function()
        local new_text = vim.trim(vim.fn.getline('.'):sub(#prompt + 1, -1))
        log('text changed', new_text)
        if #new_text == 0 or new_text == input_ctx.opts.default then
          return
        end
        print(new_text)
        input_ctx.on_confirm(new_text)
      end,
    })
    -- vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, { buffer = bufnr, callback = function() end })
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'prompt')
  end

  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'guihua')
  utils.map('n', '<ESC>', '<cmd>bd!<CR>', { silent = true, buffer = true })
  utils.map(
    { 'n', 'i' },
    '<CR>',
    "<cmd>lua require('guihua.input').input_callback()<CR>",
    { silent = true, buffer = true }
  )
  utils.map({ 'n', 'i' }, '<BS>', [[<ESC>"_cl]], { silent = true, buffer = true })

  vim.cmd(string.format('normal i%s', placeholder))
  return winnr
end

-- input({ prompt = 'replace: ', placeholder = 'old' }, function(text)
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
  input_callback = input_callback,
  onchange_callback = onchange_callback,
}
