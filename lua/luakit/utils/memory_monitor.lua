--[[--
lua内存泄漏检测工具
@module MemoryMonitor
@author iwiniwin

Date   2019-11-15 19:20:39
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:42:34
]]
--[[
    lua内存泄漏检测工具
    原理：弱表中的引用是弱引用，不会导致对象的引用计数发生变化
    即如果一个对象只有弱引用指向它，那么gc会自动回收该对象的内存
]]
--[[
    Lua运行了一个垃圾收集器来收集所有死对象来完成自动内存管理的工作
    Lua实现了一个增量标记-扫描收集器。它使用间歇率和步进倍率这两个数字来控制垃圾收集循环，都是以百分数为单位（例如：值100在内部表示1）

    间歇率控制收集器在开启新的循环前要等待多久，增大这个值将减少收集器的积极性。当这个值比100小的时候，收集器在开始新的循环前不会有等待，
    设置这个值为200就会让收集器等到总内存使用量达到之前的两倍时才开始新的循环

    步进倍率控制着收集器运行速度相对于内存分配速度的倍率，增大这个值不仅会让收集器更加积极，还会增加每个增量步骤的长度。不要把这个值设置
    的小于100，那样的话收集器就工作的太慢了以至于永远都干不完一个循环。默认值是200，表示收集器以内存分配的两倍速工作

    collectgarbage("collect") :  做一次完整的垃圾收集循环
    collectgarbage("count") : 以k字节数为单位返回Lua使用的总内存数，这个值有小数部分，所以只需要乘上1024就能得到Lua使用的准确字节数
    collectgarbage("restart") : 重启垃圾收集器的自动运行
    collectgarbage("setpause") : 将arg设为收集器的间歇率，并返回间歇率的前一个值
    collectgarbage("setstepmul") : 将arg设为收集器的步进倍率，并返回步进倍率的前一个值
    collectgarbage("step") : 单步运行垃圾收集器，步长大小由arg控制，传入0时，收集器步进一步，传入非0值，收集器收集相当于Lua分配这么多（）内存的工作。如果垃圾收集器结束一个循环将返回true
    collectgarbage("stop") : 停止垃圾收集器的运行。在调用重启前，收集器只会因显示的调用运行
]]

-- 监控间隔配置（单位：秒）
local MonitorConfig = {
    -- 内存泄漏监控间隔
    memLeakInterval = 1,
}

local MemoryMonitor = {}

function MemoryMonitor:ctor( ... )
    -- 内存泄漏弱引用表
    self.__memLeakTable = {}
    -- mode字段可以取 k, v, kv 分别表示table中的 key, value，是弱引用的， kv就是二者的组合
    -- 对于一个table，任何情况下，只要它的key或者value中的一个被gc，那么这个key-value pair就从表中移除了
    setmetatable(self.__memLeakTable, {__mode = "kv"})
    -- 内存泄漏监控器
    self.__memLeakMonitor = nil

    self:start()
end

-- 开始检测
function MemoryMonitor:start( ... )
    self.__memLeakMonitor = self:__mem_leak_monitoring()
end


--[[
把一个表或者对象添加到内存检测工具中，如果该表或者对象不存在外部引用，则说明释放干净
否则内存泄漏工具会输出日志
@table t 观察的对象 表
@string tName 表的别名

@usage 
local memoryMonitor = new(MemoryMonitor)
memoryMonitor:add_to_leak_monitor(self, "xx模块")
]]
function MemoryMonitor:add_to_leak_monitor( t, tName )
    if not self.__memLeakMonitor then
        return
    end

    assert("string" == type(tName), "invalid params")

    -- 必须以名字+地址的方式作为键值
    -- 内存泄漏经常是一句代码多次分配出内存而忘了回收，因此tName经常是相同的
    local name = string.format("%s@%s", tName, tostring(t))
    if nil == self.__memLeakTable[name] then
        self.__memLeakTable[name] = t
    end
end

-- 更新弱表信息
function MemoryMonitor:update( dt )
    dt = dt or 10
    if self.__memLeakMonitor then
        self.__memLeakMonitor(dt)
    end
end



function MemoryMonitor:__mem_leak_monitoring( ... )
    local monitorTime = MonitorConfig.memLeakInterval
    local interval = MonitorConfig.memLeakInterval
    local str = nil
    return function( dt )
        interval = interval + dt
        if interval >= monitorTime then
            interval = interval - monitorTime

            -- 强制调用gc
            collectgarbage("collect")
            collectgarbage("collect")
            collectgarbage("collect")
            collectgarbage("collect")

            local flag = false
            -- 打印当前内存泄漏监控表中依然存在（没有被释放）的对象信息
            str = "存在以下内存泄漏："
            for k,v in pairs(self.__memLeakTable) do
                str = str .. string.format("    \n%s = %s", tostring(k), tostring(v))
                flag = true
            end
            str = str .. "\n请仔细检查代码！！！"
            if flag then
                print(str)
            end
        end
    end
end

return MemoryMonitor

--[[
-- TODO 待研究情况
print("--------------分隔符--------------")
a = {}

local b = {xxx = "xxx"}

a.b = b

memoryMonitor:add_to_leak_monitor(b, "b")

a = nil
-- 此时b仍然没有被释放掉
-- 可能是由于b是local变量，不仅有a在引用b，可能lua的堆栈也在对其引用，导致无法被释放。
-- 可以对比上面在函数里定义b的区别
memoryMonitor:update()
--]]
