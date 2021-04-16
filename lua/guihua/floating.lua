local api = vim.api
local location = require "guihua.location"

local log = require "luakit.utils.log".log
-- Create a simple floating terminal.
local function floating_buf(win_width, win_height, x, y, loc, prompt, ft)
  prompt = prompt or false
  -- win_w, win_h, x, y should be passwd in from view
  loc = loc or location.center
  local row, col = loc(win_height, win_width, x, y)
  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    bufpos = {4, 0},
    row = row,
    col = col
  }
  log('floating', opts)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  -- api.nvim_buf_set_option(buf, 'buftype', 'guihua_input')
  vim.cmd('setlocal nobuflisted')
  if prompt then
    vim.fn.prompt_setprompt(buf, " ")
    api.nvim_buf_set_option(buf, "buftype", "prompt")
  else
    api.nvim_buf_set_option(buf, "readonly", true)
    if ft ~= nil then
      api.nvim_buf_set_option(buf, "filetype", ft)
    end
  end
  local win = api.nvim_open_win(buf, true, opts)
  log("creating win", win)
  return buf, win, function()
    log('floatwin closing ', win)
    vim.api.nvim_win_close(win, true)
    win=nil
  end
end

-- Create a simple floating terminal.
local function floating_term(cmd, callback, win_width, win_height, x, y)
  local current_window = vim.api.nvim_get_current_win()
  x = x or 5
  y = y or 5
  local buf, win, closer = floating_buf(win_width, win_height, x, y, nil, false, "Floaterm")
  if cmd == "" or cmd == nil then
    cmd = vim.api.nvim_get_option("shell")
  end
  api.nvim_command("setlocal nobuflisted")
  api.nvim_command("startinsert!")
  vim.fn.termopen(
    cmd,
    {
      on_exit = function(_, _, _)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        vim.api.nvim_set_current_win(current_window)
        closer()
        if callback then
          callback(lines)
        end
      end
    }
  )
  return buf, win, closer
end

local function test(prompt)
  local b, w, c = floating_buf(30, 6, 5, 5, nil, prompt)
  local data =  {"floating buf", "line1", "line2",  "line3", "line4", "line5"}
  for i = 1, 10, 1 do
    vim.api.nvim_buf_set_lines(b, i, -1, false, {data[i]})
  end
  if prompt == true then
    vim.cmd("startinsert!")
  end
end

--test(true)

return {floating_buf = floating_buf, floating_term = floating_term}
