-- preview load this file
local function test_filepreview()
  local data = {
    "local Rect2 = require 'guihua.rect'",
    "local class2 = require'middleclass'", "local a2 = 32",
    "local b2 = 'abcdefg'"
  }
  local win = TextView:new({
    relative = "cursor",
    syntax = "lua",
    rect = {height = 5, pos_x = 0, pos_y = 10},
    uri = data
  })
  win:on_draw(data)
  -- vim.cmd("startinsert!")
end

test_filepreview()
