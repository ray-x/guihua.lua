local class = require('middleclass')
-- local log = require"guihua.log".info
local Rect = class('Rect')
function Rect:initialize(...)
  local cfg = select(1, ...)

  local width = vim.api.nvim_get_option('columns')
  local height = vim.api.nvim_get_option('lines')

  if cfg ~= nil then
    self.rect = cfg.rect
  else
    cfg = { data = {} }
  end

  self.rect = self.rect or {}

  if self.rect.height and self.rect.height < 1 then
    self.rect.height = math.floor(height * self.rect.height)
  end

  if self.rect.width and self.rect.width < 1 then
    self.rect.wdith = math.floor(width * self.rect.width)
  end

  if cfg == nil then
    return
  end
  self.rect.height = self.rect.height or #cfg.data or 8
  if cfg.rigid then
    if self.rect.height > math.floor(height * 1 / 2) then
      self.rect.height = math.floor(height * 1 / 2)
    end
  end
  self.rect.pos_x = self.rect.pos_x or 0
  self.rect.pos_y = self.rect.pos_y or 1
  self.rect.width = self.rect.width or math.floor(width * 4 / 5)
end

return Rect
