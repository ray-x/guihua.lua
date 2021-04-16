require'luakit.core'
local vctl = require "guihua.textviewctrl"
local view = require "guihua.view"

local textview = class(view)
textview._class_name = "TextView"


--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  background
  prompt
}

--]]
function textview:ctor(...)
  log("textview ctor")
end


function textview:bind_ctrl()
  if self.ctrl then
    return false
  else
    self.ctrl = new(vctl, self)
    return true
  end
end


-- 更新视图
function textview:on_draw(data)
  self:set_hl()
  local content = {}
  if type(data) == "string" then content = {data}
  else
    content = data
  end
  vim.api.nvim_buf_set_lines(self.buf, 0, -2, false, content)

  -- api.nvim_win_set_option(self.win, 'winhl', 'Normal:'..self.background)
  -- if data == nil then return end
  -- if data.title then
  --   dump("update title", data.header)
  --   vim.api.nvim_buf_set_lines(self.buf, 0, -2, false, data.header)
  -- end
  -- if data.content then
  -- -- 更新content
  -- end
  -- if data.footer then
  -- -- 更新other
  -- end
end


function textview:dtor(...)
  dump("unload textView")
  self:unbind_ctrl()
end

return textview
