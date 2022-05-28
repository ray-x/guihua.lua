local eq = assert.are.same

local busted = require('plenary/busted')
local cur_dir = vim.fn.expand('%:p:h')

describe('should create view  ', function()
  package.loaded['guihua.lua'] = nil

  vim.cmd('packadd guihua.lua')
  -- require("luakit._load")
  it('should construct a float win ', function()
    local log = require('guihua.log').info
    View = require('guihua.view')
    package.loaded['guihua'] = nil
    package.loaded['guihua.view'] = nil
    -- package.loaded.packer_plugins['guihua.lua'].loaded = false
    vim.cmd('packadd guihua.lua')

    local data = { 'View: test line should show', 'view line2', 'view line3', 'view line4' }
    local win = View:new({
      loc = 'up_left',
      rect = { height = 5, pos_x = 120 },
      prompt = true,
      enter = true,
      data = data,
    })
    log('draw data', data)
  end)
end)
