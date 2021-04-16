--[[--组件基类  
注意：所有组件必须继承该类
@module ComponentBase
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:20
]]
local ComponentBase = class()

ComponentBase._class_name = "ComponentBase"

ComponentBase.exportInterface = {

}

--[[--
        组件依赖列表 
    ]]
ComponentBase.depends = {}

--[[--
    组件优先级 
]]
ComponentBase.priority = 1;

function ComponentBase:ctor( componentName )
    --[[--
        组件名称
    ]]
    self.name = componentName or "Component";
end

--[[--
    组件绑定对象
    @tparam Object object 需要绑定组件的“宿主”
    
]]
function ComponentBase:bind( object )
    for i,v in ipairs(self.exportInterface) do
        object:bind_method(self, v[1],   handler(self, self[v[1]]), v[2], v[3]);
    end 
end

--[[--
    组件解绑对象
    @tparam Object object 需要解除绑定的“宿主”
    
]]
function ComponentBase:unbind( object )
    for i,v in ipairs(self.exportInterface) do
        object:unbind_method(self, v[1]);
    end 
end

--[[--
    重置组件，按优先级调用,需要注意的是reset是配合priority使用priority越高组件越先执行
    @tparam Object object 需要解除绑定的“宿主”

]]
function ComponentBase:reset( object )
end

return ComponentBase