local eq = assert.are.same

describe('diffview', function()
  local function title_text(title)
    if type(title) == 'string' then
      return title
    end
    if type(title) ~= 'table' then
      return ''
    end
    local parts = {}
    for _, chunk in ipairs(title) do
      if type(chunk) == 'table' then
        table.insert(parts, chunk[1] or '')
      else
        table.insert(parts, tostring(chunk))
      end
    end
    return table.concat(parts)
  end

  it('should render unified diff hunks with delta-style highlights', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.diffview'] = nil
    package.loaded['guihua.textview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local diff = table.concat({
      'diff --git a/demo.lua b/demo.lua',
      'index 1111111..2222222 100644',
      '--- a/demo.lua',
      '+++ b/demo.lua',
      '@@ -1,3 +1,3 @@',
      '-local foo = "bar"',
      '+local foo = "baz"',
      ' local keep = true',
    }, '\n')

    local view = gui.diffview({
      title = 'Demo diff',
      description = 'update foo',
      diff = diff,
      syntax = 'lua',
    })

    local buf = vim.api.nvim_win_get_buf(view.win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq('update foo', lines[1])
    eq('', lines[2])
    assert.is_true(vim.tbl_contains(lines, 'local foo = "bar"'))
    assert.is_true(vim.tbl_contains(lines, 'local foo = "baz"'))
    assert.is_true(vim.tbl_contains(lines, 'local keep = true'))

    local ns = vim.api.nvim_get_namespaces()['guihua_diffview']
    assert.is_not_nil(ns)
    local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
    local has_delete, has_add, has_change = false, false, false
    local has_title, has_comment = false, false
    for _, mark in ipairs(extmarks) do
      local details = mark[4] or {}
      if details.hl_group == 'Title' then
        has_title = true
      end
      if details.hl_group == 'Comment' then
        has_comment = true
      end
      if details.sign_text == '-' or details.line_hl_group == 'GuihuaDiffDelete' then
        has_delete = true
      end
      if details.sign_text == '+' or details.line_hl_group == 'GuihuaDiffAdd' then
        has_add = true
      end
      if details.hl_group == 'GuihuaDiffChange' then
        has_change = true
      end
    end

    assert.is_true(has_title)
    assert.is_true(has_comment)
    assert.is_true(has_delete)
    assert.is_true(has_add)
    assert.is_true(has_change)

    vim.api.nvim_win_close(view.win, true)
  end)

  it('should show the close keymap in the title and bind it in the buffer', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.diffview'] = nil
    package.loaded['guihua.textview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local view = gui.diffview({
      title = 'Demo diff',
      close_keymap = '<C-x>',
      diff = 'diff --git a/a b/a\n--- a/a\n+++ b/a\n@@ -1 +1 @@\n-a\n+b',
      syntax = 'lua',
    })

    local cfg = vim.api.nvim_win_get_config(view.win)
    local title = title_text(cfg.title)
    assert.is_truthy(title:find('Demo diff', 1, true))
    assert.is_truthy(title:find('<C-x>', 1, true))
    assert.is_nil(title:find('Auto', 1, true))
    assert.is_nil(title:find('Close', 1, true))

    local maps = vim.api.nvim_buf_get_keymap(view.buf, 'n')
    local has_map = false
    for _, map in ipairs(maps) do
      if map.lhs == '<C-X>' or map.lhs == '<C-x>' then
        has_map = true
        break
      end
    end
    assert.is_true(has_map)

    vim.api.nvim_win_close(view.win, true)
  end)

  it('should autoclose when focus moves away', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.diffview'] = nil
    package.loaded['guihua.textview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local view = gui.diffview({
      title = 'Demo diff',
      autoclose = { events = { 'WinLeave' } },
      enter = true,
      diff = 'diff --git a/a b/a\n--- a/a\n+++ b/a\n@@ -1 +1 @@\n-a\n+b',
      syntax = 'lua',
    })

    vim.cmd('new')
    local other_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(other_win)
    vim.wait(50)

    assert.is_true(view.win == nil or not vim.api.nvim_win_is_valid(view.win))

    if vim.api.nvim_win_is_valid(other_win) then
      vim.api.nvim_win_close(other_win, true)
    end
  end)

  it('should autoclose after the timeout', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.diffview'] = nil
    package.loaded['guihua.textview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local view = gui.diffview({
      title = 'Demo diff',
      autoclose = { timeout = 20 },
      diff = 'diff --git a/a b/a\n--- a/a\n+++ b/a\n@@ -1 +1 @@\n-a\n+b',
      syntax = 'lua',
    })

    vim.wait(100)

    assert.is_true(view.win == nil or not vim.api.nvim_win_is_valid(view.win))
  end)
end)

-- Sample API call:
-- require('guihua.gui').diffview({
--   title = 'My diff',
--   description = 'Review changes to demo.lua',
--   syntax = 'lua',
--   close_keymap = '<C-x>',
--   autoclose = { events = { 'WinLeave' }, timeout = 5000 },
--   diff = [[
-- diff --git a/demo.lua b/demo.lua
-- --- a/demo.lua
-- +++ b/demo.lua
-- @@ -1,2 +1,2 @@
-- -local foo = "bar"
-- +local foo = "baz"
-- ]],
-- })
