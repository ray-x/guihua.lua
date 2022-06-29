local api = vim.api
local location = require('guihua.location')
-- local validate = vim.validate
-- local utils = require('guihua.util')
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local columns = api.nvim_get_option('columns')
local lines = api.nvim_get_option('lines')
local shell = api.nvim_get_option('shell')
local shellcmdflag = api.nvim_get_option('shellcmdflag')
if _GH_SETUP == nil then
  require('guihua').setup()
end

-- Create a simple floating terminal.
local function floating_buf(opts) -- win_width, win_height, x, y, loc, prompt, enter, ft)
  local prompt = opts.prompt or false
  local enter = opts.enter or false
  local x = opts.x or 0
  local y = opts.y or 0
  -- if opts.border == "single" then
  --   opts.border = {}
  -- end
  -- win_w, win_h, x, y should be passwd in from view
  local loc = opts.loc or location.center
  local row, col = loc(opts.win_height, opts.win_width)

  log('loc', opts.loc, opts.win_width, opts.win_height, x, y, enter, col, row, opts.ft)
  local win_opts = {
    style = opts.style or 'minimal',
    width = opts.win_width or 80,
    height = opts.win_height or 23,
    border = opts.border or 'single', -- "shadow"
  }

  if opts.external then
    win_opts.external = true
  else
    win_opts.relative = opts.relative or 'editor'
    win_opts.bufpos = { 0, 0 }
  end

  if win_opts.relative == 'editor' then
    win_opts.row = row + y
    win_opts.col = col + x
  end

  if win_opts.relative == 'cursor' and y ~= 0 then
    win_opts.row = y
  end

  log('floating size', win_opts.height, win_opts.width)
  trace('floating opts: ', win_opts, opts)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'buflisted', false)
  -- api.nvim_buf_set_option(buf, 'buftype', 'guihua_input')
  if prompt then
    vim.fn.prompt_setprompt(buf, ' ')
    api.nvim_buf_set_option(buf, 'buftype', 'prompt') -- vim.fn.setbufvar(bufnr, "buflisted", 0)
  else
    api.nvim_buf_set_option(buf, 'readonly', true)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'guihua') -- default ft for all buffers. do not use specific ft e.g
    -- javascript as it may cause lsp loading
  end
  local win = api.nvim_open_win(buf, enter, win_opts)
  log('creating win', win, 'buf', buf)

  -- note: if failed to focus on the view, you can add to the caller
  -- vim.fn.win_gotoid(win)

  -- api.nvim_buf_set_option(buf, "nobuflisted")
  return buf,
    win,
    function()
      if win == nil then
        -- already closed or not valid
        return
      end
      log('floatwin closing ', win)
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
        win = nil
      end
    end
end

-- Create a mask.
local function floating_buf_mask(transparency) -- win_width, win_height, x, y, loc, prompt, enter, ft)
  vim.validate({ transparency = { transparency, 'number' } })
  columns = api.nvim_get_option('columns')
  lines = api.nvim_get_option('lines')
  -- local loc = location.center
  -- local row, col = loc(lines, columns)
  local win_opts = {
    style = 'minimal',
    relative = 'editor',
    width = columns,
    height = lines,
    bufpos = { 0, 0 },
    zindex = 1, -- on bottom
  }

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  -- api.nvim_buf_set_option(buf, 'buftype', 'guihua_input')
  api.nvim_buf_set_option(buf, 'readonly', true)
  api.nvim_buf_set_option(buf, 'buflisted', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'guihua') -- default ft for all buffers. do not use specific ft e.g
  -- javascript as it may cause lsp loading
  local win = api.nvim_open_win(buf, false, win_opts)
  api.nvim_win_set_option(win, 'winblend', transparency)
  log('creating win', win, 'buf', buf)

  return buf,
    win,
    function()
      if win == nil then
        -- already closed or not valid
        return
      end
      log('floatwin closing ', win)
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
        win = nil
      end
    end
end

-- prepare buf and win for floatterm
local function floatterm(opts)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_keymap(buf, 't', '<ESC>', '<C-\\><C-c>', {})
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'buflisted', false)

  log(opts)
  local width = opts.win_width or math.floor(columns * 0.9)
  local height = opts.win_height or math.floor(lines * 0.9)
  local win_opts = {
    relative = 'editor',
    style = 'minimal',
    row = opts.y or math.floor((lines - height) * 0.5),
    col = opts.x or math.floor((columns - width) * 0.5),
    width = width,
    height = height,
    border = opts.border,
  }

  if opts.external then
    win_opts.external = true
    win_opts.relative = nil
    win_opts.row = nil
    win_opts.col = nil
  end

  log(win_opts)
  local win = api.nvim_open_win(buf, true, win_opts)
  return win, buf, win_opts
end

