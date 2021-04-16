--[[--常用函数集合
@module Function
@author iwiniwin

Date   2020-02-27 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:04
]]
local M = {}

function M.handler( obj, method )
    return function ( ... )
        if obj and method then
            method(obj, ...)
        end
    end
end

return M