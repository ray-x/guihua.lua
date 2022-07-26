#! /usr/bin/env lua
--
-- test.lua
-- Copyright (C) 2020 romgrk <romgrk@arch>
--
-- Distributed under terms of the MIT license.
--

local export = require'fzy'

local function print_table(tbl)
  if type(tbl) ~= 'table' then
    print(tbl)
    return
  end
  local i = 1
  local result = '{ '
  for k, v in pairs(tbl) do
    result = result .. k .. ' = ' .. tostring(v) .. (i == #tbl and '' or ', ')
  end
  result = result .. ' }'
  print(result)
end

-- print_table(export)
-- print_table(export.filter)
--
-- local lines = {"abc", "esst", "test", "lua_test", "east", "esat"}
-- local filtered = export.filter("est", lines)
-- print(vim.inspect(filtered))
-- print_table(filtered[1][1])
-- print_table(filtered[1][2])
-- print_table(filtered[1][3])
--
-- local orderd = export.quicksort(filtered)
-- print_table(orderd)


local lines = {{text="Lua 5.4 was release on 29 Jun 2020", meta={uri='http://www.lua.org/versions.html#5.4'}}, {text="Lua 5.3 was released on 12 Jan 2015", meta={uri='http://www.lua.org/versions.html#5.3'}}, {text="Lua 5.2 was released on 16 Dec 2011",  meta={uri='http://www.lua.org/versions.html#5.2'}}, {text="Lua 5.1 was released on 21 Feb 2006",  meta={uri='http://www.lua.org/versions.html#5.1'}}}

local filtered = export.filter_table_ordered("released", lines)
print("result: ")
print(vim.inspect(filtered))
