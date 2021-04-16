require "luakit.core"
local vctl = require "guihua.listviewctrl"
local view = require "guihua.view"
log = require'luakit.utils.log'.log

if listview == nil then
  listview = class(view)
  listview._class_name = "ListView"
end

--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  background
  prompt
}

--]]

function listview:ctor(...)
  log("listview ctor ") --, self)
  local opts = select(1, ...) or {}
  self:bind_ctrl(opts)
  listview.active_view = self
  -- vim.fn.setpos('.', {self.win, i, 1, 0})
end

function listview:bind_ctrl(data)
  if self.ctrl then
    return false
  else
    self.ctrl = new(vctl, self, data)
    return true
  end
end

function listview:unbind_ctrl(...)
  if self.ctrl then
    delete(self.ctrl)
    self.ctrl = nil
  end
end

function listview:set_pos(i)
  self.selected_line = i

  local selhighlight = vim.api.nvim_create_namespace("selhighlight")
  vim.schedule(
    function()
      vim.api.nvim_buf_clear_namespace(self.buf, selhighlight, 0, -1)
      if #vim.api.nvim_buf_get_lines(self.buf, 0, -1, false) < 2 then
        return
      end
      local ListviewHl = self.opts.hl_group or "PmenuSel"
      vim.api.nvim_buf_add_highlight(self.buf, selhighlight, ListviewHl, i - 1, 0, -1)
    end
  )
end

function listview:dtor(...)
  log("unload listview")
  self:unbind_ctrl()
  self.super:dtor(...)
  self.active_view = nil
end

function listview:on_close()

  log(" listview on close") --, self)
  --self.m_delegate:on_close()
  listview.active_view:buf_closer()
  listview.active_view:dtor()
end

local function test()
  -- vim.cmd("packadd guihua.lua")
  package.loaded["guihua"] = nil
  package.loaded["guihua.view"] = nil
  package.loaded["guihua.viewctrl"] = nil
  package.loaded["guihua.listview"] = nil
  package.loaded["guihua.listviewctrl"] = nil
  --package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd("packadd guihua.lua")
  local data = {"ListView: test line should show", "view line2", "view line3", "view line4"}
  vim.g.debug_output = true
  win = new(listview, {loc = "up_left", prompt = true, rect={height=5}, data=data})
  log("test", win)
  vim.cmd('startinsert!')
  -- win:on_draw({})
  win:set_pos(1)
end

-- test()
return listview
