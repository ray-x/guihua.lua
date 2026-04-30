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
    }, function(item)
      choice = item
    end)

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
    }, function(_) end)
    local listview2 = gui.select({ 'alpha', 'beta', 'gamma' }, {
      prompt = 'Second select',
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
    local View = require('guihua.view')
    local choice1 = nil
    local choice2 = nil
    local listview1 = gui.select({ 'one', 'two', 'three' }, {
      prompt = 'First select',
    }, function(choice)
      choice1 = choice
    end)
    local listview2 = gui.select({ 'alpha', 'beta', 'gamma' }, {
      prompt = 'Second select',
    }, function(choice)
      choice2 = choice
    end)

    vim.api.nvim_set_current_win(listview1.win)
    vim.fn.maparg('<CR>', 'n', false, true).callback()

    eq('one', choice1)
    eq(nil, choice2)
    assert.is_true(listview1.win == nil or not vim.api.nvim_win_is_valid(listview1.win))
    assert.is_true(vim.api.nvim_win_is_valid(listview2.win))
    eq(listview2, View.ActiveView)

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
    local View = require('guihua.view')
    local listview1 = gui.select({ 'one', 'two', 'three' }, {
      prompt = 'First select',
    }, function(_) end)
    local ctrl1 = listview1:get_ctrl()

    ctrl1:on_leave()
    ctrl1:on_close()

    local listview2 = gui.select({ 'alpha', 'beta', 'gamma' }, {
      prompt = 'Second select',
    }, function(_) end)

    vim.wait(20)

    assert.is_true(vim.api.nvim_win_is_valid(listview2.win))
    eq(listview2, View.ActiveView)

    listview2:close()
  end)
end)
