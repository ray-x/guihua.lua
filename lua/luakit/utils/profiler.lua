--[[--
lua性能分析工具
@module profiler
@author iwiniwin

Date   2019-11-15 19:20:39
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:50
]]
--[[
    debug.getinfo(level, arg) : 返回一个包含函数信息的table
    level表示函数调用的层级，表示要输出哪个函数的信息
    arg是一个字符串，其中每个字符代表一组字段，用于指定希望获取那些信息，可以是"n","S","I","u","f","L"中的一个或组合
    n : 表示name（函数名）和namewhat（函数类型，field, upvalue, global）
    S : 表示source（函数所属文件名）, linedefined（函数定义起始行号）, lastlinedefined（函数定义结束行号）, what（函数类型，Lua, C, main）, short_src（函数所属文件名，source的短版本）
    l : 表示currentline（上级函数被调用的行号）
    u : 表示nups（函数的upvalue值的个数）
    f : 表示func（函数本身）
    L : 表示activelines（一个包含行号的table，可理解为该函数运行的代码的行号）
    debug.sethook(hook, mask, count) : 将一个函数作为钩子函数设入。字符串mask以及数字count决定了钩子将在何时调用
    掩码是由下列字符组合成的字符串
    "c" : 每当lua调用一个函数时，调用钩子
    "r" : 每当lua从一个函数内返回时，调用钩子
    "l" : 每当lua进入新的一行时，调用钩子
    当count值大于0的时候，每执行完count数量的指令后就会触发钩子

]]
-- package.path = package.path .. ";..\\?.lua;"
-- require("_load")
local EMPTY_TIME                       = "0.0000"       -- Detect empty time, replace with tag below
local emptyToThis                      = "~"

local timeWidth                        = 7
local relaWidth                        = 6
local callWidth                        = 10

local divider = "";
local formatOutput                     = "";
local formatFunTime                    = "%04.4f"
local formatFunRelative                = "%03.1f"
local formatFunCount                   = "%"..(callWidth-1).."i"
local formatHeader                     = ""
local scale                            = 1;

local function charRepetition(n, character)
    local s   = {}
    character = character or " "
    for _ = 1, n do
        table.insert(s,character)
    end
    return table.concat(s)
end

local Profiler = {}

--[[
创建一个性能分析工具对象
@string variant 性能分析模式 "call" or "time"
@usage
local profiler = new_profiler("call")
profiler:start()
-- do something
profiler:stop()
profiler:dump_report_to_file("profile.txt")
]]
local function new_profiler( variant )
    if Profiler.running then
        print("Profiler already running")
        return
    end

    variant = variant or "time"

    if variant ~= "time" and variant ~= "call" then
        print("Profiler method must be 'time' or 'call'")
        return
    end

    local newprof = {}
    for k,v in pairs(Profiler) do
        newprof[k] = v
    end
    newprof.variant = variant
    return newprof
end

--[[
启动性能分析，核心是利用debug.sethook对函数调用进行钩子
每次只能启动一个
]]
function Profiler:start( ... )
    if Profiler.running then
        return
    end
    Profiler.running = self

    self.caller_cache = {}
    self.callstack = {}

    self.start_time = os.clock()
    if self.variant == "time" then

    elseif self.variant == "call" then 
        -- 因为垃圾回收会导致性能分析下降严重，所以先放缓垃圾回收
        self.setpause = collectgarbage("setpause")
        self.setstepmul = collectgarbage("setstepmul")
        collectgarbage("setpause", 300)
        collectgarbage("setstepmul", 5000)

        self.coroutine_create = coroutine.create
        self.coroutines = {}
        coroutine.create = function(...)
            local co = self.coroutine_create(...)
            table.insert(self.coroutines, co)
            debug.sethook(co,profiler_hook_wrapper_by_call, "cr")
            return co
        end

        debug.sethook(profiler_hook_wrapper_by_call, "cr")
    else
        error("Profiler method must be 'time' or 'call'")
    end
