local eq = assert.are.same

local busted = require('plenary/busted')
local cur_dir = vim.fn.expand('%:p:h')

describe('should create view  ', function()
  package.loaded['guihua'] = nil
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  vim.cmd('packadd guihua.lua')
  it('should construct a float win ', function()
    local log = require('guihua.log').info
    local sorter = require('fzy')

    local ListView = require('guihua.listview')
    local TextView = require('guihua.textview')
    log('sorter', sorter)
    if sorter == nil then
      return
    end
    local filter_input = 'tes' -- get string after prompt
    local testdata = { 'abc', 'test', 'teas', 'blabal', 'testcase' }
    local filtered_data = sorter.filter(filter_input, testdata)
    log(filtered_data)
    local ordered = sorter.quicksort(filtered_data)
    log(ordered)
    ordered = sorter.fzy(filter_input, testdata)

    log(ordered)
    -- display_data = {unpack(listobj.filtered_data, 1, listobj.display_height)}
    -- log("filter: ", display_data)

    local listview = ListView:new({
      loc = 'up_left',
      prompt = true,
      rect = { height = 5 },
      -- data = display_data,
      data = {
        'Listview: test line should show',
        'list line2 tes',
        'list line3 tesssst ',
        'list line4 tast',
      },
    })

    vim.cmd('normal! zb')
    vim.cmd('startinsert!')
    eq(true, vim.api.nvim_win_is_valid(listview.win))
  end)
end)
