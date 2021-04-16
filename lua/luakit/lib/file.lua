--[[--文件操作
@module File
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:45:04
]]
local File = {}

---插入文件内容到指定行
--@table content 插入内容
--@string path 目标文件
--@number row 行数，默认插入到文件末尾
File.insert_to_file = function (content, path, row)
	file = io.open(path, "r")
	local lines = {}
	for line in file:lines() do
		if row and #lines == row - 1 then
			for _, l in ipairs(content) do
				table.insert(lines, l)
			end
		end
		table.insert(lines, line)
	end 
	file:close()
	if not row then
		for _, l in ipairs(content) do
			table.insert(lines, l)
		end
	end
	file = io.open(path, "w+")
	for _,line in ipairs(lines) do
		file:write(line .. "\n")
	end
	file:close()
end

---查询文件是否包含指定内容
--@string path 目标文件
--@string text 关键字
--@return 关键字所在行数，不存在返回空表
File.find_text = function (path, text)
	local result = {}
	local row = 0
	file = io.open(path, "r")
    for line in file:lines() do
    	row = row + 1
        if string.find(line, text) then
        	table.insert(result, row)
        end
    end 
    return result
end

return File