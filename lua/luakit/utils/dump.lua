--[[--
格式化输出table（格式化过程中，排序操作会比较耗时）
@module dump
@author iwiniwin

Date   2019-11-15 19:20:39
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:41:51
]]

local isSort  = true;

local table_format = string.format
local string_len = string.len
local string_rep = string.rep

local math_randomseed = math.randomseed
local debug_traceback = debug.traceback

local function _dump_value(v)
    if type(v) == "string" then
        v = "\"" .. v .. "\""
    end
    return tostring(v)
end

--- dump 输出table的内容
--@param value 输出的table
--@string desciption 调试信息格式
--@int nesting 输出时的嵌套层级，默认为 15
--@usage local t = {key = "xxx"}
--dump(t)
local function dump(value, desciption, nesting)
    if type(nesting) ~= "number" then nesting = 10 end

    local lookup = {}
    local result = {}
    local traceback = string.split(debug_traceback("", 2), "\n")
    
    --print("dump from: " .. string.trim(traceback[3]))
    local str = "- dump from: " .. string.trim(traceback[3]);
    print(str);
    local function _dump(value, desciption, indent, nest, keylen)
        desciption = desciption or "<var>"
        local spc = ""
        if type(keylen) == "number" then
            spc = string_rep(" ", keylen - string_len(_dump_value(desciption)))
        end
        if type(value) ~= "table" then
            result[#result +1 ] = table_format("%s%s%s = %s", indent, _dump_value(desciption), spc, _dump_value(value))
        elseif lookup[tostring(value)] then
            result[#result +1 ] = table_format("%s%s%s = *REF*", indent, _dump_value(desciption), spc)
        else
            lookup[tostring(value)] = true
            if nest > nesting then
                result[#result +1 ] = table_format("%s%s = *MAX NESTING*", indent, _dump_value(desciption))
            else
                result[#result +1 ] = table_format("%s%s = {", indent, _dump_value(desciption))
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    if k~="___message" then
                        keys[#keys + 1] = k
                        local vk = _dump_value(k)
                        local vkl = string_len(vk)
                        if vkl > keylen then keylen = vkl end
                        values[k] = v
                    end
                end
                if isSort == true then
                    table.sort(keys, function(a, b)
                        if type(a) == "number" and type(b) == "number" then
                            return a < b
                        else
                            return tostring(a) < tostring(b)
                        end
                    end)
                end


                for i, k in ipairs(keys) do
                    _dump(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result +1] = table_format("%s}", indent)
            end
        end
    end
    _dump(value, desciption, "- ", 1)

    
    for i, line in ipairs(result) do
        -- str = str .. line .. "\r\n";
        print(line)
    end

end

return dump;