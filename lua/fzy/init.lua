--
-- init.lua
-- Copyright (C) 2020 romgrk <romgrk@arch>
--
-- Distributed under terms of the MIT license.
--

-- #! /usr/bin/env lua
local sep = package.config:sub(1, 1)
local dirname = string.sub(debug.getinfo(1).source, 2, string.len("/init.lua") * -1)

local original_path = dirname .. sep .. "original.lua"
local native_path = dirname .. sep .. "native.lua"
local quicksort_path = dirname .. sep .. "quicksort.lua"

local implementation = dofile(original_path)

local fn, err = loadfile(native_path)
if err == nil then
  local ok, result = pcall(fn)
  if ok then
    implementation = result
  end
end

implementation.quicksort = dofile(quicksort_path)

function implementation.fzy(niddle, stacks)
  if stacks == nil or #stacks < 1 then
    print("[ERR] fzy 2nd argument")
    return
  end
  if stacks[1].text ~= nil then
    return implementation.filter_table_ordered(niddle, stacks)
  else
    local filtered = implementation.filter(niddle, stacks)
    return implementation.quicksort(filtered)
  end
end

return implementation
