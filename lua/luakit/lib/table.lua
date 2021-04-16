--[[--table操作
@module table
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:20
]]

local tableConcat = table.concat
local tableInsert = table.insert

local type = type
local pairs = pairs
local tostring = tostring
local next = next
local TableLib = {}

--[[--
    计算表格包含的字段数量
    Lua table 的 "#" 操作只对依次排序的数值下标数组有效，TableLib.nums() 则计算 table 中所有不为 nil 的值的个数。

    @tparam table t 要计算的表格
    @return number 结果
    @usage
    local TableLib = import("bos.utils").TableLib
    TableLib.nums({a= 1,b=2})
]]
function TableLib.nums(t)
    local temp = checktable(t)
    local count = 0
    for k, v in pairs(temp) do
        count = count + 1
    end
    return count
end


--[[--
    将来源表格中所有键及其值复制到目标表格对象中，如果存在同名键，则覆盖其值
    @tparam table dest 目标表格
    @tparam table src  来源表格
    @usage
    local dest = {a = 1, b = 2}
    local src  = {c = 3, d = 4}
    TableLib.merge(dest, src)
    -- dest = {a = 1, b = 2, c = 3, d = 4}
]]
function TableLib.merge(dest, src)
    if not src or not dest then
        return;
    end
    for k, v in pairs(src) do
        dest[k] = v
    end
end

--[[--
    合并两个表格的内容
    @tparam table src1 来源表格1
    @tparam table src2 来源表格2
    @return table 合并后的新表
    @usage
    local src1 = {a = 1, b = 2}
    local src2  = {c = 3, d = 4}
    local temp = TableLib.merge(src1, src2)
    -- src1 = {a = 1, b = 2}
    -- temp = {a = 1, b = 2, c = 3, d = 4}
]]
function TableLib.merge2(src1, src2)
    local tb ={}
    if src1 and next(src1) then
        for k, v in pairs(src1) do
            tableInsert(tb,v);
        end
    end
    if src2 and next(src2) then
        for k, v in pairs(src2) do
            tableInsert(tb,v);
        end
    end
    return tb;
end

--[[--
    合并两个表格的以数字开头的内容
    @tparam table src1 来源表格1
    @tparam table src2 来源表格2
    @return table 合并后的新表
    @usage
    local src1 = {a = 1, b = 2, 3}
    local src2  = {c = 3, d = 4, 4}
    local temp = TableLib.merge3(src1, src2)
     return {3, 4}
]]
function TableLib.merge3(src1, src2)
    local tb ={}
    if src1 and next(src1) then
        for k, v in pairs(src1) do
            if type(k) == "number" then
                tableInsert(tb,v);
            end
        end
    end
    if src2 and next(src2) then
        for k, v in pairs(src2) do
            if type(k) == "number" then
                tableInsert(tb,v);
            end
        end
    end
    return tb;
end

--[[--
    同步数据,把tab2 的数据同步到 tab1（不是合并）
    @tparam table tab1 来源表格1
    @tparam table tab2 来源表格2
    @usage
    local tab1 = {c = 1, b = 2,g=9}
    local tab2  = {c = 3, d = 4}
    TableLib.sync(tab1, tab2)
    -- tab1  = {c = 3, b = 2,g=9}
    -- tab2  = {c = 3, d = 4}
]]
function TableLib.sync(tab1, tab2)
    for k, v in pairs(tab2) do
        if tab1[k] ~= nil then
            tab1[k] = v;
        end
    end
end

--[[--
    从表格中查找指定值，返回其 key，如果没找到返回 nil
    @tparam table hashtable 表格
    @tparam mixed value 要查找的值
    @return string 该值对应的 key
    @usage
    local hashtable = {name = "dualface", comp = "chukong"}
    print(TableLib.key_of(hashtable, "chukong")) -- 输出 comp
]]
function TableLib.key_of(hashtable, value)
    for k, v in pairs(hashtable) do
        if v == value then return k end
    end
    return nil