end

--[[
    停止性能分析
]]
function Profiler:stop( ... )
    if Profiler.running ~= self then
        -- 如果没有启动则没有任何效果
        return
    end
    self.end_time = os.clock()

    if self.coroutine_create then
        coroutine.create = self.coroutine_create
        self.coroutine_create = nil
    end
    
    -- 停止性能分析
    debug.sethook(nil)
    if self.variant == "call" then
        -- 还原之前的垃圾回收设置
        collectgarbage("setpause", self.setpause) 
        collectgarbage("setstepmul", self.setstepmul)
    end
    collectgarbage("collect")
    collectgarbage("collect")
    Profiler.running = nil
end

--[[
    钩子函数入口
]]
function profiler_hook_wrapper_by_call( action )
    if Profiler.running == nil then
        debug.sethook(nil)
    end
    Profiler.running:analysis_call_info(action)
end

--[[
    分析函数调用信息
    @string action 函数调用类型 action return tail return
]]
function Profiler:analysis_call_info( action )
    -- 获取当前的调用信息，注意该函数有一定的损耗
    -- 0表示当前函数，即getinfo，1表示上一层调用即analysis_call_info，2表示再上一层，即profiler_hook_wrapper_by_call， 3即客户函数
    local caller_info = debug.getinfo(3, "Slfn")

    if caller_info == nil then
        return
    end

    local last_caller = self.callstack[1]

    if action == "call" then -- 进入函数，标记堆栈
        local this_caller = self:get_func_info_by_cache(caller_info)
        this_caller.parent = last_caller
        this_caller.clock_start = os.clock()
        this_caller.count = this_caller.count + 1
        table.insert(self.callstack, 1, this_caller)
    else
        table.remove(self.callstack, 1) -- 移除顶部堆栈，有可能粗发连续触发return

        if action == "tail return" then
            return
        end

        local this_caller = self.caller_cache[caller_info.func]
        if this_caller == nil then
            return
        end

        -- 计算本次函数调用时长
        this_caller.this_time = os.clock() - this_caller.clock_start 
        -- 该函数累加调用时间
        this_caller.time = this_caller.time + this_caller.this_time  

        -- 更新父类信息
        if this_caller.parent then
            local func = this_caller.func
            -- 更新父类中存储的该子函数的调用次数
            this_caller.parent.children[func] = (this_caller.parent.children[func] or 0) + 1
            -- 更新父类中存储的该子函数的总调用时间
            this_caller.parent.children_time[func] = (this_caller.parent.children_time[func] or 0) + this_caller.this_time
            
            if caller_info.name == nil then
                -- 统计无名函数调用时间
                this_caller.parent.unknow_child_time = this_caller.parent.unknow_child_time + this_caller.this_time
            else
                -- 统计有名函数调用时间
                this_caller.parent.name_child_time = this_caller.parent.name_child_time + this_caller.this_time
            end
        end
    end
end

--[[
    获取缓存里的函数信息
    @info 函数调用信息debug.getinfo返回的数据
]]
function Profiler:get_func_info_by_cache( info )
    local func = info.func
    local ret = self.caller_cache[func]
    if ret == nil then
        ret = {}
        ret.func = func
        ret.count = 0 -- 调用次数
        ret.time = 0 -- 时间
        ret.unknow_child_time = 0 --没有名字的函数的调用时间
        ret.name_child_time = 0 -- 有名字的函数的调用时间
        ret.children = {}
        ret.children_time = {}
        ret.func_info = info
        self.caller_cache[func] = ret
    end
    return ret
end

