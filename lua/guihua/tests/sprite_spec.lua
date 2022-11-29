local eq = assert.are.same

local busted = require('plenary/busted')
local cur_dir = vim.fn.expand('%:p:h')

describe('should create view  ', function()
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.sprite'] = nil
  vim.cmd('packadd guihua.lua')
  it('should construct a text win ', function()
    local log = require('guihua.log').info

    local Sprite = require('guihua.sprite')
    local data = {
      "local Rect = require 'guihua.rect'",
      "local class = require'middleclass'",
    }
    local win = Sprite:new({
      loc = 'top_center',
      syntax = 'lua',
      rect = { height = 2, pos_x = 0, pos_y = 10 },
      data = data,
      hl_line = 1,
      enter = true,
    })

    log('draw data', data)
    win:on_draw(data)
  end)
end)
