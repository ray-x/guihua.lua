local class = require "middleclass"
local ListViewCtrl = require "guihua.listviewctrl"
local View = require "guihua.view"
local log = require "guihua.log".info
local verbose = require "guihua.log".trace

if ListView == nil then
  ListView = class("ListView", View)
end

--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  background
  prompt
}

--]]

function ListView:initialize(...)
  verbose(debug.traceback())
  log("listview ctor ") --, self)
  local opts = select(1, ...) or {}

  vim.cmd([[hi GHListDark guifg=#e0d8f4 guibg=#372745]])
  opts.bg = opts.bg or "GHListDark"

  opts.enter = true
  View.initialize(self, opts)
  self:bind_ctrl(opts)
  --ListView.static.active_view = self
  log("listview created", self.win) --, self)

  vim.api.nvim_buf_set_option(self.buf, "ft", "guihua")
  vim.api.nvim_win_set_option(self.win, "wrap", false)

  vim.cmd("normal! zvzb")
  -- vim.fn.setpos('.', {self.win, i, 1, 0})
end

function ListView:bind_ctrl(opts)
  if self.ctrl and self.ctrl.class_name == "ListView" then
    log("already binded", self.ctrl)
    return false
  else
    self.ctrl = ListViewCtrl:new(self, opts)
    return true
  end
end

function ListView:unbind_ctrl(...)
  if self.ctrl then
    self.ctrl = nil
  end
end

function ListView:set_pos(i)
  if not vim.api.nvim_buf_is_valid(self.buf) then
    return
  end
  if #vim.api.nvim_buf_get_lines(self.buf, 0, -1, false) < 2 then
    return
  end
  self.selected_line = i
  local selhighlight = vim.api.nvim_create_namespace("selhighlight")

  vim.schedule(
    function()
      -- log("setpos", self.buf)
      if not vim.api.nvim_buf_is_valid(self.buf) then return end
      vim.api.nvim_buf_clear_namespace(self.buf, selhighlight, 0, -1)
      local ListviewHl = self.hl_group or "PmenuSel"
      vim.api.nvim_buf_add_highlight(self.buf, selhighlight, ListviewHl, self.selected_line - 1, 0, -1)
    end
  )
end


return ListView
