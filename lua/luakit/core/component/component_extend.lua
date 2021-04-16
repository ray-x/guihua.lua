--[[--组件扩展
赋予类绑定解绑组件的能力
@module ComponentExtend
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:20
]]
local ComponentFactory = require("core.component.component_factory")

local component_extend = function ( Class )

    function Class:has_component( ComponentClass )
        local component_name = tostring(ComponentClass)
        return self._component_objects and self._component_objects[component_name]
    end

    function Class:get_component( ComponentClass )
        if not self._component_objects then return end
        local component_name = tostring(ComponentClass)
        return self._component_objects[component_name]
    end

    function Class:bind_component( ComponentClass )
        assert(ComponentClass, "required component class")
        local component_name = tostring(ComponentClass);
        if not self._component_objects then self._component_objects = {} end
        if self._component_objects[component_name] then return end

        local component = ComponentFactory.create_component(ComponentClass);
        for i,DependComponentClass in ipairs(component.depends) do
            
            self:bind_component(DependComponentClass)

            local depend_component_name = tostring(DependComponentClass)
            if not self._component_depends then self._component_depends = {} end
            if not self._component_depends[depend_component_name] then
                self._component_depends[depend_component_name] = {}
            end
            
            table.insert(self._component_depends[depend_component_name], component_name)
        end

        component.object = self
        component:bind(self)
        self._component_objects[component_name] = component
        return component
    end

    function Class:unbind_component( ComponentClass )
        local component_name = tostring(ComponentClass);
        assert(self._component_objects and self._component_objects[component_name],
            string.format("component %s not binding", component_name))
        assert(not self._component_depends or not self._component_depends[component_name],
            string.format("component %s depends by other binding", component_name))

        local component = self._component_objects[component_name]
        for i,DependComponentClass in ipairs(component.depends) do
            local depend_component_name = tostring(DependComponentClass)
            for i,name in ipairs(self._component_depends[depend_component_name]) do
                if name == component_name then
                    table.remove(self._component_depends[depend_component_name], i)
                    if #self._component_depends[depend_component_name] == 0 then
                        self._component_depends[depend_component_name] = nil
                    end
                    break
                end
            end
        end

        component:unbind(self)
        self._component_objects[component_name] = nil
        component.object = nil
        delete(component)
    end

    function Class:unbind_all_component(  )
        if not self._component_objects then return end
        for component_name,component in pairs(self._component_objects) do
            component:unbind(self)
            component.object = nil
            delete(component)
        end
        self._component_objects = {}
        self._component_depends = {}
    end

    function Class:bind_method( component, method_name, method, deprecate_origin_method, call_origin_method_last )
        
        if not self._bind_methods then
            self._bind_methods = {}
        end

        if not self._bind_methods[method_name] then
            self._bind_methods[method_name] = {}
        end

        -- 根据优先级确定绑定
        local index
        local component_priority = component.priority or 1
        for i,c in ipairs(self._bind_methods[method_name]) do
            local priority = c[1].priority or 1
            if component_priority > priority then
                index = i
                break
            end 
        end

        local chain = { component }

        local new_method

        if index then
            chain[2] = self._bind_methods[method_name][index][2]
        else
            chain[2] = self[method_name]
        end
        
        if deprecate_origin_method then
            new_method = method
        elseif call_origin_method_last then
            new_method = function ( ... )
                if chain[2] then
                    method(...)
                    return chain[2](...)
                else
                    return method(...)
                end
            end
        else
            new_method = function ( ... )
                local func = chain[2]
                if func then
                    local ret = func(...)
                    if ret then
                        local args = {...}
                        args[#args + 1] = ret
                        return method(unpack(args))
                    else
                        return method(...)
                    end
                else
                    return method(...)
                end
            end
        end

        if index then
            self._bind_methods[method_name][index][2] = new_method
            table.insert(self._bind_methods[method_name], index, chain)
        else
            self[method_name] = new_method
            table.insert(self._bind_methods[method_name], chain)
        end

        chain[3] = new_method
    end

    function Class:unbind_method( component, method_name )
        if not self._bind_methods or not self._bind_methods[method_name] then
            return
        end
        local methods = self._bind_methods[method_name]
        local count = #methods
        for i = count, 1, -1 do
            local chain = methods[i]
            if chain[1] == component then
                if i < count then
                    methods[i + 1][2] = chain[2]
                elseif count > 1 then
                    self[method_name] = methods[i - 1][3]
                elseif count == 1 then
                    self[method_name] = chain[2]
                    self._bind_methods[method_name] = nil
                end
                table.remove(methods, i)
                break;
            end
        end
    end

end

return component_extend