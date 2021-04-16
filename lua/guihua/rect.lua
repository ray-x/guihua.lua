local class = require "middleclass"
local log = require "guihua.log".info
local Rect = class("Rect")
function Rect:initialize(...)
  local cfg = select(1, ...)

  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")

  if cfg ~= nil then
    self.rect = cfg.rect or {}
  end
  self.rect.height = self.rect.height or #cfg.data or 6
  if self.rect.height > math.floor(height*1/2) then
    self.rect.height = math.floor(height*1/2)
  end
  self.rect.pos_x = self.rect.pos_x or 0
  self.rect.pos_y = self.rect.pos_y or 1
  self.rect.width = self.rect.width or math.floor(width*4/5)
end

return Rect