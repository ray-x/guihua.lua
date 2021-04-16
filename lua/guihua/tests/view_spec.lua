local eq = assert.are.same

local busted = require("plenary/busted")
local cur_dir = vim.fn.expand("%:p:h")

describe(
  "should create view  ",
  function()
    package.loaded["guihua.lua"] = nil

    vim.cmd("packadd guihua.lua")
    require("luakit._load")
    it(
      "should construct a float win ",
      function()
        view = require "guihua.view"
        win = new(view, {loc='up_left'})
        win:on_draw("test line should show")
        assert(true)

      end
    )
  end
)
