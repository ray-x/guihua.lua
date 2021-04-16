--[[--
序列化lua table
@module dump_to_file
@author iwiniwin

Date   2019-11-15 19:20:39
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:42:17
]]

local M = {};

local table_format = string.format
local string_len = string.len
local string_rep = string.rep


---数列化table 报错到文件
--@string t 表
--@string tabName 表名
--@string path 保存目录，可选
--@retrurn tableStr
function M.serialize(t, tabName,path)
    local function dump(value, desciption, nesting)
    	local lookup = {}
    	local result = {}
    	if type(nesting) ~= "number" then nesting = 100 end

		local function _dump_value(v)
		    if type(v) == "string" then
		        v = string.format("%q", v)
		    end
		    if type(v) == "function" or type(v) == "userdata" then
		    	v = string.format("%q", tostring(v))
		    end

		 	-- if type(v) == "userdata" then
		  --   	v = string.format("%q", tostring(v))
		  --   end

		    -- if type(v) == "number" then
		    	-- v = string.format("%.2f",v)
		    	-- 如果是小数,保留小数点后两位
		    	-- if math.floor(v) < v then
		    	-- 	v = string.format("%.2f",v)
		    	-- end
		    -- end
		    return tostring(v)
		end

		local function _dump_key(v)
		    if type(v) == "number" then
		        v = "[" .. v .. "]"
		    end
		    return v
		end

	    local function _dump(value, desciption, indent, nest, keylen)
	        desciption = desciption or "<var>"
	        local spc = ""
	        if type(keylen) == "number" then
	            spc = string_rep(" ", keylen - string_len(_dump_value(desciption)))
	        end

	        if type(value) ~= "table" then
	            result[#result +1 ] = table_format("%s%s%s = %s,", indent, _dump_key(desciption), spc, _dump_value(value))
	        elseif lookup[tostring(value)] then
	            result[#result +1 ] = table_format("%s%s%s = '*REF*%s',", indent, desciption, spc,tostring(value))
	        else
	            lookup[tostring(value)] = true
	            if nest > nesting then
	                result[#result +1 ] = table_format("%s%s = '*MAX NESTING*',", indent, desciption)
	            else
	            	result[#result +1 ] = table_format("%s%s = {", indent, _dump_key(desciption))
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
	                -- table.sort(keys, function(a, b)
	                --     if type(a) == "number" and type(b) == "number" then
	                --         return a < b
	                --     else
	                --         return tostring(a) < tostring(b)
	                --     end
	                -- end)
	                for i, k in ipairs(keys) do
	                    _dump(values[k], k, indent2, nest + 1, keylen)
	                end
	                result[#result +1] = table_format("%s},", indent)
	            end
	        end
	    end

    	_dump(value, desciption, "", 1)
    	result[1] 		= "{";
    	result[#result] = "}";

    	local ret = ""
	    for i, line in ipairs(result) do
	        ret = ret .. line .. "\n";
	    end
	    return ret;
	end

	tabName = tabName or "ret"
    

    local str = "do local " .. tabName .. " =\n"..dump(t) .. string.format("\nreturn %s end",tabName);
    -- local path = System.getStorageTempPath()  .. tabName .. ".lua"
    local filePath = tabName .. ".lua"
    if path then
        filePath = path .. "/" .. filePath
    end
    M.writefile(str,filePath)
    return str;
end


function M.writefile(str, file)
    --os.remove(file);
    local file =io.open(file,"w");
    if file then
    	file:write(str);
    	file:close();
    end
end


function M.dump_to_file(t,tabName,path)
	return M.serialize(t,tabName,path)
end


return M;