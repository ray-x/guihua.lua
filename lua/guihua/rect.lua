require('luakit.core')
local log = require "luakit.utils.log".log
local rect = class()
rect._class_name = "Rect"
function rect:ctor(...)
  local cfg = select(1, ...)
  self.rect = cfg.rect or {}
  self.rect.pos_x = self.rect.pos_x or 10
  self.rect.pos_y = self.rect.pos_y or 10
  self.rect.height = self.rect.height or 10
  self.rect.width = self.rect.width or 40

end
function rect:dtor(...)
end
return rect
