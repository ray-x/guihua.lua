local log = require"guihua.log".info
local trace = require"guihua.log".trace
local function view_test()
  View = require 'guihua.view'
  package.loaded["guihua"] = nil
  package.loaded["guihua.view"] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd("packadd guihua.lua")

  local data = {"View: test line should show", "view line2", "view line3", "view line4"}
  local win = View:new({
    loc = "up_left",
    rect = {height = 5, pos_x = 120},
    prompt = true,
    enter = true,
    data = data
  })
  log("draw data", data)
  -- win:on_draw(data)
  -- vim.cmd("startinsert!")
end

local function view_mask_test()
  View = require 'guihua.view'
  package.loaded["guihua"] = nil
  package.loaded["guihua.view"] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd("packadd guihua.lua")

  local data = {"View: test line should show", "view line2", "view line3", "view line4"}
  local win = View:new({
    loc = "up_left",
    rect = {height = 5, pos_x = 120},
    prompt = true,
    enter = true,
    data = data,
    mask = 60
  })
  log("draw data", data)
  -- win:on_draw(data)
  -- vim.cmd("startinsert!")
end

view_mask_test()
