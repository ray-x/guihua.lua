local eq = assert.are.same

local busted = require('plenary/busted')
local cur_dir = vim.fn.expand('%:p:h')

describe('should create view  ', function()
  package.loaded['guihua.lua'] = nil

  vim.cmd('packadd guihua.lua')
  -- require("luakit._load")
  it('should construct a float win ', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    -- package.loaded.packer_plugins['guihua.lua'].loaded = false
    vim.cmd('packadd guihua.lua')
    local uri = 'file://' .. vim.fn.expand('%:p')
    local range = {
      ['end'] = {
        line = 16,
      },
      start = {
        line = 16,
      },
    }

    local opts = {
      relative = 'cursor',
      loc = 'none',
      uri = uri,
      lnum = range.start.line,
      height = 5,
      range = range,
      width = 60,
      edit = true,
    }

    local view = require('guihua.gui').preview_uri(opts)
    print(view.buf)
  end)
end)
