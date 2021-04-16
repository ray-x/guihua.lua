--[[--组件工厂类  
@module ComponentFactory
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:20
]]
local ComponentBase = require("core.component.component_base")

local ComponentFactory = {}

function ComponentFactory.create_component( component )
    assert(component ~= nil, "invalid component : " .. tostring(component))
    if typeof(component, ComponentBase) then
        return new(component);
    elseif type(component) == "table" and component.require and component.path then
        return new(component.require(component.path))
    else
        error("invalid component : " .. tostring(component))
    end
end

return ComponentFactory
