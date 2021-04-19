package.loaded["guihua"] = nil
package.loaded["guihua.view"] = nil
package.loaded["guihua.viewctrl"] = nil
package.loaded["guihua.listview"] = nil
package.loaded["guihua.listviewctrl"] = nil
vim.cmd("packadd guihua.lua")

local TextView = require("guihua.textview")
local log = require "guihua.log".info
--package.loaded.packer_plugins['guihua.lua'].loaded = false
function test_fixed(enter)
  local data = {
    "local Rect = require 'guihua.rect'",
    "local class = require'middleclass'",
    "local a = 32",
    "local b='abcdef'"
  }
  local win = TextView:new({loc = "top_center", syntax = "lua", rect = {height = 5, pos_x = 0, pos_y = 10}, data = data, enter = enter})
  log("draw data", data)
  win:on_draw(data)
  -- vim.cmd("startinsert!")
end

function test_relative()
  local data = {
    "local Rect2 = require 'guihua.rect'",
    "local class2 = require'middleclass'",
    "local a2 = 32",
    "local b2 = 'abcdef'"
  }
  local win = TextView:new({relative = 'cursor', syntax = "lua", rect = {height = 5, pos_x = 0, pos_y = 10}, data = data})
  log("draw data", data)
  win:on_draw(data)
  -- vim.cmd("startinsert!")
end

function test_multi()
    test_fixed()
    test_relative()
end

test_fixed(true)
-- test_relative()

-- test_multi()
