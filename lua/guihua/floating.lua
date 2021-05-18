local api = vim.api
local location = require "guihua.location"

local log = require"guihua.log".info
local trace = require"guihua.log".trace
local columns = api.nvim_get_option("columns")
local lines = api.nvim_get_option("lines")
local shell = api.nvim_get_option("shell")
local shellcmdflag = api.nvim_get_option("shellcmdflag")

-- Create a simple floating terminal.
local function floating_buf(opts) -- win_width, win_height, x, y, loc, prompt, enter, ft)
  local prompt = opts.prompt or false
  local enter = opts.enter or false
  local x = opts.x or 0
  local y = opts.y or 0
  log("loc", opts.loc, opts.win_width, opts.win_height, x, y, enter, opts.ft)
  -- win_w, win_h, x, y should be passwd in from view
  local loc = opts.loc or location.center
  local row, col = loc(opts.win_height, opts.win_width)
  local win_opts = {
    style = opts.style or "minimal",
    relative = opts.relative or "editor",
    width = opts.win_width or 80,
    height = opts.win_height or 20,
    bufpos = {0, 0},
    border = opts.border or "none" -- "shadow"
  }
  if win_opts.relative == "editor" then
    win_opts.row = row + y
    win_opts.col = col + x
  end
  trace("floating", win_opts, opts)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  -- api.nvim_buf_set_option(buf, 'buftype', 'guihua_input')
  vim.cmd("setlocal nobuflisted")
  if prompt then
    vim.fn.prompt_setprompt(buf, " ")
    api.nvim_buf_set_option(buf, "buftype", "prompt")
  else
    api.nvim_buf_set_option(buf, "readonly", true)
    vim.api.nvim_buf_set_option(buf, "filetype", "guihua") -- default ft for all buffers. do not use specific ft e.g
    -- javascript as it may cause lsp loading
  end
  local win = api.nvim_open_win(buf, enter, win_opts)
  log("creating win", win, "buf", buf)
  return buf, win, function()
    if win == nil then
      -- already closed or not valid
      return
    end
    log("floatwin closing ", win)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      win = nil
    end
  end
end

-- prepare buf and win for floatterm
local function floatterm(opts)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_keymap(buf, "t", "<ESC>", "<C-\\><C-c>", {})
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local width = opts.win_width or math.floor(columns * 0.9)
  local height = opts.win_height or math.floor(lines * 0.9)
  local win_opts = {
    relative = "editor",
    style = "minimal",
    row = math.floor((lines - height) * 0.5),
    col = math.floor((columns - width) * 0.5),
    width = width,
    height = height,
    border = opts.border
  }

  local win = api.nvim_open_win(buf, true, win_opts)
  return win, buf, win_opts
end

-- Create a simple floating terminal.
local function floating_term(opts) -- cmd, callback, win_width, win_height, x, y)
  local current_window = vim.api.nvim_get_current_win()
  opts.enter = opts.enter or true
  opts.x = opts.x or 1
  opts.y = opts.y or 1

  if opts.cmd == "" or opts.cmd == nil then
    opts.cmd = vim.api.nvim_get_option("shell")
  end

  -- get dimensions
  -- local width = api.nvim_get_option("columns")
  -- local height = api.nvim_get_option("lines")

  -- calculate our floating window size
  opts.win_height = opts.win_width or math.ceil(lines * 0.88)
  opts.win_width = opts.win_width or math.ceil(columns * 0.88)
  local win, buf, _ = floatterm(opts)

  api.nvim_win_set_option(win, "winhl", "Normal:Normal")
  api.nvim_command("startinsert!")
  local closer = function()
    log("floatwin closing ", win)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      win = nil
    end
  end

  local args = {shell, shellcmdflag, opts.cmd}

  vim.fn.termopen(args, {
    on_exit = function(_, _, _)
      -- local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      vim.api.nvim_set_current_win(current_window)
      closer()
      -- if callback then
      --   callback(lines)
      -- end
    end
  })

  vim.cmd("startinsert!")
  return buf, win, closer
end

local function test(prompt)
  local b, w, c = floating_buf({
    win_width = 30,
    win_height = 6,
    x = 5,
    y = 5,
    prompt = prompt
  })
  local data = {"floating buf", "line1", "line2", "line3", "line4", "line5"}
  for i = 1, 10, 1 do
    vim.api.nvim_buf_set_lines(b, i, -1, false, {data[i]})
  end
  if prompt == true then
    vim.cmd("startinsert!")
  end
end

local function test2(prompt)
  local b, w, c = floating_buf({
    win_width = 30,
    win_height = 8,
    x = 25,
    y = 25,
    prompt = prompt
  })
  local data = {"floating buf", "linea", "lineb", "linec", "lined", "linee"}
  for i = 1, 10, 1 do
    vim.api.nvim_buf_set_lines(b, i, -1, false, {data[i]})
  end
  if prompt == true then
    vim.cmd("startinsert!")
  end
end

-- test(true)
-- test2(false)
-- test_term(true)
-- floating_term({cmd = 'lazygit', border = 'single'})

return {floating_buf = floating_buf, floating_term = floating_term}
