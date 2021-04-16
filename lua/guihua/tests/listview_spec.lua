local eq = assert.are.same

local busted = require("plenary/busted")
local cur_dir = vim.fn.expand("%:p:h")

describe(
  "should create view  ",
  function()
    package.loaded["guihua"] = nil
    package.loaded["guihua"] = nil
    package.loaded["guihua.view"] = nil
    package.loaded["guihua.viewctrl"] = nil
    package.loaded["guihua.listview"] = nil
    package.loaded["guihua.listviewctrl"] = nil
    vim.cmd("packadd guihua.lua")
    require("luakit._load")
    it(
      "should construct a float win ",
      function()
        -- vim.cmd("packadd guihua.lua")

        --package.loaded.packer_plugins['guihua.lua'].loaded = false
        listview = require('guihua.listview')
        vim.cmd("packadd guihua.lua")

        win =
          new(
          listview,
          {
            loc = "up_left",
            prompt = true,
            rect = {height = 3},
            data = {
              "Listview: test line should show",
              "list line2",
              "list line3",
              "list line4"
            }
          }
        )
        log("test", win)
        -- win:on_draw({})
        time = require("luakit.lib.time")
        win:set_pos(1)
      end
    )
  end
)
