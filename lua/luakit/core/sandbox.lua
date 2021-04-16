--[[--lua沙盒
@module sandbox
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:08
]]
--[[
2. lua沙盒
理解：lua沙盒就是通过改变上下文环境，使函数可以在不同的环境表中运行，访问得到限制，从而避免相互
影响。可以利用其构建一个安全的环境，用来执行一些未知的危险代码
]]


function test( ... )
    print("hello")
end

test()

-- 设置test在环境表e运行，此时test不能调用_G中的print
-- local e = {}
-- setfenv(test, {})
-- test()
-- setfenv(test, _G)
-- test()


-- 在e环境表对x赋值不会影响到f环境
local e = {print = print, setfenv = setfenv}
setfenv(1, e)
x = 3
print(x)
local f = {print = print, setfenv = setfenv}
setfenv(1, f)
print(x)

---保护环境 人人有责
local env = getfenv();
local protectEnv = function(env)
    local mt  = getmetatable(env);
    local cache = {};
    mt.__newindex = function( t,k,v )
        if cache[k] == nil then
            cache[k] = v;
        else
            if cache[k] ~= v then
                error("不允许复写" .. k)
            end
        end
        rawset(mt.__index, k, v)
    end
end
protectEnv(env);

-- http://timothyqiu.com/archives/lua-note-sandboxes/