local class = require "middleclass"
local ListViewCtrl = require "guihua.listviewctrl"
local View = require "guihua.view"
local log = require"guihua.log".info
local trace = require"guihua.log".trace

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
  trace(debug.traceback())

  if win and vim.api.nvim_win_is_valid(win) then
    ListView.close()
  end

  log("listview ctor ") -- , self)
  local opts = select(1, ...) or {}

  vim.cmd([[hi GHListDark guifg=#e0d8f4 guibg=#272755]])
  opts.bg = opts.bg or "GHListDark"

  opts.enter = true
  View.initialize(self, opts)
  self:bind_ctrl(opts)
  -- ListView.static.active_view = self
  log("listview created", self.win) -- , self)
  local ft = "guihua"
  vim.api.nvim_buf_set_option(self.buf, "ft", ft)
  vim.api.nvim_win_set_option(self.win, "wrap", false)

  if not opts.prompt or opts.enter then
    vim.cmd("normal! 1gg")
    vim.fn.setpos(".", {self.win, 1, 1, 0})
  else
    vim.cmd("normal! zvzb")
  end

  ListView.static.Winnr = self.win
  ListView.static.Bufnr = self.buf
  vim.api.nvim_buf_set_keymap(self.buf, "n", "<C-e>", "<cmd> lua ListView.close() <CR>", {})
  vim.api.nvim_buf_set_keymap(self.buf, "i", "<C-e>", "<cmd> lua ListView.close() <CR>", {})
  -- vim.fn.setpos('.', {self.win, i, 1, 0})
end

function ListView:bind_ctrl(opts)
  if self.ctrl and self.ctrl.class_name == "ListViewCtrl" then
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
  ListViewCtrl._viewctlobject = nil
end

-- Next time the ListView object will be re-create
-- But I still feel that it is better to de-reference so it will demalloc early
function ListView.close()
  log("closing listview", ListView.name)
  local buf = ListView.Bufnr
  local win = ListView.Winnr
  if buf == nil and win == nil then
    return
  end
  if buf and vim.api.nvim_buf_is_valid(buf) and win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    -- ListView.on_close() -- parent view closer
    ListView.static.Bufnr = nil
    ListView.static.Winnr = nil
  end
  if ListView.ActiveView and ListView.ActiveView.win then
    ListView.ActiveView.on_close()
    ListView.static.Bufnr = nil
    ListView.static.Winnr = nil
  end

  ListView:unbind_ctrl()
  if ListView.ActiveView ~= nil then
    ListView.ActiveView.data = nil
  end
  ListView.data = nil
  View.data = nil
  vim.cmd([[stopinsert]])
  -- ListView = class("ListView", View)
  log("listview destroied", win)
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

  vim.schedule(function()
    -- log("setpos", self.buf)
    if not vim.api.nvim_buf_is_valid(self.buf) then
      return
    end
    vim.api.nvim_buf_clear_namespace(self.buf, selhighlight, 0, -1)
    local ListviewHl = self.hl_group or "PmenuSel"
    vim.api
        .nvim_buf_add_highlight(self.buf, selhighlight, ListviewHl, self.selected_line - 1, 0, -1)
  end)
end

return ListView