end

--[[--
    从表格中查找指定值，返回其索引，如果没找到返回 false
    @tparam table array 表格
    @tparam mixed value 要查找的值
    @tparam number begin 起始索引值
    @return number 
    @usage
    local a = {"a","b","c"}
    TableLib.index_of(a,"b",1)
]]

function TableLib.index_of(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then return i end
    end
    return false
end

--[[--
    从表格中删除指定值，返回删除的值的个数
    @tparam table array 表格
    @tparam mixed value 要删除的值
    @tparam boolean remove_all 是否删除所有相同的值
    @return number 删除的值的个数
    @usage 
    local array = {"a", "b", "c", "c"}
    print(TableLib.remove_by_value(array, "c", true)) -- 输出 2
]]
function TableLib.remove_by_value(array, value, remove_all)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not remove_all then break end
        end
        i = i + 1
    end
    return c
end

--[[--
    判断table是否为空
    @tparam table t 表格
    @return boolean 是否为空
    @usage
    TableLib.is_empty({}) -- true
]]
function TableLib.is_empty(t)
    if t and type(t)=="table" then --FIXME 此句可以判空，为何还要循环表内元素？
        return next(t)==nil;
    end
    return true;
end

--[[--
    判断table是否为table
    @tparam table t 表格
    @return boolean 是否为table
    @usage
    TableLib.is_table({}) -- true
]]
function TableLib.is_table(t)
    if type(t)=="table" then
        return true;
    end
    return false;
end

--[[--
    复制table
    @tparam table st 表格
    @return table 复制后的新表
    @usage
    TableLib.copy_tab({1,2,3,4,5}) 
]]
function TableLib.copy_tab(st)
    local tab = {}
    for k, v in pairs(st or {}) do
        if type(v) ~= "table" then
            tab[k] = v
        else
            tab[k] = TableLib.copy_tab(v)
        end
    end
    return tab
end

--[[--
    从table1复制到table2
    @tparam table target 目标表格
    @tparam table source 被复制表格
    @usage
    TableLib.copy_to({1,2,3,4,5},{"c","c","c"}) 
]]

function TableLib.copy_to(target, source)
    for _,v in ipairs(source or {}) do
        table.insert(target, v)
    end
end


--[[--
    table校验，返回自身或者{}
    @tparam table t 目标表格
    @return table 返回自身或者{}
    @usage
    TableLib.checktable({1,2,3,4,5}) 
]]
function TableLib.checktable(t)
    return TableLib.verify(t)
end

--[[--
    table校验，返回自身或者{}
    @tparam table t 目标表格
    @return table 返回自身或者{}
    @usage
    TableLib.verify({1,2,3,4,5}) 
]]
function TableLib.verify(t)
    if t and type(t)=="table" then
        return t;
    end
    return {};
end

--[[--
    获取table 元素数量
    @tparam table t 目标表格
    @return number 数量
    @usage
    TableLib.size({1,2,3,4,5}) 
]]
function TableLib.size(t)
    if type(t) ~= "table" then
        return 0;
    end

    local count = 0;
    for _,v in pairs(t) do
        count = count + 1;
    end

    return count;
end

--[[--
    比较两个table的内容是否相同
    @tparam table t1 目标表格
    @tparam table t2 目标表格
    @return boolean 是否相同
    @usage
    TableLib.equal({1,2,3,4,5},{5,4,3,2,1}) 
]]
function TableLib.equal(t1,t2)
    if type(t1) ~= type(t2) then
        return false;
    else
        if type(t1) ~= "table" then
            return t1 == t2;
        else
            local len1 = TableLib.size(t1);
            local len2 = TableLib.size(t2);
            if len1 ~= len2 then
                return false;
            else
                local isEqual = true;
                for k,v in pairs(t1) do
                    if t2[k]  == nil then
                        isEqual = false;
                        break;
                    else
                        if type(t2[k]) ~= type(v) then
                            isEqual = false;
                            break;
                        else
                            if type(v) ~= "table" then
                                if t2[k] ~= v then
                                    isEqual = false;
                                    break;
                                end
                            else
                                isEqual = TableLib.equal(v,t2[k]);
                                if not isEqual then
                                    break;
                                end
                            end
                        end
                    end
                end

                return isEqual;
            end
        end
    end
end

--[[--
    从表里获取n个随机值
    @tparam table t 目标表格
    @tparam number num 获取个数
    @return table 获取的值的table
    @usage
    TableLib.random({1,2,3,4,5},2) 
]]
function TableLib.random(t, num)
    assert(type(t) == "table", "invalid arg");
    local randomList = { }

    if not num or num > #t then
        num = #t;
    end

    local rangeList = { };
    for i,v in ipairs(t) do
        rangeList[i] = v;
    end

    for i = 1, num do
        local index = math.random(i, #rangeList);--生成一个随机数
        rangeList[i], rangeList[index] = rangeList[index], rangeList[i];--交换
        randomList[i] = rangeList[i];--交换以后把i位置的牌放到要返回的函数中
    end

    return randomList;
end

--[[--
    序列化table
    @tparam table root 目标表格
    @return string 结果
    @usage
    TableLib.tostring({1,2,3,4,5}) 
]]
function TableLib.tostring(root)
    if not root then return end
    local cache = {  [root] = "root" }
    local flag = {};
    local function _dump(t,name)
        local mt = getmetatable(t)
        if mt and mt.__tostring then
            return tostring(t)
        end
        local temp = {}
        for i,v in ipairs(t) do
            flag[i] = true;
            if cache[v] then
                tableInsert(temp, cache[v])
            elseif type(v) == "table" then
                cache[v] = string.format("%s[%d]", name, i)
                tableInsert(temp, string.format("%s", _dump(v, cache[v])))
            else
                tableInsert(temp, tostring(v))
            end
        end
        for k,v in pairs(t) do
            if not flag[k] then
                local key = tostring(k)
                if cache[v] then
                    tableInsert(temp, string.format("%s=%s", key, cache[v]))
                elseif type(v) == "table" then
                    cache[v] = string.format("%s.%s", name, key)
                    tableInsert(temp, string.format("%s=%s", key, _dump(v, cache[v])))
                else
                    tableInsert(temp, string.format("%s=%s", key, tostring(v)))
                end
            end
        end
        return string.format("{%s}", tableConcat(temp,","));
    end
    return _dump(root, "root");
end

--[[--
    合并多个表到src
    @tparam table src 目标表格
    @tparam tables ... 待合并表，可多个
    @usage
    TableLib.deep_merge({1,2,3,4,5},{"c","c","s","c"},{a = "ccc"}) 
]]
function TableLib.deep_merge( src, ... )
    local arg = {...};
    for i,v1 in ipairs(arg) do
        for k,v in pairs(v1) do
            if type(v) == "table" and type(src[k]) == "table" then
                TableLib.deep_merge(src[k], v);
            else
                src[k] = v;
            end
        end
    end
end

--[[--
    遍历表，处理函数返回true终止
    @tparam table t 目标表格
    @tparam function func 处理函数
    @usage
    local function a(i,v)
        -- return true 返回true时停止遍历
    end
     TableLib.select({1,2,3,4}, a)
]]
function TableLib.select(t, func)
    for i,v in ipairs(t) do
        if func and func(i,v) == true then
            return i, v;
        end
    end
end

--[[--
    遍历所有元素，返回所有处理函数return true的元素
    @tparam table t 目标表格
    @tparam function func 处理函数
    @return table array所有处理函数return true的元素
    @usage
    local function a(i,v)
        -- return true 返回true时最后要返回该元素
    end
     TableLib.select({1,2,3,4}, a)
]]
function TableLib.select_all(t, func)
    local temp = {};
    for i,v in ipairs(t) do
        if func and func(i,v) == true then
            temp[#temp+1] = v;
        end
    end
    return temp;
end

--[[--
    检索某个元素
    @tparam table t 目标表格
    @tparam mixed ...  键值索引,传入多个会递归检索
    @return nil|mixed 返回键值对应的值
    @usage
    local a = {
        b = {  -- 传入"b"作为参数时就返回该表
            c = 1  -- 在"b"之后传入"c"，就返回1
        }
    }
     TableLib.retrive(a,"b","c") -- return 1
]]
function TableLib.retrive(t, ...)
    if not t then
        return
    end
    local arg = {...}
    local tmp = t;
    for _,v in ipairs( arg ) do
        if tmp[v] then
            tmp = tmp[v];
        else
            return;
        end
    end
    return tmp;
end

--[[--
    设置table为只读
    @tparam table t 目标表格
    @usage
    local a = {1,1,1,1}
    TableLib.lock_write(a)
]]
function TableLib.lock_write(t)
    local mt = getmetatable(t) or {};
    mt.__newindex = function(_,k,v)
        error(string.format("can't write [%s] into table",k))
    end;
    if not getmetatable(t) then
        setmetatable(t, mt);
    end
end

--[[--
    取消设置table为只读
    @tparam table t 目标表格
    @usage
    local a = {1,1,1,1}
    TableLib.lock_write(a)
    TableLib.release_lock_write(a)
]]
function TableLib.release_lock_write(t)
    local mt = getmetatable(t);
    if not (mt and mt.__newindex) then
        return
    end
    mt.__newindex = nil
end

--[[--
    通过连续下标，获取table子集
    @tparam table t 目标表格,array
    @tparam number from 起始下标
    @tparam number to 截止下标
    @return table 子集
    @usage
    local a = {1,1,1,1}
    TableLib.get_subset(a,2,3)
]]
function TableLib.get_subset(t, from, to)
    assert(from > 0 and from <= to and to <= #t, string.format("invalid range : %d, %d", from, to));
    local sub = {}
    for i=from,to do
        sub[#sub + 1] = t[i]
    end
    return sub
end

--[[--
    克隆一份表数据
    @tparam table object 目标表格
    @return table 克隆表
    @usage
    local a = {1,1,1,1}
    TableLib.clone(a)
]]
function TableLib.clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

local function infilter( filter, key, value )
    if filter.key then
        for i,v in ipairs(filter.key) do
            if v == key then return i end
        end
    end
    if filter.class then
        for i,v in ipairs(filter.class) do
            if typeof and typeof(value, v) then return i end
        end
    end
    return false
end

--[[--
    克隆一份表数据，可过滤
    @tparam table object 目标表格
    @tparam table filter 过滤器{key = {"ingorekey1",...},class = {class1,...} }
    @return table 克隆表
    @usage
    local a = {1,1,1,1}
    local filter = {
        key = {"1","3"} -- 键值1、3对应的值不克隆
    }
    TableLib.clone(a,filter)
]]
function TableLib.clone2(object, filter)
    local lookup_table = {}
    filter = filter or {}
    local function _copy(object, filter)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            if not infilter(filter, key, value) then
                new_table[_copy(key, filter)] = _copy(value, filter)
            end
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object, filter)
end

--[[--
    加载string为table
    @tparam string strTab 定义table的字符串
    @return table 定义的表
    @usage
    local a = "{1,1,1,1}"
    TableLib.load_str_tab(a)
]]
function TableLib.load_str_tab(strTab)
    if string.match(strTab, "^%s*%{.*%}%s*$") then
        return loadstring("return " .. strTab)()
    end
    return strTab;
end

--[[--
    返回table中所有key的集合
    @tparam table tab 表
    @return table key表
    @usage
    local a = "{1,1,1,1}"
    TableLib.all_keys(a)
]]
function TableLib.all_keys( tab )
    if next(tab) == nil then
        print("nilTab")
        return
    end

    local keys = {}
    for k,_ in pairs(tab) do
        table.insert(keys, k)
    end
    return keys
end

return TableLib;