package.loaded['guihua'] = nil
package.loaded['guihua.view'] = nil
package.loaded['guihua.viewctrl'] = nil
package.loaded['guihua.listview'] = nil
package.loaded['guihua.listviewctrl'] = nil
package.loaded['guihua.util'] = nil
-- vim.cmd("packadd guihua.lua")

local home = vim.env.HOME
local github = vim.env.HOME .. '/github/'
local gopath = vim.env.GOPATH

local ListView = require('guihua.listview')
local TextView = require('guihua.textview')
local util = require('guihua.util')
local log = require('guihua.log').info

local prepare_for_render = require('navigator.render').prepare_for_render
local function test_plaintext()
  -- vim.cmd("packadd guihua.lua")

  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  ---vim.cmd("packadd guihua.lua")

  local sorter = require('fzy')
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

  local win = ListView:new({
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
--   -- ListView.active_view:closer()
--   log(" listview close finish") --, self)
-- end

-- function ListView.on_close()
--   log(" listview on close", ListView.active_view)
--   log(debug.traceback())
--   --self.m_delegate:on_close()
--   ListView.active_view:close()
--   log(" listview on close finish") --, self)
-- end

local open_file_at = function(filename, line, col)
  vim.api.nvim_command(string.format('e! +%s %s', line, filename))
  col = col or 1
  print(col)
  -- vim.api.nvim_command(string.format("normal! %dl", col - 1))
  vim.api.nvim_command(string.format('normal! %d|', col))
