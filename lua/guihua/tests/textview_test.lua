package.loaded['guihua'] = nil
package.loaded['guihua.view'] = nil
package.loaded['guihua.viewctrl'] = nil
package.loaded['guihua.textview'] = nil
package.loaded['guihua.listviewctrl'] = nil
vim.cmd('packadd guihua.lua')

local TextView = require('guihua.textview')
local log = require('guihua.log').info
--package.loaded.packer_plugins['guihua.lua'].loaded = false
local function test_fixed(enter)
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
  -- vim.cmd("startinsert!")
end

local function test_relative()
  local data = {
    "local Rect2 = require 'guihua.rect'",
    "local class2 = require'middleclass'",
    'local a2 = 32',
    "local b2 = 'abcdef'",
  }
  local win = TextView:new({
    relative = 'cursor',
    syntax = 'lua',
    rect = { height = 5, pos_x = 0, pos_y = 10 },
    data = data,
  })
  log('draw data', data)
  win:on_draw(data)
  -- vim.cmd("startinsert!")
end

local function test_multi()
  test_fixed()
  test_relative()
end

local signature = {
  activeParameter = 1,
  activeSignature = 0,
  signatures = {
    {
      documentation = [[Date returns the Time corresponding to\n\tyyyy-mm-dd hh:mm:ss + nsec nanoseconds\nin the appropriate zone for that time in the given location.\n\nThe month,
 day, hour, min, sec, and nsec values may be outside\ntheir usual ranges and will be normalized during the conversion.\nFor example, October 32 converts to November 1.\n\nA daylig
ht savings time transition skips or repeats times.\nFor example, in the United States, March 13, 2011 2:15am never occurred,\nwhile November 6, 2011 1:15am occurred twice. In such
 cases, the\nchoice of time zone, and therefore the time, is not well-defined.\nDate returns a time that is correct in one of the two zones involved\nin the transition, but it doe
s not guarantee which.\n\nDate panics if loc is nil.\n]],
      label = 'Date(year int, month time.Month, day int, hour int, min int, sec int, nsec int, loc *time.Location) time.Time',
      parameters = {
        {
          label = 'year int',
        },
        {
          label = 'month time.Month',
        },
        {
          label = 'day int',
        },
        {
          label = 'hour int',
        },
        {
          label = 'min int',
        },
        {
          label = 'sec int',
        },
        {
          label = 'nsec int',
        },
        {
          label = 'loc *time.Location',
        },
      },
    },
  },
}

local function test_signature()
  lines = { signature.signatures[1].label }
  local i = 1
  local doc = ''
  local util = require('vim.lsp.util')
  for s in signature.signatures[1].documentation:gmatch('[^\r\n]+') do
    s = vim.trim(s:gsub('[\t]', '  '))
    doc = doc .. s
    i = i + 1
  end
  doc = '/*' .. doc .. '*/'
  table.insert(lines, doc)
  local data = lines
  local win = TextView:new({
    relative = 'cursor',
    syntax = 'go',
    rect = { height = 5, pos_x = 0, pos_y = 10 },
    data = data,
  })
  log('draw data', data)
  win:on_draw(data)
  -- vim.cmd("startinsert!")
end

local function test_filepreview()
  local fname = vim.fn.expand('%:p:h') .. '/listview_spec.lua'
  local uri = vim.uri_from_fname(fname)
  local range = {
    ['end'] = {
      character = 46,
      line = 16,
    },
    start = {
      character = 40,
      line = 4,
    },
  }
  local opts = {
    relative = 'cursor',
    syntax = 'lua',
    rect = { height = 5, pos_x = 0, pos_y = 10,width=60 },
    uri = uri,
    range = range,
    edit = true,
  }

  local win = TextView:new(opts)
  log('draw data', opts)
  win:on_draw(opts)
  -- vim.cmd("startinsert!")
end

-- test_signature()
-- test_fixed(false)
-- test_relative()

-- test_multi()

test_filepreview()

-- signature
-- [[ --]]