-- Create a simple floating terminal.
local function floating_term(opts) -- cmd, callback, win_width, win_height, x, y)
  local current_window = vim.api.nvim_get_current_win()
  opts.enter = opts.enter or true

  if opts.cmd == '' or opts.cmd == nil then
    opts.cmd = vim.api.nvim_get_option('shell')
  end

  -- get dimensions
  -- calculate our floating window size
  columns = api.nvim_get_option('columns')
  lines = api.nvim_get_option('lines')
  opts.win_height = opts.win_height or math.ceil(lines * 0.88)
  opts.win_width = opts.win_width or math.ceil(columns * 0.88)
  local win, buf, _ = floatterm(opts)

  api.nvim_win_set_option(win, 'winhl', 'Normal:Normal')

  local closer = function()
    log('floatwin closing ', win)

    if opts.autoclose ~= false then
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
        win = nil
      end
    end
    if opts.closer ~= nil then
      opts.closer(opts.closer_args)
    end
  end
  vim.api.nvim_buf_set_option(buf, 'filetype', 'guihua') -- default ft for all buffers. do not use specific ft e.g

  local args
  if type(opts.cmd) == 'string' then
    args = { shell, shellcmdflag, opts.cmd }
  else
    args = opts.cmd
  end

  vim.fn.termopen(args, {
    on_exit = function(_, _, _)
      if opts.autoclose ~= false then
        vim.api.nvim_set_current_win(current_window)
        closer()
      end
    end,
  })

  if opts.autoclose ~= false then
    vim.cmd('startinsert!')
  end

  return buf, win, closer
end

local function close_float_terminal(name)
  local cur_buf = api.nvim_get_current_buf()
  local has_var, float_term_win = pcall(api.nvim_buf_get_var, cur_buf, name)
  if not has_var then
    return
  end
  if float_term_win[1] ~= nil and api.nvim_buf_is_valid(float_term_win[1]) then
    api.nvim_buf_delete(float_term_win[1], { force = true })
  end
  if float_term_win[2] ~= nil and api.nvim_win_is_valid(float_term_win[2]) then
    api.nvim_win_close(float_term_win[2], true)
  end
end

-- wrapper for tui/gui
local term = function(opts)
  columns = api.nvim_get_option('columns')
  lines = api.nvim_get_option('lines')

  local win_width, win_height
  if type(opts.vsplit) == 'boolean' and opts.vsplit == true then
    opts.vsplit = 130
  end
  if opts.vsplit and columns > opts.vsplit then
    -- split in right
    win_height = math.ceil(lines * 0.98)
    win_width = math.ceil(columns * (opts.vwidth_rator or 0.5))

    opts.y = win_height
    opts.x = columns - win_width
  else
    win_height = math.ceil(lines * (opts.height_ratio or 0.6))
    win_width = math.ceil(columns * 0.98)

    opts.y = opts.y or lines - win_height
    opts.x = opts.x or 1
  end
  opts.win_height = opts.win_height or win_height
  opts.win_width = opts.win_width or win_width
  opts.border = opts.border or 'single'
  if opts.autoclose == nil then
    opts.autoclose = true
  end

  opts.closer = function()
    log('closer callback')
    vim.cmd('set noconfirm')
    vim.cmd('bufdo e!')
    vim.cmd('set confirm')
  end
  opts.closer_args = {}
  local buf, win, closer = floating_term(opts)
  api.nvim_command('setlocal nobuflisted')
  local var_key = opts.term_name or 'guihua_floating_term'
  api.nvim_buf_set_var(buf, var_key, { buf, win })
  local m = _GH_SETUP.maps
  local f = string.format('lua require("guihua.floating").close(%s)<CR>', var_key)
  vim.api.nvim_buf_set_keymap(buf, 'n', m.close_view, f, {})
  vim.api.nvim_buf_set_keymap(buf, 'i', m.close_view, f, {})
  return buf, win, closer
end

--
-- test_mask()
-- test(true)
-- test2(false)
-- test_term(true)
-- multigrid
-- floating_term({ cmd = 'lazygit', border = 'single', external = true })
-- floating_term({ cmd = 'pwd', border = 'single', external = false, autoclose = false })
-- floating_term({ cmd = 'lazygit', border = 'single', external = false })
-- term({ cmd = 'fish', border = 'single', external = false })
local function test(prompt)
  local b, w, c = floating_buf({
    win_width = 30,
    win_height = 6,
    x = 5,
    y = 5,
    prompt = prompt,
    focus = true,
  })
  local data = { 'floating buf', 'line1', 'line2', 'line3', 'line4', 'line5' }
  for i = 1, 10, 1 do
    vim.api.nvim_buf_set_lines(b, i, -1, false, { data[i] })
  end
  -- vim.cmd('silent buffer ' .. tostring(b))
  -- vim.fn.win_gotoid(w)
  if prompt == true then
    vim.cmd('startinsert!')
  end
end

local function test2(prompt)
  local b, w, c = floating_buf({ win_width = 30, win_height = 8, x = 25, y = 25, prompt = prompt })
  local data = { 'floating buf', 'linea', 'lineb', 'linec', 'lined', 'linee' }
  for i = 1, 10, 1 do
    vim.api.nvim_buf_set_lines(b, i, -1, false, { data[i] })
  end
  if prompt == true then
    vim.cmd('startinsert!')
  end
end

local function test_mask()
  local b, w, c = floating_buf_mask()
end

return {
  floating_buf = floating_buf,
  floating_term = floating_term,
  floating_buf_mask = floating_buf_mask,
  input = function(o, confirm, change)
    print('please use gui.input')
    return require('guihua.gui').input(o, confirm, change)
  end,
  input_callback = function()
    print('please use gui.input_callback')
    return require('guihua.gui').input_callback()
  end,
  gui_term = term,
  close = close_float_terminal,
}