end
local lines = {
  './lua/fzy/quicksort.lua:3:  local function tprint(tbl, indent)',
  './lua/fzy/quicksort.lua:7:    for k, v in pairs(tbl) do',
  './lua/fzy/quicksort.lua:4:   if not indent then',
  './lua/fzy/quicksort.lua:20:   local function partition(arr, low, high)',
  './lua/fzy/quicksort.lua:15:  print(formatting .. v)',
  "./lua/fzy/quicksort.lua:9:      if type(v) == 'table' then",
}
local function preview_uri(uri, linenum, offset_y)
  log(uri)
  offset_y = offset_y or 6
  local loc = { targetUri = uri, targetRange = { start = { line = linenum } } }
  loc.targetRange['end'] = { line = linenum + 4 }
  local n = tostring(os.time())
  local contents = { 'local abc = 12', 'local winid = ' .. n, 'print(winid)' }
  return TextView:new({
    loc = 'top_center',
    rect = { height = #contents + 1, width = 90, pos_x = 0, pos_y = 7 },
    -- data = display_data,
    data = contents,
    syntax = 'lua',
  })
end

local data = {
  {
    col = 11,
    filename = github .. 'guihua.lua/lua/fzy/quicksort.lua',
    uri = 'file:///' .. github .. 'guihua.lua/lua/fzy/quicksort.lua',
    lnum = 3,
    text = '1: local function tprint(tbl, indent)',
  },
  {
    col = 11,
    filename = github .. 'guihua.lua/lua/fzy/quicksort.lua',
    uri = 'file:///' .. github .. 'guihua.lua/lua/fzy/quicksort.lua',
    lnum = 7,
    text = '2:  for k, v in pairs(tbl) do',
  },
  {
    col = 22,
    filename = github .. 'guihua.lua/lua/fzy/quicksort.lua',
    uri = 'file:///' .. github .. 'guihua.lua/lua/fzy/quicksort.lua',
    lnum = 4,
    text = '3: if not indent then',
  },
  {
    col = 20,
    filename = github .. 'guihua.lua/lua/fzy/quicksort.lua',
    uri = 'file:///' .. github .. 'guihua.lua/lua/fzy/quicksort.lua',
    lnum = 20,
    text = '4: local function partition(arr, low, high) ',
  },
  {
    col = 31,
    filename = github .. 'guihua.lua/lua/fzy/quicksort.lua',
    uri = 'file:///' .. github .. 'guihua.lua/lua/fzy/quicksort.lua',
    lnum = 15,
    text = '5: print(formatting .. v) ',
  },
  {
    col = 31,
    filename = github .. 'guihua.lua/lua/fzy/quicksort.lua',
    uri = 'file:///' .. github .. 'guihua.lua/lua/fzy/quicksort.lua',
    lnum = 9,
    text = "6:   if type(v) == 'table' then ",
  },
}

local on_confirm = function(item)
  log('confirm open', item.filename, item.uri)
  open_file_at(item.filename, item.lnum, item.col)
end

local on_move = function(item)
  log('pos:', item.text or item, item.uri)
  -- todo fix
  return preview_uri(item.uri, item.lnum, 6)
  -- test(false)
end

local function test_list()
  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')

  local win = ListView:new({
    loc = 'top_center',
    border = 'none',
    prompt = true,
    enter = true,
    rect = { height = 5, width = 90 },
    data = data,
    on_confirm = on_confirm,
    on_move = on_move,
  })
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:on_draw({})
  -- win:set_pos(1)
end

local function test_list_mask()
  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')

  local win = ListView:new({
    loc = 'top_center',
    border = 'none',
    prompt = true,
    enter = true,
    rect = { height = 5, width = 90 },
    data = data,
    transparency = 60,
    on_confirm = on_confirm,
    on_move = on_move,
  })
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:on_draw({})
  -- win:set_pos(1)
end

local function test_preview()
  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')
  local win = ListView:new({
    loc = 'top_center',
    prompt = true,
    rect = { height = 4, width = 90 },
    data = lines,
    on_confirm = on_confirm,
    on_move = on_move,
  })
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:on_draw({})
  win:set_pos(1)
end

local function test_render_list()
  local items = {
    {
      col = 9,
      filename = github .. 'guihua.lua/lua/fzy/original.lua',
      display_filename = './lua/fzy/original.lua',
      lnum = 59,
      range = { start = { character = 8, line = 58 } },
      text = ' local match_bonus = {}',
      uri = 'file://' .. github .. 'guihua.lua/lua/fzy/original.lua',
    },
    {
      col = 7,
      filename = github .. 'guihua.lua/lua/fzy/original.lua',
      display_filename = './lua/fzy/original.lua',
      lnum = 65,
      range = { start = { character = 6, line = 64 } },
      text = '      match_bonus[i] = SCORE_MATCH_SLASH',
      uri = 'file://' .. github .. 'guihua.lua/lua/fzy/original.lua',
    },
    {
      col = 10,
      filename = github .. 'guihua.lua/lua/guihua/listview.lua',
      display_filename = './lua/guihua/listview.lua',
      lnum = 79,
      range = { start = { character = 9, line = 78 } },
      text = '  return match_bonus',
      uri = 'file://' .. github .. 'guihua.lua/lua/fzy/original.lua',
    },
  }
  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')

  local d = prepare_for_render(items)
  log(d)
  local win = ListView:new({
    loc = 'top_center',
    border = 'none',
    prompt = true,
    enter = true,
    rect = { height = 5, width = 90 },
    data = d,
    on_confirm = on_confirm,
    on_move = on_move,
  })
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:on_draw({})
  -- win:set_pos(1)
end

local function test_list_one_item()
  data = {
    {
      detail = 'func',
      filename = gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
      kind = 12,
      lnum = 19,
      name = 'main',
      range = { ['end'] = { character = 1, line = 78 }, start = { character = 0, line = 18 } },
      selectionRange = { ['end'] = { character = 9, line = 18 }, start = { character = 5, line = 18 } },
      text = '[ ]main func',
      uri = 'file://' .. gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
    },
  }
  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')

  local d = prepare_for_render(data)
  data = d
  local win = ListView:new({
    loc = 'top_center',
    border = 'none',
    prompt = false,
    rect = { height = 5, width = 90 },
    data = d,
    on_confirm = on_confirm,
    on_move = on_move,
  })
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:on_draw({})
  -- win:set_pos(1)
end

local function test_list_one_item_symbol()
  data = {
    {
      detail = 'func',
      filename = gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
      kind = 12,
      lnum = 18,
      name = 'main',
      range = { ['end'] = { character = 1, line = 77 }, start = { character = 0, line = 17 } },
      selectionRange = { ['end'] = { character = 9, line = 17 }, start = { character = 5, line = 17 } },
      text = '[ ]main func',
      uri = 'file://' .. gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
    },
  }
  -- data = prepare_for_render(data)
  log(data)

  local opt = {
    api = ' ',
    bg = 'GuihuaListDark',
    data = data,
    enter = true,
    ft = 'go',
    loc = 'top_center',
    prompt = true,
    on_confirm = on_confirm,
    on_move = on_move,
    rect = { height = 1, pos_x = 0, pos_y = 0, width = 120 },
  }

  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')

  local win = ListView:new(opt)
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  -- win:set_pos(1)
end

local function test_list_two_item_symbol()
  local opt = {
    api = ' ',
    bg = 'GuihuaListDark',
    data = {
      {
        detail = 'func',
        filename = gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
        kind = 12,
        lnum = 18,
        name = 'main',
        range = { ['end'] = { character = 1, line = 77 }, start = { character = 0, line = 17 } },
        selectionRange = { ['end'] = { character = 9, line = 17 }, start = { character = 5, line = 17 } },
        text = '[ ]main func',
        uri = 'file://' .. gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
      },
      {
        detail = 'func',
        filename = gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
        kind = 12,
        lnum = 18,
        name = 'main',
        range = { ['end'] = { character = 1, line = 77 }, start = { character = 0, line = 17 } },
        selectionRange = { ['end'] = { character = 9, line = 17 }, start = { character = 5, line = 17 } },
        text = '[ ]main func',
        uri = 'file://' .. gopath .. '/src/github.com/Shopify/sarama/examples/consumergroup/main.go',
      },
    },
    enter = true,
    ft = 'go',
    loc = 'top_center',
    prompt = true,
    on_confirm = on_confirm,
    on_move = on_move,
    rect = { height = 2, pos_x = 0, pos_y = 0, width = 120 },
  }
end

local function test_list_page()
  local opt = {
    api = ' ',
    bg = 'GuihuaListDark',
    data = data,
    enter = true,
    ft = 'go',
    loc = 'top_center',
    transparency = 50,
    prompt = true,
    on_confirm = on_confirm,
    on_move = on_move,
    -- external = true,
    rect = { height = 2, pos_x = 0, pos_y = 0, width = 120 },
  }

  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')

  local win = ListView:new(opt)
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  win:on_draw({})
  -- win:set_pos(1)
end

local function test_list_page_customer_filter()
  local height = 15
  local bufnr = vim.api.nvim_get_current_buf()
  data = { { text = '' } }
  for i = 1, height do
    table.insert(data, { text = '' })
  end
  local opt = {
    api = ' ',
    bg = 'GuihuaListDark',
    data = data,
    enter = true,
    ft = 'go',
    loc = 'top_center',
    transparency = 50,
    prompt = true,
    on_confirm = on_confirm,
    on_input_filter = function(text)
      -- log('on_input_filter', text)
      -- print(text)

      local params = { query = text or '#' }
      local new_result = vim.lsp.buf_request_sync(bufnr, 'workspace/symbol', params)
      local new_locations = {}
      log(vim.inspect(new_result[1].result))
      local r = new_result[1].result
      new_result = { { result = util.dedup(r, 'name', 'kind') } }
      for _, server_results in pairs(new_result or {}) do
        if server_results.result then
          --[[
{{result={{ kind = 8, location = { range = { end = { character = 61, line = 463 }, start = { character = 52, line = 463 } }, uri = "file:///home/ray/github/dotfiles/nvim/lua/modules/ui/eviline.lua" }, name = "show_zero", range = { 4630054, 4630063 }
      },
      { kind = 8, location = { range = { end = { character = 12, line = 171 }, start = { character = 6, line = 171 } }, uri = "file:///home/ray/github/dotfiles/nvim/lua/modules/completion/plugins.lua" }, name = "zindex", range = { 1710006, 1710012 }
      } }
  } }
]]
          --
          vim.list_extend(new_locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
          --[[
           { { col = 3, filename = "/usr/local/share/nvim/runtime/lua/vim/filetype.lua", kind = "Field", lnum = 786, text = "[Field] zig" },
           { col = 3, filename = "/usr/local/share/nvim/runtime/lua/vim/filetype.lua", kind = "Field", lnum = 787, text = "[Field] zu" },
          ]]
          --
        end
      end
      log('new_locations', new_locations)
      -- print(vim.inspect(new_locations))
      return new_locations
    end,
    on_move = on_move,
    -- external = true,
    rect = { height = height, pos_x = 0, pos_y = 0, width = 120 },
  }

  -- vim.g.debug_trace_output = true
  package.loaded['guihua'] = nil
  package.loaded['guihua.view'] = nil
  package.loaded['guihua.viewctrl'] = nil
  package.loaded['guihua.listview'] = nil
  package.loaded['guihua.listviewctrl'] = nil
  -- package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd('packadd guihua.lua')

  local win = ListView:new(opt)
  -- log("test", win)
  -- vim.cmd("startinsert!")
  -- vim.cmd("normal! zvzb")
  win:on_draw({})
  -- win:set_pos(1)
end

-- test_list()
-- test_list_mask()
-- test_textview()

-- test_list_one_item_symbol()
-- test_list_page_customer_filter()
-- test_list_two_item_symbol()

-- test_plaintext()
-- test_preview()
