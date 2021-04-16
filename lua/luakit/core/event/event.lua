--[[--事件配置，便于统一管理项目中所有使用的事件
@module Event
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-04-01 14:47:14
]]
local Event = {}

local event_id = 1;

Event.get_unique_id = function (  )
    event_id = event_id + 1
    return "event_" .. event_id
end

Event.KeyDown           = Event.get_unique_id()

return Event