--格式化成表格样式
function Profiler:format_header(ordering,lines,totalTime)
    local TABL_REPORTS = {};
    local maxFileLen = 0;
    local maxFuncLen = 0;
    for i,func in ipairs(ordering) do
        local record = self.caller_cache[func]
        local reportInfo                         = {
            count  = record.count,
            timer  = record.time,
            src     = record.func_info.short_src,
            name    = record.func_info.name or "unknow",
            linedefined = record.func_info.linedefined,
            what = record.func_info.what,
            source = record.func_info.source;
        }

        reportInfo.src = self:pretty_name(func,true);

        --计算最长的名字
        if string.len(reportInfo.src) > maxFileLen and reportInfo.count > 0  then
            maxFileLen = string.len(reportInfo.src) + 1;
        end

        if string.len(reportInfo.name) > maxFuncLen and reportInfo.count > 0 then
            maxFuncLen = string.len(reportInfo.name) + 1;
        end

        table.insert(TABL_REPORTS,reportInfo);

    end

    if maxFileLen>=99 then --必须如此处理，不然会报错越界
        maxFileLen = 99;
    end

    --     if maxFuncLen>100 then
    --     maxFuncLen = 100;
    -- end


    -- print(maxFileLen,"maxFileLen")
    formatOutput                     = "| %-"..maxFileLen.."s: %-"..maxFuncLen.."s: %-"..timeWidth.."s: %-"..relaWidth.."s: %-"..callWidth.."s|\n"
    -- dump(formatOutput)
    formatHeader                     = string.format(formatOutput, "FILE", "FUNCTION", "TIME", "%", "Call count")
    divider = charRepetition(#formatHeader-1, "-").."\n"


    table.insert(lines, "\n"..divider)
    table.insert(lines, formatHeader)
    table.insert(lines, divider)

    local totalCount = 0;
    for i,reportInfo in ipairs(TABL_REPORTS) do
        if reportInfo.count > 0 and reportInfo.timer <= totalTime then
            local count             = string.format(formatFunCount, reportInfo.count)
            local timer             = string.format(formatFunTime, reportInfo.timer)
            local relTime           = string.format(formatFunRelative, (reportInfo.timer / totalTime) * 100)
            if timer == EMPTY_TIME then
                timer             = emptyToThis
                relTime           = emptyToThis
            end
            local outputLine    = string.format(formatOutput, reportInfo.src,reportInfo.name, timer, relTime, count)
            table.insert(lines, outputLine)

            totalCount = totalCount + reportInfo.count;
        end
    end
    table.insert(lines, divider)
    table.insert(lines, "\n\n")

    table.insert(lines, 2,"Total call count spent in profiled functions: " ..
        totalCount.. "\n\n")
end

--[[--
    生成报表table
    @return     table     报表
    @return     number     性能分析总时间
    @usage
        local new_profiler = import("bos.core.profiler")
        local profiler = new_profiler("call")
        profiler:start();
        -- do something
        profiler:stop();
        profiler:report();
]]
function Profiler:report()
    local lines = {};
    table.insert(lines,[[Lua Profile output created by profiler.lua. author: iwiniwin ]])
    table.insert(lines, "\n\n" )
    local total_time = self.end_time - self.start_time

    table.insert(lines, 1,"Total time spent in profiled functions: " ..
        string.format("%5.3g",total_time) .. "s\n\n")

    -- This is pretty awful.
    local terms = {}
    if self.variant == "time" then

    elseif self.variant == "call" then
        terms.capitalized = "Call"
        terms.single = "call"
        terms.pastverb = "called"
        local ordering = {}

        for func,record in pairs(self.caller_cache) do
            table.insert(ordering, func)
        end

        table.sort( ordering,
            function(a,b) return self.caller_cache[a].time > self.caller_cache[b].time end
        )

        --生成头部表格信息
        self:format_header(ordering,lines,total_time);

        for i,v in ipairs(ordering) do
            local func = ordering[i]
            local record = self.caller_cache[func]
            if record.count and record.count > 0 then --- 标记数量大于0的
                local thisfuncname = " " .. self:pretty_name(func) .. " "
                if string.len( thisfuncname ) < 42 then
                    thisfuncname =
                        string.rep( "-", (42 - string.len(thisfuncname))/2 ) .. thisfuncname
                    thisfuncname =
                        thisfuncname .. string.rep( "-", 42 - string.len(thisfuncname) )
                end

                --单个函数的总时间减去子函数的时间,获得自身的时间
                local timeinself = record.time - (record.unknow_child_time + record.name_child_time)
                if timeinself < 0 then
                    timeinself = 0;
                end

                local children =  record.unknow_child_time+record.name_child_time
                if children > record.time then
                    children = record.time
                end

                timeinself = timeinself * scale;

                table.insert(lines, string.rep( "-", 19 ) .. thisfuncname ..
                    string.rep( "-", 19 ) .. "\n" )

                table.insert(lines, terms.capitalized.." count:         " ..
                    string.format( "%4d", record.count ) .. "\n" )
                table.insert(lines, "Time spend total:       " ..
                    string.format( "%4.4f", record.time * scale) .. "s\n" )
                table.insert(lines, "Time spent in children: " ..
                    string.format("%4.4f",(children) * scale) ..
                    "s\n" )

                table.insert(lines, "Time spent in self:     " ..
                    string.format("%4.4f", timeinself) .. "s\n" )

                -- Report on each child in the form
                -- Child  <funcname> called n times and took a.bs
                local added_blank = 0
                for k,v in pairs(record.children) do
                    if added_blank == 0 then
                        table.insert(lines, "\n" ) -- extra separation line
                        added_blank = 1
                    end
                    table.insert(lines, "Child " .. self:pretty_name(k) ..
                        string.rep( " ", 41-string.len(self:pretty_name(k)) ) .. " " ..
                        terms.pastverb.." " .. string.format("%6d", v) )
                    table.insert(lines, " times. Took " ..
                        string.format("%4.5f", record.children_time[k] * scale ) .. "s\n" )

                end

                table.insert(lines, "\n" ) -- extra separation line

            end

        end
    end

    table.insert(lines, [[
END
]] )


    return lines,total_time
end

--[[--
    输出报表到文件
    @tparam     table     self    Profiler对象
    @tparam     string     outfile    文件名称
    @return   number 本次总共花费时间
    @usage
        local new_profiler = import("bos.core.profiler")
        local profiler = new_profiler("call")
        profiler:start();
        -- do something
        profiler:stop();
        profiler:dump_report_to_file("path");
]]
function Profiler.dump_report_to_file(self,outfile)
    local outfile = io.open(outfile, "w+" )
    local lines, total_time= self:report()
    for i,v in ipairs(lines) do
        outfile:write(v)
    end
    outfile:flush()
    outfile:close()
    return total_time
end


--[[
    美化名称，输出可以看懂的信息
    @tparam     function    func  函数
    @boolean    force 是否强制
]]
function Profiler:pretty_name(func,force)

    -- Only the data collected during the actual
    -- run seems to be correct.... why?
    local info = self.caller_cache[func].func_info

    local name = ""
    if info.what == "Lua" and force then
        name = "L:" .. info.short_src ..":" .. info.linedefined
        return name;
    end
    if info.what == "Lua" then
        name = "L:"
    end
    if info.what == "C" then
        name = "C:"
    end
    if info.what == "main" then
        name = " :"
    end
    if info.name == nil then
        name = name .. "<"..tostring(func) .. ">"
    else
        name = name .. info.name
    end

    if info.source then
        name = name .. "@" .. info.source
    else
        if info.what == "C" then
            name = name .. "@?"
        else
            name = name .. "@<string>"
        end
    end
    name = name .. ":"
    -- if info.what == "C" then
    --     name = name .. "unknow line"
    -- else
    --     name = name .. info.linedefined
    -- end
    name = name .. info.linedefined

    return name
end

return new_profiler



