#! /usr/bin/env lua
--
-- init.lua
-- Copyright (C) 2020 romgrk <romgrk@arch>
--
-- Distributed under terms of the MIT license.
--

local sep = package.config:sub(1, 1)
local dirname = string.sub(debug.getinfo(1).source, 2, string.len('/init.lua') * -1)

local original_path = dirname .. sep .. 'original.lua'
local native_path   = dirname .. sep .. 'native.lua'
local quicksort_path   = dirname .. sep .. 'quicksort.lua'

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
  local filtered = implementation.filter(niddle, stacks)
  return implementation.quicksort(filtered)
end
return implementation
