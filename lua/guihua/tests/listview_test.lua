package.loaded["guihua"] = nil
package.loaded["guihua.view"] = nil
package.loaded["guihua.viewctrl"] = nil
package.loaded["guihua.listview"] = nil
package.loaded["guihua.listviewctrl"] = nil
--vim.cmd("packadd guihua.lua")

local ListView = require("guihua.listview")
local TextView = require("guihua.textview")
local log = require "guihua.log".info
local function test_plaintext()
  -- vim.cmd("packadd guihua.lua")

  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  ---vim.cmd("packadd guihua.lua")

  local sorter = require "fzy"
  log("sorter", sorter)
  if sorter == nil then
    return
  end
  local filter_input = "tes" -- get string after prompt
  local testdata = {"abc", "test", "teas", "blabal", "testcase"}
  local filtered_data = sorter.filter(filter_input, testdata)
  log(filtered_data)
  local ordered = sorter.quicksort(filtered_data)
  log(ordered)
  ordered = sorter.fzy(filter_input, testdata)

  log(ordered)
  -- display_data = {unpack(listobj.filtered_data, 1, listobj.display_height)}
  -- log("filter: ", display_data)

  local win =
    ListView:new(
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

  vim.cmd("normal! zb")
  vim.cmd("startinsert!")
  -- vim.cmd('normal! zvzz')
  -- vim.cmd('stopinsert!')
  -- vim.cmd('normal! G')
  -- vim.cmd('normal')
  -- vim.cmd('startinsert!')
  -- log("test created win", win)
end

-- test()
-- function ListView:close(...)
--   log("unload listview")
--   log(debug.traceback())
--   self:unbind_ctrl()
--   self.super.on_close(...)
--   -- ListView.active_view:buf_closer()
--   log(" listview close finish") --, self)
-- end

-- function ListView.on_close()
--   log(" listview on close", ListView.active_view)
--   log(debug.traceback())
--   --self.m_delegate:on_close()
--   ListView.active_view:close()
--   log(" listview on close finish") --, self)
-- end

local open_file_at = function(filename, line)
  vim.api.nvim_command(string.format("e! +%s %s", line, filename))
end
local lines = {
  "./lua/fzy/quicksort.lua:3:  local function tprint(tbl, indent)",
  "./lua/fzy/quicksort.lua:7:    for k, v in pairs(tbl) do",
  "./lua/fzy/quicksort.lua:4:   if not indent then",
  "./lua/fzy/quicksort.lua:20:   local function partition(arr, low, high)",
  "./lua/fzy/quicksort.lua:15:  print(formatting .. v)",
  "./lua/fzy/quicksort.lua:9:      if type(v) == 'table' then"
}
local data = {
  {
    col = 11,
    filename = "/Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    uri = "file:////Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    lnum = 3,
    text = "local function tprint(tbl, indent)"
  },
  {
    col = 11,
    filename = "/Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    uri = "file:////Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    lnum = 7,
    text = "  for k, v in pairs(tbl) do"
  },
  {
    col = 22,
    filename = "/Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    uri = "file:////Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    lnum = 4,
    text = "if not indent then"
  },
  {
    col = 20,
    filename = "/Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    uri = "file:////Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    lnum = 20,
    text = "local function partition(arr, low, high) "
  },
  {
    col = 31,
    filename = "/Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    uri = "file:////Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    lnum = 15,
    text = "print(formatting .. v) "
  },
  {
    col = 31,
    filename = "/Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    uri = "file:////Users/ray.xu/github/guihua.lua/lua/fzy/quicksort.lua",
    lnum = 9,
    text = "   if type(v) == 'table' then "
  }
}

local function preview_uri(uri, line, offset_y)
  log(uri)
  offset_y = offset_y or 6
  local loc = {targetUri = uri, targetRange = {start = {line = line}}}
  loc.targetRange["end"] = {line = line + 4}
  local n = tostring(os.time())
  local contents = {"local abc = 12", "local winid = " .. n, "print(winid)"}
  return TextView:new(
    {
      loc = "top_center",
      rect = {
        height = #contents + 1,
        width = 90,
        pos_x = 0,
        pos_y = 7
      },
      -- data = display_data,
      data = contents,
      syntax = "lua"
    }
  )
end

local on_confirm = function(pos)
  if pos == 0 then
    pos = 1
  end
  local l = data[pos]
  log("confirm open", l.filename, pos, l.uri)
  open_file_at(l.filename, l.lnum)
end
local on_move = function(pos)
  if pos == 0 then
    pos = 1
  end
  if pos > #data then print("[ERR] idx", pos, "length ", #data)end
  local l = data[pos]
  log("pos:", pos, l.text or l, l.uri)
  -- todo fix
  return preview_uri(l.uri, l.lnum, 6)
end

local function test_preview()
  -- vim.g.debug_verbose_output = true
  package.loaded["guihua"] = nil
  package.loaded["guihua.view"] = nil
  package.loaded["guihua.viewctrl"] = nil
  package.loaded["guihua.listview"] = nil
  package.loaded["guihua.listviewctrl"] = nil
  --package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd("packadd guihua.lua")
  local win =
    ListView:new(
    {
      loc = "top_center",
      prompt = true,
      rect = {height = 4, width = 90},
      data = lines,
      on_confirm = on_confirm,
      on_move = on_move
    }
  )
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:on_draw({})
  win:set_pos(1)
end

local function test_list()
  data = {
    {
      col = 6,
      filename = "/Users/ray.xu/github/guihua.lua/lua/guihua/view.lua",
      display_filename = "./lua/guihua/view.lua",
      lnum = 30,
      range = {
        start = {
          character = 5,
          line = 29
        }
      },
      text = "if opts.prompt == true then",
      uri = "file:///Users/ray.xu/github/guihua.lua/lua/guihua/view.lua"
    },
    {
      col = 6,
      filename = "/Users/ray.xu/github/guihua.lua/lua/guihua/view.lua",
      display_filename = "./lua/guihua/view.lua",
      lnum = 35,
      range = {
        start = {
          character = 5,
          line = 34
        }
      },
      text = "if opts.loc ~= nil then",
      uri = "file:///Users/ray.xu/github/guihua.lua/lua/guihua/view.lua"
    },
    {
      col = 6,
      filename = "/Users/ray.xu/github/guihua.lua/lua/guihua/listview.lua",
      display_filename = "./lua/guihua/listview.lua",
      lnum = 21,
      range = {
        start = {
          character = 5,
          line = 34
        }
      },
      text = "function ListView:initialize(...)",
      uri =
      "file:///Users/ray.xu/github/guihua.lua/lua/guihua/listview.lua"
    }

  }
  local util=require'guihua.util'
  -- vim.g.debug_verbose_output = true
  package.loaded["guihua"] = nil
  package.loaded["guihua.view"] = nil
  package.loaded["guihua.viewctrl"] = nil
  package.loaded["guihua.listview"] = nil
  package.loaded["guihua.listviewctrl"] = nil
  --package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd("packadd guihua.lua")

  local d = util.aggregate_filename(data)
  data = d
  local win =
    ListView:new(
    {
      loc = "top_center",
      prompt = true,
      rect = {height = 5, width = 90},
      data = d,
      on_confirm = on_confirm,
      on_move = on_move
    }
  )
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:on_draw({})
  win:set_pos(1)
end

test_list()
-- test_plaintext()
-- test_preview()
