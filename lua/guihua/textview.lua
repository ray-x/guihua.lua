local class = require "middleclass"
local View = require "guihua.view"
local log = require "guihua.log".info
local util = require "guihua.util"
local verbose = require "guihua.log".debug
-- local TextView = {}
if TextView == nil then
  TextView = class("TextView", View)
end
-- Note, Support only one active view
-- ActiveView = nil
--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  loc='center|up_left|center_right'
  background
  prompt
}

--]]
function TextView:initialize(...)
  verbose(debug.traceback())
  log("ctor TextView start:")

  local opts = select(1, ...) or {}

  vim.cmd([[hi GHTextViewDark guifg=#e0d8f4 guibg=#3e2e6f]])

  opts.bg = opts.bg or "GHTextViewDark"
  if TextView.ActiveTextView ~= nil then -- seems not working..
    verbose("active view ", TextView.ActiveTextView.buf, TextView.ActiveTextView.win)
    if
      TextView.ActiveTextView.win ~= nil and vim.api.nvim_win_is_valid(TextView.ActiveTextView.win) and
        vim.api.nvim_buf_is_valid(self.buf)
     then
      verbose("active view already existed")
      self = TextView.ActiveTextView
      TextView.ActiveTextView:on_draw(opts.data)
      return TextView.ActiveTextView
    end
    TextView.ActiveTextView.win = nil
    TextView.ActiveTextView.buf = nil
    TextView.static.ActiveTextView = nil
  end
  opts.enter = opts.enter or false
  verbose("TxView", opts)
  View.initialize(self, opts)

  self.cursor_pos = {1, 1}
  if opts.syntax then
    vim.api.nvim_buf_set_option(self.buf, "syntax", opts.syntax)
    self.syntax = opts.syntax
  end
  TextView.static.ActiveTextView = self
  if not opts.enter then
    -- currsor move will close textview
    util.close_view_autocmd({"CursorMoved", "CursorMovedI"}, self.win)
  else
    -- for definition preview <c-e> close
    util.close_view_event("n", "<C-e>", self.win, self.buf, opts.enter)
    util.close_view_event("i", "<C-e>", self.win, self.buf, opts.enter)
  end
  log("ctor TextView: end", self.win) --, View.ActiveView)--, self)
end

function TextView.Active()
  if TextView.ActiveTextView ~= nil then
    return true
  end
  return false
end

function TextView:on_draw(data)
  if not vim.api.nvim_buf_is_valid(self.buf) then
    log("buf id invalid", self.buf)
    return
  end

  local content = {}
  if type(data) == "string" then
    content = {data}
  else
    content = data
  end

  verbose("draw", data, self.buf, self.win)
  local start = 0
  if self.header ~= nil then
    start = 1
  end
  local end_at = -1
  local bufnr = self.buf or TextView.ActiveTextView.buf
  if bufnr == 0 then
    print("Error: plugin failure, please submit a issue")
  end
  --log("bufnr", bufnr)

  vim.api.nvim_buf_set_option(bufnr, "readonly", false)
  -- vim.api.nvim_buf_set_lines(self.buf, start, end_at, true, content)
  vim.api.nvim_buf_set_lines(bufnr, start, end_at, true, content)
  vim.api.nvim_buf_set_option(bufnr, "readonly", true)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

  -- vim.fn.setpos(".", {0, 1, 1, 0})
end

function TextView:on_close()
  verbose(debug.traceback())
  if TextView.ActiveTextView == nil then
    log("view onclose nil")
    return
  end
  log("view onclose ", TextView.ActiveTextView.win)
  TextView.ActiveTextView:close()
  TextView.static.ActiveView = self
end

return TextView
