local class = require "middleclass"
local View = require "guihua.view"
local log = require"guihua.log".info
local util = require "guihua.util"
local verbose = require"guihua.log".debug

local TextViewCtrl = require "guihua.textviewctrl"
-- local TextView = {}

if TextView == nil then TextView = class("TextView", View) end
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
opts= {uri = l.uri, width = width, height=height, lnum = l.lnum, col = l.col, offset_x = 0, offset_y = offset_y}

--]]
function TextView:initialize(...)
  verbose(debug.traceback())
  log("ctor TextView start:")

  local opts = select(1, ...) or {}

  vim.cmd([[hi GHTextViewDark guifg=#e0d8f4 guibg=#332e64]])

  opts.bg = opts.bg or "GHTextViewDark"
  if TextView.ActiveTextView ~= nil then -- seems not working..
    verbose("active view ", TextView.ActiveTextView.buf,
            TextView.ActiveTextView.win)
    if TextView.ActiveTextView.win ~= nil and
        vim.api.nvim_win_is_valid(TextView.ActiveTextView.win) and
        vim.api.nvim_buf_is_valid(self.buf) then
      if TextView.hl_id ~= nil then
        vim.api.nvim_buf_clear_namespace(0, TextView.hl_id, 0, -1)
        TextView.static.hl_id = nil
        TextView.static.hl_line = nil
      end
      verbose("active view already existed")
      self = TextView.ActiveTextView
      -- TODO: delegate, on_load
      TextView.ActiveTextView:on_draw(opts.data)
      if opts.hl_line ~= nil then
        if opts.hl_line == 0 then opts.hl_line = 1 end
        log("hl buf", self.buf, "l ", opts.hl_line)
        TextView.static.hl_id = vim.api.nvim_buf_add_highlight(self.buf, -1,
                                                               "Search",
                                                               opts.hl_line - 1,
                                                               0, -1)
        TextView.static.hl_line = opts.hl_line
      end
      return TextView.ActiveTextView
    end
    -- TextView.ActiveTextView.win = nil
    -- TextView.ActiveTextView.buf = nil
    -- TextView.static.ActiveTextView = nil
  end
  opts.enter = opts.enter or false
  View.initialize(self, opts)

  verbose("textview after super", self)
  self.cursor_pos = {1, 1}
  if opts.syntax then
    self.syntax = opts.syntax
    log("hl ", self.buf, opts.syntax)
    require"guihua.util".highlighter(self.buf, opts.syntax, opts.ts)
    -- vim.api.nvim_buf_set_option(self.buf, "syntax", opts.syntax)
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

  if opts.hl_line ~= nil then
    if opts.hl_line == 0 then opts.hl_line = 1 end
    log("buf", self.buf, "l: ", opts.hl_line)
    TextView.static.hl_id = vim.api.nvim_buf_add_highlight(self.buf, -1,
                                                           "Search",
                                                           opts.hl_line - 1, 0,
                                                           -1)
    TextView.static.hl_line = opts.hl_line
  end

  -- controller and data
  if opts.edit then -- well this is a feature flag for early phase dev
    log("ctor TextView: ctrl") -- , View.ActiveView)--, self)
    self:bind_ctrl(opts)

    local content = self.ctrl.on_load(opts)
    self:on_draw(content)
  end

  log("ctor TextView: end", self) -- , View.ActiveView)--, self)
end

function TextView.Active()
  if TextView.ActiveTextView ~= nil then return true end
  return false
end

function TextView:on_draw(opts)
  local data = {}
  if not self or not vim.api.nvim_buf_is_valid(self.buf) then
    log("buf id invalid", self)
    return
  end
  if opts.uri ~= nil then
    data = self.ctrl.on_load(opts)
  else
    data = opts
  end

  local content = {}
  if type(data) == "string" then
    content = {data}
  elseif type(data) == "table" then
    content = data
  else
    return
  end

  verbose("draw", data, self.buf, self.win)
  if #data < 1 then
    log("nothing to redraw")
    return
  end
  local start = 0
  if self.header ~= nil then start = 1 end
  local end_at = -1
  local bufnr = self.buf or TextView.ActiveTextView.buf
  if bufnr == 0 then print("Error: plugin failure, please submit a issue") end
  -- log("bufnr", bufnr)

  vim.api.nvim_buf_set_option(bufnr, "readonly", false)
  -- vim.api.nvim_buf_set_lines(self.buf, start, end_at, true, content)
  vim.api.nvim_buf_set_lines(bufnr, start, end_at, true, content)
  vim.api.nvim_buf_set_option(bufnr, "readonly", true)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  if TextView.hl_line ~= nil then
    TextView.static.hl_id = vim.api.nvim_buf_add_highlight(self.buf, -1,
                                                           "Search",
                                                           TextView.hl_line - 1,
                                                           0, -1)
  end
  -- vim.fn.setpos(".", {0, 1, 1, 0})
end

function TextView.on_close()
  verbose(debug.traceback())
  if TextView.ActiveTextView == nil then
    log("view onclose nil")
    return
  end
  log("TextView onclose ", TextView.ActiveTextView.win)
  TextView.ActiveTextView:close()
  TextView.static.ActiveView = nil
end

function TextView:bind_ctrl(opts)
  if self.ctrl and self.ctrl.class_name == "TextViewCtrl" then
    return false
  else
    self.ctrl = TextViewCtrl:new(self, opts)
    verbose("textview ctrl", self.ctrl)
    return true
  end
end

return TextView
