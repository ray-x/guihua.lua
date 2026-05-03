local class = require('middleclass')
local ViewController = class('ViewController')
local trace = require('guihua.log').trace

function ViewController:initialize(delegate, ...)
  self.m_delegate = delegate
  local opts = select(1, ...) or {}
  self.display_data = opts.data or {}
  self.session = opts.session or (delegate and delegate.session)
  trace('view ctrl')
end

function ViewController:get_ui()
  return self.m_delegate
end

function ViewController:on_draw(data)
  local ui = self:get_ui()
  if ui then
    ui:on_draw(data)
  end
end

return ViewController
