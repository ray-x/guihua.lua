local api = vim.api
local location = require "guihua.location"

local log = require "guihua.log".info
-- Create a simple floating terminal.
local function floating_buf(opts) --win_width, win_height, x, y, loc, prompt, enter, ft)
  local prompt = opts.prompt or false
  local enter = opts.enter or false
  local x = opts.x or 0
  local y = opts.y or 0
  log("loc", opts.loc, opts.win_width, opts.win_height, x, y, enter, opts.ft)
  -- win_w, win_h, x, y should be passwd in from view
  loc = opts.loc or location.center
  local row, col = loc(opts.win_height, opts.win_width)
  local win_opts = {
    style = "minimal",
    relative = opts.relative or "editor",
    width = opts.win_width or 80,
    height = opts.win_height or 5,
    bufpos = {0, 0}
  }
  if win_opts.relative == "editor" then
    win_opts.row = row + y
    win_opts.col = col + x
  end
  log("floating", win_opts, opts)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  -- api.nvim_buf_set_option(buf, 'buftype', 'guihua_input')
  vim.cmd("setlocal nobuflisted")
  if prompt then
    vim.fn.prompt_setprompt(buf, " ")
    api.nvim_buf_set_option(buf, "buftype", "prompt")
  else
    api.nvim_buf_set_option(buf, "readonly", true)
    if opts.ft ~= nil then
      api.nvim_buf_set_option(buf, "syntax", opts.ft)
    end
  end
  local win = api.nvim_open_win(buf, enter, win_opts)
  log("creating win", win)
  return buf, win, function()
    log("floatwin closing ", win)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      win = nil
    end
  end
end

-- Create a simple floating terminal.
local function floating_term(opts) --cmd, callback, win_width, win_height, x, y)
  local current_window = vim.api.nvim_get_current_win()
  local enter = opts.enter or false
  local x = opts.x or 0
  local y = opts.y or 0

  if cmd == "" or cmd == nil then
    cmd = vim.api.nvim_get_option("shell")
  end

  -- get dimensions
  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  -- calculate our floating window size
  local win_height = opts.win_width or math.ceil(height * 0.88)
  local win_width = opts.win_width or math.ceil(width * 0.88)

  local buf, win, closer =
    floating_buf({win_width = win_width, win_height = win_height, x = x, y = y, enter = false, ft = "Floaterm"})
  api.nvim_command("setlocal nobuflisted")
  api.nvim_command("startinsert!")
  vim.fn.termopen(
    cmd,
    {
      on_exit = function(_, _, _)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        vim.api.nvim_set_current_win(current_window)
        closer()
        -- if callback then
        --   callback(lines)
        -- end
      end
    }
  )
  return buf, win, closer
end

local function test(prompt)
  local b, w, c = floating_buf(30, 6, 5, 5, nil, prompt)
  local data = {"floating buf", "line1", "line2", "line3", "line4", "line5"}
  for i = 1, 10, 1 do
    vim.api.nvim_buf_set_lines(b, i, -1, false, {data[i]})
  end
  if prompt == true then
    vim.cmd("startinsert!")
  end
end

--test(true)

return {floating_buf = floating_buf, floating_term = floating_term}
