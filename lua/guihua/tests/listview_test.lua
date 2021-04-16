package.loaded["guihua"] = nil
package.loaded["guihua"] = nil
package.loaded["guihua.view"] = nil
package.loaded["guihua.viewctrl"] = nil
package.loaded["guihua.listview"] = nil
package.loaded["guihua.listviewctrl"] = nil
vim.cmd("packadd guihua.lua")
require("luakit._load")

local log = require "luakit.utils.log".log
function test()
  -- vim.cmd("packadd guihua.lua")

  --package.loaded.packer_plugins['guihua.lua'].loaded = false
  local listview = require("guihua.listview")
  local view = require("guihua.listview")
  vim.cmd("packadd guihua.lua")

  local sorter = require'fzy'
  log('sorter', sorter)
  if sorter == nil then return end
  local filter_input =  'tes' -- get string after prompt
  local testdata = {'abc', 'test', 'teas', 'blabal', 'testcase'}
  local filtered_data = sorter.filter(filter_input, testdata)
  log(filtered_data)
  local ordered=sorter.quicksort(filtered_data)
  log(ordered)
  ordered = sorter.fzy(filter_input, testdata)

  log(ordered
  )
  -- display_data = {unpack(listobj.filtered_data, 1, listobj.display_height)}
  -- log("filter: ", display_data)

  vim.g.debug_output = true
  win =
    new(
    listview,
    {
      loc = "up_left",
      prompt = true,
      rect = {height = 5},
      -- data = display_data,
      data = {
        "Listview: test line should show",
        "list line2 tes",
        "list line3 tesssst ",
        "list line4 tast"
      }
    }
  )
  --vim.cmd('normal! zvzz')
  -- vim.cmd('stopinsert!')
  -- vim.cmd('normal! G')
  -- vim.cmd('normal')
  --vim.cmd('startinsert!')
  -- log("test created win", win)
end

test()
