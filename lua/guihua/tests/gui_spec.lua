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

  it('should lazy load top-level guihua exports', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.view'] = nil
    package.loaded['guihua.listview'] = nil
    vim.cmd('packadd guihua.lua')

    local guihua = require('guihua')

    assert.is_nil(package.loaded['guihua.view'])
    assert.is_nil(package.loaded['guihua.listview'])

    local view = guihua.view

    assert.is_not_nil(view)
    assert.is_not_nil(package.loaded['guihua.view'])
    assert.is_nil(package.loaded['guihua.listview'])
  end)

  it('should lazy load gui submodules until used', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.textview'] = nil
    package.loaded['guihua.input'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')

    assert.is_nil(package.loaded['guihua.listview'])
    assert.is_nil(package.loaded['guihua.textview'])
    assert.is_nil(package.loaded['guihua.input'])

    local input_win = gui.input({
      prompt = 'Rename',
      placeholder = 'target',
    }, function(_) end)

    assert.is_not_nil(package.loaded['guihua.input'])
    assert.is_nil(package.loaded['guihua.listview'])
    assert.is_nil(package.loaded['guihua.textview'])

    vim.api.nvim_win_close(input_win, true)
  end)

  it('should restore focus for select popup after focus changes', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')
    vim.cmd('new')
    local other_win = vim.api.nvim_get_current_win()

    local listview = require('guihua.gui').select({ 'tabs', 'spaces', 'enter' }, {
      prompt = 'Select tabs or spaces',
      ft = 'guihua',
    }, function(_) end)

    local ctrl = listview:get_ctrl()
    local popup_win = listview.win

    assert.is_true(vim.api.nvim_win_is_valid(popup_win))
    assert.is_true(vim.api.nvim_win_is_valid(other_win))
    assert.are_not.same(popup_win, other_win)
    vim.api.nvim_clear_autocmds({ group = ctrl.augroup })
    vim.api.nvim_set_current_win(other_win)
    eq(other_win, vim.api.nvim_get_current_win())

    ctrl:on_focus_gained(listview.buf)
    eq(popup_win, vim.api.nvim_get_current_win())

    vim.api.nvim_win_close(other_win, true)
    listview:close()
  end)

  it('should keep select popup open when input popup opens', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.input'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local listview = gui.select({ 'tabs', 'spaces', 'enter' }, {
      prompt = 'Select tabs or spaces',
      ft = 'guihua',
    }, function(_) end)
    local ctrl = listview:get_ctrl()
    local select_win = listview.win
    local input_win = gui.input({
      prompt = 'Rename',
      placeholder = 'target',
    }, function(_) end)

    assert.is_true(vim.api.nvim_win_is_valid(select_win))
    assert.is_true(vim.api.nvim_win_is_valid(input_win))

    eq(1, ctrl.selected_line)
    vim.api.nvim_set_current_win(select_win)
    ctrl:on_prev()
    eq(1, ctrl.selected_line)

    vim.api.nvim_win_close(input_win, true)
    listview:close()
  end)

  it('should disable strikethrough in select popups only', function()
    if vim.api.nvim_win_get_hl_ns == nil or vim.api.nvim_get_hl == nil then
      return
    end
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    vim.api.nvim_set_hl(0, '@markup.strikethrough', { fg = 0xabcdef, strikethrough = true })

    local gui = require('guihua.gui')
    local listview = gui.select({ 'one', 'two', 'three' }, {
      prompt = 'Select ~~value~~',
      ft = 'markdown',
    }, function(_) end)

    local ns = vim.api.nvim_win_get_hl_ns(listview.win)
    local hl = vim.api.nvim_get_hl(ns, { name = '@markup.strikethrough', link = false })

    eq(0xabcdef, hl.fg)
    assert.is_not_true(hl.strikethrough)

    listview:close()
  end)

  it('should disable strikethrough in input popups only', function()
    if vim.api.nvim_win_get_hl_ns == nil or vim.api.nvim_get_hl == nil then
      return
    end
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.input'] = nil
    vim.cmd('packadd guihua.lua')

    vim.api.nvim_set_hl(0, '@markup.strikethrough', { fg = 0x123456, strikethrough = true })

    local input_win = require('guihua.gui').input({
      prompt = 'Rename ~~value~~',
      placeholder = 'target',
    }, function(_) end)

    local ns = vim.api.nvim_win_get_hl_ns(input_win)
    local hl = vim.api.nvim_get_hl(ns, { name = '@markup.strikethrough', link = false })

    eq(0x123456, hl.fg)
    assert.is_not_true(hl.strikethrough)

    vim.api.nvim_win_close(input_win, true)
  end)

  it('should expand input popups for long text instead of clipping the tail', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.input'] = nil
    vim.cmd('packadd guihua.lua')

    local long_text = string.rep('segment/', 20) .. 'file.lua'
    local input_win = require('guihua.gui').input({
      prompt = 'Rename',
      placeholder = long_text,
      width = 20,
    }, function(_) end)

    local cfg = vim.api.nvim_win_get_config(input_win)
    local buf = vim.api.nvim_win_get_buf(input_win)
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]

    assert.is_true(cfg.height > 1)
    assert.is_true(vim.api.nvim_get_option_value('wrap', { win = input_win }))
    assert.is_truthy(line:find(long_text, 1, true))

    vim.api.nvim_win_close(input_win, true)
  end)

  it('should pass multiline input content to the callback', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.input'] = nil
    vim.cmd('packadd guihua.lua')

    local captured = nil
    local input_win = require('guihua.gui').input({
      prompt = 'Rename',
      placeholder = '',
    }, function(text)
      captured = text
    end)

    local buf = vim.api.nvim_win_get_buf(input_win)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { ' first line', 'second line' })
    vim.api.nvim_set_current_win(input_win)
    vim.fn.maparg('<CR>', 'n', false, true).callback()

    eq('first line\nsecond line', captured)
  end)

  it('should preselect the first item when prompt text is rendered in the popup', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local choice = nil
    local gui = require('guihua.gui')
    local listview = gui.select({ 'one', 'two', 'three' }, {
      prompt = 'Select the first item from this popup even when the prompt is long enough to wrap into the popup body.',
      ft = 'guihua',
    }, function(item)
      choice = item
    end)

    vim.wait(20)
    eq(listview:get_ctrl().state:cursor_line(), vim.api.nvim_win_get_cursor(listview.win)[1])
    vim.api.nvim_set_current_win(listview.win)
    vim.fn.maparg('<CR>', 'n', false, true).callback()

    eq('one', choice)
  end)

  it('should keep concurrent select popups independent', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local listview1 = gui.select({ 'one', 'two', 'three' }, {
      prompt = 'First select',
      ft = 'guihua',
    }, function(_) end)
    local listview2 = gui.select({ 'alpha', 'beta', 'gamma' }, {
      prompt = 'Second select',
      ft = 'guihua',
    }, function(_) end)

    local ctrl1 = listview1:get_ctrl()
    local ctrl2 = listview2:get_ctrl()
    local ctrl1_line = ctrl1.selected_line
    local ctrl2_line = ctrl2.selected_line

    eq(1, ctrl1_line)
    eq(1, ctrl2_line)

    assert.is_true(vim.api.nvim_win_is_valid(listview1.win))
    assert.is_true(vim.api.nvim_win_is_valid(listview2.win))

    ctrl1:on_next()
    eq(ctrl1_line + 1, ctrl1.selected_line)
    eq(ctrl2_line, ctrl2.selected_line)

    ctrl2:on_next()
    eq(ctrl1_line + 1, ctrl1.selected_line)
    eq(ctrl2_line + 1, ctrl2.selected_line)

    listview1:close()
    listview2:close()
  end)

  it('should confirm the first select popup while another select is open', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local SessionRegistry = require('guihua.session_registry')
    local choice1 = nil
    local choice2 = nil
    local listview1 = gui.select({ 'one', 'two', 'three' }, {
      prompt = 'First select',
      ft = 'guihua',
    }, function(choice)
      choice1 = choice
    end)
    local listview2 = gui.select({ 'alpha', 'beta', 'gamma' }, {
      prompt = 'Second select',
      ft = 'guihua',
    }, function(choice)
      choice2 = choice
    end)

    vim.api.nvim_set_current_win(listview1.win)
    vim.fn.maparg('<CR>', 'n', false, true).callback()

    eq('one', choice1)
    eq(nil, choice2)
    assert.is_true(listview1.win == nil or not vim.api.nvim_win_is_valid(listview1.win))
    assert.is_true(vim.api.nvim_win_is_valid(listview2.win))
    eq(listview2, SessionRegistry.get_active().list_view)

    listview2:close()
  end)

  it('should not clear active view from a stale deferred leave', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.gui'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.view'] = nil
    vim.cmd('packadd guihua.lua')

    local gui = require('guihua.gui')
    local SessionRegistry = require('guihua.session_registry')
    local listview1 = gui.select({ 'one', 'two', 'three' }, {
      prompt = 'First select',
      ft = 'guihua',
    }, function(_) end)
    local ctrl1 = listview1:get_ctrl()

    ctrl1:on_leave()
    ctrl1:on_close()

    local listview2 = gui.select({ 'alpha', 'beta', 'gamma' }, {
      prompt = 'Second select',
      ft = 'guihua',
    }, function(_) end)

    vim.wait(20)

    assert.is_true(vim.api.nvim_win_is_valid(listview2.win))
    eq(listview2, SessionRegistry.get_active().list_view)

    listview2:close()
  end)

  it('should close the preview when the listview closes', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.view'] = nil
    package.loaded['guihua.viewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.textview'] = nil
    vim.cmd('packadd guihua.lua')

    local ListView = require('guihua.listview')
    local TextView = require('guihua.textview')
    local SessionRegistry = require('guihua.session_registry')
    local original_win = vim.api.nvim_get_current_win()
    local listview = ListView:new({
      loc = 'top_center',
      border = 'none',
      prompt = false,
      rect = { height = 2, width = 40 },
      data = {
        {
          text = 'only item',
        },
      },
      on_confirm = function(_) end,
      on_move = function(_)
        return TextView:new({
          loc = 'top_center',
          rect = { height = 2, width = 20 },
          data = { 'preview line' },
        })
      end,
    })

    local ctrl = listview:get_ctrl()
    ctrl:on_prev()

    local preview = TextView.ActiveTextView
    assert.is_true(preview ~= nil)
    assert.is_true(vim.api.nvim_win_is_valid(preview.win))

    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    vim.api.nvim_win_close(listview.win, true)
    vim.wait(20)
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end

    assert.is_true(listview.win == nil or not vim.api.nvim_win_is_valid(listview.win))
    assert.is_true(preview.win == nil or not vim.api.nvim_win_is_valid(preview.win))
    assert.is_true(TextView.ActiveTextView == nil or TextView.ActiveTextView.win == nil)
  end)

  it('should close a reused preview when the listview closes from the second item', function()
    package.loaded['guihua'] = nil
    package.loaded['guihua.view'] = nil
    package.loaded['guihua.viewctrl'] = nil
    package.loaded['guihua.listview'] = nil
    package.loaded['guihua.listviewctrl'] = nil
    package.loaded['guihua.textview'] = nil
    vim.cmd('packadd guihua.lua')

    local ListView = require('guihua.listview')
    local TextView = require('guihua.textview')
    local SessionRegistry = require('guihua.session_registry')
    local original_win = vim.api.nvim_get_current_win()
    local listview = ListView:new({
      loc = 'top_center',
      border = 'none',
      prompt = true,
      enter = true,
      ft = 'go',
      rect = { height = 2, width = 40 },
      data = {
        { text = 'one' },
        { text = 'two' },
      },
      on_confirm = function(_) end,
      on_move = function(item)
        return TextView.preview_spec({
          loc = 'top_center',
          rect = { height = 3, width = 20 },
          data = { 'local x = 1', item.text },
          syntax = 'lua',
        })
      end,
    })

    local ctrl = listview:get_ctrl()
    ctrl:on_item(1)
    local first_preview = SessionRegistry.get(listview.session.id).preview_view
    ctrl:on_item(2)

    local preview = SessionRegistry.get(listview.session.id).preview_view
    eq(first_preview, preview)
    assert.is_true(preview ~= nil)
    assert.is_true(vim.api.nvim_win_is_valid(preview.win))

    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    vim.api.nvim_win_close(listview.win, true)
    vim.wait(20)
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end

    assert.is_true(preview.win == nil or not vim.api.nvim_win_is_valid(preview.win))
    assert.is_true(TextView.ActiveTextView == nil or TextView.ActiveTextView.win == nil)
  end)
end)
