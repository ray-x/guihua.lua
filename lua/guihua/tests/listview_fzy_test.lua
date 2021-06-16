local log = require"guihua.log".info
local ListView = require "guihua.listview"
local TextView = require "guihua.textview"
local lines = {"hi", "ho", "ha"}
local data = {
  {filename = "/tmp/hi.txt", uri = "file:///tmp/hi.txt", text = "hi"},
  {filename = "/tmp/ho.txt", uri = "file:///tmp/ho.txt", text = "ho"},
  {filename = "/tmp/ha.txt", uri = "file:///tmp/ha.txt", text = "ha"}
}
local idx = require"guihua.util".fzy_idx
local function preview_uri(uri, line, offset_y)
  line = line or 1
  offset_y = offset_y or 6
  local loc = {targetUri = uri, targetRange = {start = {line = line}}}
  loc.targetRange["end"] = {line = line + 4}
  local n = tostring(os.time())
  local contents = {"local abc = 12", "local winid = " .. n, "print(winid)"}
  return TextView:new({
    loc = "top_center",
    rect = {height = #contents + 1, width = 90, pos_x = 0, pos_y = 7},
    range = {["end"] = {character = 1, line = 2}, start = {character = 1, line = 0}},
    uri = uri,
    syntax = "lua"
  })
end

local on_move = function(pos)
  if pos == 0 then
    pos = 1
  end
  if pos > #data then
    print("[ERR] idx", pos, "length ", #data)
  end
  local l = idx(data, pos)
  log(l, pos, data, lines)
  return preview_uri(l.uri, 1)
end

local function test_preview()
  ListView:new({
    loc = "top_center",
    prompt = true,
    rect = {height = 4, width = 90},
    data = data,
    on_move = on_move
  })
end

test_preview()
