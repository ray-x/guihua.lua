local eq = assert.are.same

local busted = require('plenary/busted')
local cur_dir = vim.fn.expand('%:p:h')

describe('should create view  ', function()
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.textview'] = nil
  package.loaded['guihua.textviewctrl'] = nil
  vim.cmd('packadd guihua.lua')
  it('should construct a text win ', function()
    local log = require('guihua.log').info
    local sorter = require('fzy')

    local TextView = require('guihua.textview')
    local data = {
      "local Rect = require 'guihua.rect'",
      "local class = require'middleclass'",
      'local a = 32',
      "local b='abcdef'",
    }
    local win = TextView:new({
      loc = 'top_center',
      syntax = 'lua',
      rect = { height = 5, pos_x = 0, pos_y = 10 },
      data = data,
      hl_line = 1,
      enter = enter,
    })
    log('draw data', data)
    win:on_draw(data)
    vim.cmd('normal! zb')
    vim.cmd('startinsert!')
  end)
end)
