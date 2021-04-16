#! /usr/bin/env lua
--
-- test.lua
-- Copyright (C) 2020 romgrk <romgrk@arch>
--
-- Distributed under terms of the MIT license.
--

local export = require'init'

local function print_table(tbl)
  if type(tbl) ~= 'table' then
    print(tbl)
    return
  end
  local result = '{ '
  for k, v in pairs(tbl) do
    result = result .. k .. ' = ' .. tostring(v) .. (i == #tbl and '' or ', ')
  end
  result = result .. ' }'
  print(result)
end

print_table(export)
print_table(export.filter)

local lines = {"abc", "esst", "test", "lua_test", "east", "esat"}
local filtered = export.filter("est", lines)
print_table(filtered)
print_table(filtered[1][1])
print_table(filtered[1][2])
print_table(filtered[1][3])

local orderd = export.quicksort(filtered)
print_table(orderd)
