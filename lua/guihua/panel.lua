local class = require('middleclass')

local log = require('guihua.log').info
local trace = require('guihua.log').trace
local utils = require('guihua.util')
local vfn = vim.fn
local api = vim.api
local skip_buf_types = { 'quickfix', 'nofile', 'terminal', 'prompt', 'help', 'vista' }
local TextView = require('guihua.textview')
local panel_icons
local syntax_icons
if Panel == nil then
  Panel = class('Panel')
end

local function _make_window_name(tabpage)
  return '__guihua__win_(' .. tabpage .. ')'
end
local sep = '────'
local function _make_augroup_name(tabpage)
  return '__guihua__aug_' .. tabpage .. ''
end

local active_windows = {}
local tabs = {}

local function entry_prefix(node, is_last_node)
  local prefix = ''
  local idl = node.indent_level
  if not idl or idl < 1 then
    log('indent level < 1')
    idl = 1
  end
  if is_last_node or idl == 1 then
    prefix = string.rep(' ', (idl - 1) * 2) .. panel_icons.outer_node .. ' '
  else
    prefix = string.rep(' ', (idl - 1) * 2) .. panel_icons.inner_node .. ' '
  end
  return prefix
end

local function func_type(node)
  if node.type == 'function' or node.type == 'method' or node.kind == 12 or node.kind == 5 or node.kind == 6 then
    return true
  end
end

local function format_node(node, section)
  local is_last_node = false
  local last_leave_node = false
  trace(node)
  if not node.next_indent_level then
    is_last_node = true
  elseif node.indent_level ~= node.next_indent_level then
    is_last_node = true
    if node.indent_level > node.next_indent_level then
      last_leave_node = true
    end
  end
  last_leave_node = last_leave_node and nil -- true/nil-> nil, false -> false
  local str = entry_prefix(node, is_last_node)
  str = str .. panel_icons.bracket_left .. (syntax_icons[node.type] or node.type or '') .. panel_icons.bracket_right
  str = str .. ' ' .. (node.node_text or node.text or '')
  if node.node_text == nil and node.text == nil then
    log('node text is empty', node)
  end

  local scope = ''
  if section and section.scope and node[section.scope] then
    if func_type(node) then
      local s = node[section.scope]['start'].line
      local e = node[section.scope]['end'].line
      if s and e then
        scope = ' ' .. panel_icons.range_left .. s + 1 .. '-' .. e + 1 .. panel_icons.range_right
      end
    end
  end
  if node.lnum then
    str = str .. ' ' .. panel_icons.line_num_left .. tostring(node.lnum) .. panel_icons.line_num_right .. scope
  end
  trace('format:', str)
  return str
end

function Panel:initialize(opts)
  -- This holds a mapping from a dict[buffer_id --> dict[line_nr --> cursor_position]]

  self.per_buffer_jump_info = {}
  self.last_parsed_buf = -1
  self.width = opts.width or 35
  self.sections = self.sections or {}
  self.icons = {}
  self.icons.panel_icons = opts.panel_icons
    or {
      section_separator = '─', --'',
      line_num_left = ':', --'',
      line_num_right = '', --',

      range_left = '', --'',
      range_right = '',
      inner_node = '', --├○',
      folded = '◉',
      unfolded = '○',

      outer_node = '', -- '╰○',
      bracket_left = '', -- ⟪',
      bracket_right = '', -- '⟫',
    }
  panel_icons = self.icons.panel_icons
  self.icons.syntax_icons = opts.syntax_icons
    or {
      var = ' ', -- "👹", -- Vampaire
      method = 'ƒ ', --  "🍔", -- mac
      ['function'] = ' ', -- "🤣", -- Fun
      parameter = '  ', -- Pi
      associated = '🤝',
      namespace = '🚀',
      type = ' ',
      field = '🏈',
      interface = '蘒',
      module = '📦',
      flag = '🎏',
    }
  syntax_icons = self.icons.syntax_icons
  -- set_highlights(self.icons)

  self:add_section(opts)
  self.ft = vim.o.ft
  Panel.activePanel = self
  trace('panel created', Panel)
  return self
  -- run_on_buf_enter()
end

local genheader = function(opt)
  local sepr = panel_icons.section_separator
  local width = opt.width or 35
  local text = opt.header or 'outline'
  local side_size = math.floor((width - #text) / 2)
  return { string.rep(sepr, side_size) .. text .. string.rep(sepr, side_size) }
end

function Panel:add_section(opts)
  table.insert(self.sections, {
    nodes = opts.items,
    header = genheader(opts),
    format = opts.format or format_node,
    render = opts.render,
    fold = opts.fold,
    scope = opts.scope,
    on_confirm = opts.on_confirm, -- on_confirm must return true/false to indicate success
  })
end

function Panel:animate_create(animate, fast)
  -- Smoothly expand window width, contract a bit, and then expand to final size.
  local final_width = self.width
  animate = animate or false
  local widths = { final_width + 10, final_width + 7, final_width + 5 }
  local prev_w = 1
  local speed = 10
  local set_text_fn = function()
    -- Display matches
    local offset = 0
    if vim.api.nvim_buf_get_option(self.buf, 'filetype') ~= 'guihua' then
      return
    end
    if vim.api.nvim_buf_get_option(self.buf, 'modifiable') ~= false then
      return
    end
    for i, section in pairs(self.sections) do
      api.nvim_buf_set_option(self.buf, 'modifiable', true)
      api.nvim_buf_set_lines(self.buf, offset, offset + #section.header, false, section.header)
      offset = offset + #section.header
      api.nvim_buf_set_lines(self.buf, offset, offset + #section.text, false, section.text)
      offset = offset + #section.text
      -- Apparently this needs to be set after we insert text.
      api.nvim_buf_set_option(self.buf, 'modifiable', false)
      api.nvim_win_set_width(self.win, final_width)
      log('section rendered', i, section.header, #section.text)
    end
    -- Need this for smooth animation.
    api.nvim_command('redraw')
  end
  if not animate then
    return set_text_fn()
  end
  for i, target_w in pairs(widths) do
    local step_dir = -1
    if target_w > prev_w then
      step_dir = 1
    end
    for j = prev_w, target_w, step_dir do
      local new_width_fn = function()
        api.nvim_win_set_width(self.win, j)
        -- smooth animation.
        api.nvim_command('redraw')
      end
      vim.defer_fn(new_width_fn, speed)
    end
    prev_w = target_w
  end
  if fast then
    vim.defer_fn(function()
      api.nvim_buf_set_option(self.buf, 'modifiable', true)
      api.nvim_buf_set_lines(self.buf, 0, #fast, false, fast)
      api.nvim_buf_set_option(self.buf, 'modifiable', false)
    end, speed * 2)
  end

  vim.defer_fn(set_text_fn, speed * 3)
end

function Panel:get_jump_info()
  local line = api.nvim_get_current_line()
  if not self.activePanel then
    return
  end
  local scts = self.activePanel.sections
  for _, sct in pairs(scts) do
    if vfn.empty(sct.nodes) == 1 then
      log('no nodes', sct.header)
      return
    end
    for _, node in pairs(sct.nodes) do
      trace(node.text or node.node_text)
      log(node, sct.format(node), utils.trim(line))
      if utils.trim(sct.format(node)) == utils.trim(line) then
        log('node found', node.node_text, 'line', line)
        return node
      end
    end
    -- parcial match
    for _, node in pairs(sct.nodes) do
      -- log(node, sct.format(node), utils.trim(line))
      if utils.trim(line):find(utils.trim(sct.format(node))) then
        log('node found', node.node_text, 'line', line)
        return node
      end
    end
  end

  log('node not found', 'line', line)
  return nil
end

-- NB: Must be called from within guihua window.
local function add_keymappings(bufnr)
  bufnr = bufnr or 0
  -- jump to definition on <CR> or double-click
  api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', ':lua require "guihua.panel".jump_or_fold()<CR>', { silent = true })

  api.nvim_buf_set_keymap(
    bufnr,
    'n',
    '<2-LeftMouse>',
    ':lua require "guihua.panel".jump_or_fold()<CR>',
    { silent = true }
  )

  api.nvim_create_autocmd(
    { 'CursorHold', 'CursorHoldI' },
    { buffer = bufnr, command = ":lua require ('guihua.panel').on_hover()" }
  )

  api.nvim_create_autocmd(
    { 'CursorMoved', 'CursorMovedI', 'TabLeave', 'FocusLost', 'BufRead', 'BufEnter', 'BufUnload', 'BufLeave' },
    { buffer = bufnr, command = ":lua require ('guihua.panel').on_preview_close()" }
  )
end

local function filepreview(node)
  local uri = node.uri
  local range = node.range
  if not uri or not range then
    local ft = vim.api.nvim_buf_get_option(0, 'filetype')
    local hint = node.hint or node.text or node.node_text or node.name or 'unknown'
    if type(hint) == 'string' then
      hint = { hint }
    end
    vim.lsp.util.open_floating_preview(hint, ft, { border = 'single' })
    return
  end

  local opts = {
    relative = 'cursor',
    loc = 'none',
    uri = uri,
    lnum = node.lnum or (range.start and range.start.line) or nil,
    filetype = Panel.activePanel.ft,
    height = 5,
    range = range,
    width = 60,
    edit = true,
  }

  -- local win = TextView:new(opts)
  -- log('draw data', opts)
  -- win:on_draw(opts)
  return require('guihua.gui').preview_uri(opts)
end

-- Re-run guihua if buffer is written to using autocommands.
local function run_on_buf_write(buf)
  --Wrap autocmd in per-tabpage augroup to stop duplicate registration.
  local tabpage = api.nvim_get_current_tabpage()
  local augroup = _make_augroup_name(tabpage)
  vim.cmd('augroup ' .. augroup)
  api.nvim_create_autocmd({ 'BufWritePost' }, { buffer = buf, command = ":lua require ('guihua.panel').redraw(false)" })

  vim.cmd('augroup END')
end

-- Removes current tab from list of open tabs so we don't try to open guihua panel
-- when it has been closed.
function Panel:remove_tab(tabpage)
  tabs[tabpage] = nil
  local augroup = _make_augroup_name(tabpage)
  -- Delete all guihua panel autocommands set up for this tab.
  vim.cmd('augroup ' .. augroup)
  vim.cmd('au!')
  vim.cmd('augroup ' .. augroup)
end

function Panel:is_open()
  local tabpage = api.nvim_get_current_tabpage()
  return tabs[tabpage]
end

--If guihua buffer is being unloaded (either because someone opened a new file
--in our window or the window is being closed), let's close guihua for this
--tab.
function Panel:remove_tab_on_buf_leave()
  local tabpage = api.nvim_get_current_tabpage()
  Panel:remove_tab(tabpage)
end

-- Closes guihua window for current tabpage.
function Panel:close()
  local tabpage = api.nvim_get_current_tabpage()
  local win_name = _make_window_name(tabpage)
  if tabs[tabpage] then
    if active_windows[win_name] then
      Panel:remove_tab(tabpage)
      vim.api.nvim_win_close(active_windows[win_name], true)
      active_windows[win_name] = nil
    end
  end
  Panel.activePanel = nil
  Panel:remove_tab_on_buf_leave()
end

-- redraw if panel is open for the current tabpage and buffer can be parsed but
-- hasn't been.
function Panel:redraw(recreate)
  recreate = recreate or false
  if vim.bo.filetype == 'nofile' then
    log('redrawing ignored for ft', vim.bo.filetype)
    return
  end

  local buf = api.nvim_get_current_buf()
  log(vfn.expand('<afile>'), vfn.expand('<amatch>'), vfn.bufname(buf))

  local win = api.nvim_get_current_win()
  if Panel:is_open() then
    if recreate then
      Panel.activePanel:open(false, true, buf)
      api.nvim_set_current_win(win)
      return
    end
    if Panel.activePanel == nil then
      Panel:close()
    end
    if Panel.activePanel.last_parsed_buf ~= buf or vim.bo.filetype == 'guihua' then
      log('swap buffer')
      Panel.activePanel:open(false, true, buf)
      api.nvim_set_current_win(win)
    end
  end
end

local function run_on_buf_enter()
  local tabpage = api.nvim_get_current_tabpage()
  local augroup = _make_augroup_name(tabpage)
  vim.cmd('augroup ' .. augroup)

  api.nvim_create_autocmd({ 'BufEnter' }, { command = ":lua require ('guihua.panel').redraw(false)" })
  vim.cmd('augroup END')
end

local function close_on_buf_win_leave()
  local tabpage = api.nvim_get_current_tabpage()
  local augroup = _make_augroup_name(tabpage)
  vim.cmd('augroup ' .. augroup)
  local lua_callback_cmd = "lua require('guihua.panel').remove_tab_on_buf_leave()"
  local full_cmd = 'autocmd! ' .. augroup .. ' BufWinLeave <buffer> ' .. lua_callback_cmd
  vim.cmd(full_cmd)
  vim.cmd('augroup END')
end

local function make_panel_window(win_name)
  --local win_name = 'Guihua' .. tostring(api.nvim_get_current_buf())
  log('make_panel_window', win_name)
  api.nvim_command('keepalt botright vertical 1 split! ' .. win_name)
  local win = api.nvim_get_current_win()
  local buf = api.nvim_get_current_buf()

  --Disable wrapping
  api.nvim_win_set_option(win, 'wrap', false)
  api.nvim_win_set_option(win, 'list', false)
  api.nvim_win_set_option(win, 'number', false)
  api.nvim_win_set_option(win, 'relativenumber', false)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_win_set_option(win, 'wrap', false)
  vim.bo.buflisted = false
  vim.bo.modifiable = false
  vim.bo.textwidth = 0
  vim.bo.filetype = 'guihua'
  api.nvim_command('hi NonText guifg=bg')
  vim.wo.winfixwidth = true
  vim.wo.spell = false
  -- updateh followings? nolist, nowrap, breakindent?, number? nosigncolumn
  return win, buf
end

-- Searches current tabpage for a window containing buf.
local function find_win_for_buf(buf)
  local wins = api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(wins) do
    if api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
  return nil
end

function Panel:draw()
  -- log(self)
  local tabpage = api.nvim_get_current_tabpage()
  local win_name = _make_window_name(tabpage)
  if not active_windows[win_name] or vfn.win_id2win(active_windows[win_name]) == 0 then
    self.win, self.buf = make_panel_window(win_name)
    active_windows[win_name] = self.win
  else
    self.win = active_windows[win_name]
    api.nvim_set_current_win(self.win)
    self.buf = api.nvim_get_current_buf()
  end
  local header = self.header or { 'outline' }
  api.nvim_buf_set_option(self.buf, 'modifiable', true)
  api.nvim_buf_set_lines(self.buf, 0, #header, false, header)
  api.nvim_buf_set_lines(self.buf, 0, -1, false, {})
  api.nvim_buf_set_option(self.buf, 'modifiable', false)

  self:animate_create()
  add_keymappings(self.buf)
  --Track which windows we have been opened in.
  tabs[tabpage] = true
  return self.win, self.buf
end

function Panel.foldtext()
  local foldstart = vim.v.foldstart
  log('foldstart', foldstart)

  local line_count = vim.v.foldend - vim.v.foldstart + 1
  local line = api.nvim_buf_get_lines(0, foldstart - 1, foldstart, false)[1]
  local folded_icon = panel_icons.folded or ''
  line = ' ' .. folded_icon .. line .. ' ⚡' .. tostring(line_count)
  log(line, folded_icon)
  return line
end

local function get_indent_level(line)
  if not line then
    return 0
  end
  if string.find(line, sep) then
    return -1
  end
  local indent_level = string.match(line, '(%s*)')
  if indent_level == nil then
    log('failed to find indent level')
    return 1
  end
  return math.floor(#indent_level / 2) + 1
end

local function get_fold_context(line_num)
  local before = nil
  if line_num == 0 then
    before = nil
  else
    before = api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
  end
  local lines, _ = api.nvim_buf_get_lines(0, line_num, line_num + 2, false)
  return before, lines[1], lines[2]
end

function Panel.foldexpr()
  local line_num = vim.v.lnum - 1
  if line_num < 1 then
    return '0'
  end
  local before, line, after = get_fold_context(line_num)
  local before_indent = get_indent_level(before)
  local line_indent = get_indent_level(line)
  local after_indent = get_indent_level(after)
  -- section seperator etc
  local level
  -- grep seperator?
  if line_indent < 0 then
    level = '-1'
  elseif line == '' or before == '' or line_indent < 1 then
    log(line_num, line_indent, '0')
    level = '0'
  elseif line_indent == 1 or before_indent < line_indent then
    level = '>' .. tostring(line_indent)
  elseif after_indent <= 1 or after_indent < line_indent then
    level = '<' .. tostring(line_indent)
  elseif line_indent <= before_indent then
    level = tostring(line_indent)
  else
    log('unhandled case: ' .. line_num .. ' ' .. line_indent .. ' ' .. before_indent .. ' ' .. after_indent)
    level = '0'
  end

  -- log('ind: ', level, line_num, before, before_indent, line, line_indent, after, after_indent)
  -- log('ind: ', line_num, level, line, before_indent, line_indent, after_indent)
  return level
end

local function enable_folding()
  -- print('enable folding')
  vim.wo.foldtext = [[luaeval("require('guihua.panel').foldtext()")]]
  vim.wo.foldexpr = [[luaeval("require('guihua.panel').foldexpr()")]]
  vim.wo.foldmethod = 'expr'
  -- vim.wo.foldmethod = 'indent'
  -- vim.wo.foldcolumn = '2'
end

function Panel.jump_or_fold(fold)
  fold = fold or false
  local cursor_pos = api.nvim_win_get_cursor(0)
  local pos_y, pos_x = cursor_pos[1], cursor_pos[2]

  local line = api.nvim_get_current_line()
  local can_fold = string.find(line, panel_icons.folded)
  local spaces = get_indent_level(pos_y) * 2

  if can_fold or pos_x < spaces + 3 then
    Panel.fold()
  else
    Panel.jump_to_loc()
  end
end

function Panel.fold()
  local node = Panel:get_jump_info()
  if node == nil then
    return log('no node found')
  end
  for _, sct in pairs(Panel.activePanel.sections) do
    if sct.fold ~= nil then
      log('on_fold')
      if sct.fold(Panel.activePanel, node) then
        return true
      end
    end
  end

  log('fallback za')
  vim.cmd('silent! normal za')
end

function Panel.jump_to_loc()
  local node = Panel:get_jump_info()
  if node == nil then
    log('no jump info')
    return
  end
  if node.range == nil or node.lnum == nil then
    -- check if on_confirm is set
    log('incorrect node info to jump', node)
    for _, sct in pairs(Panel.activePanel.sections) do
      if sct.on_confirm ~= nil then
        log('on_confirm', node)
        if sct.on_confirm(node) then
          return
        end
      end
    end
  end
  node.range = node.range or { start = { character = 1 } }
  node.lnum = node.lnum or node.range.start.line or 1
  Panel.on_preview_close()
  local fileuri = node.uri
  local bufnr = vim.uri_to_bufnr(fileuri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vfn.bufload(bufnr)
  end
  local win = find_win_for_buf(bufnr)
  trace(node.range, node.lnum, win)
  if win then
    api.nvim_set_current_win(win)
    api.nvim_win_set_cursor(0, { node.lnum, node.range.start.character })
  else
    log('no win found for', fileuri)
  end
end

function Panel.on_hover()
  local node = Panel:get_jump_info()
  if node == nil then
    log('no hover info')
    return
  end
  Panel.on_preview_close()
  Panel.activePanel.preview_textview = filepreview(node)
end

function Panel.on_preview_close()
  local pa = Panel.activePanel
  if not pa then
    return
  end
  local p = pa.preview_textview
  if p and p.buf and vim.api.nvim_buf_is_valid(p.buf) then
    vim.api.nvim_buf_delete(p.buf, { force = true })
    -- vim.api.nvim_win_close(p.win, true)
    Panel.activePanel.preview_textview = nil
  end
end

function Panel.on_move()
  Panel.on_close()
end

function Panel.debug()
  log(Panel)
  log(active_windows)
  return Panel, active_windows
end

function Panel:open(should_toggle, redraw, buf)
  buf = buf or api.nvim_get_current_buf()
  log('buf:', vfn.bufname(buf or 0))
  if should_toggle and self:is_open() then
    Panel:close()
    return
  end
  -- trace(debug.traceback())
  for i, section in pairs(self.sections) do
    local nodes = section.render(buf)
    trace(nodes)
    if vfn.empty(nodes) == 1 then
      log('nothing to display')
      local modifiable = vim.bo.modifiable
      local filetype = vim.bo.filetype
      local unparseable_buftype = vim.tbl_contains(skip_buf_types, vim.bo.buftype)
      if not modifiable or filetype == '' or unparseable_buftype then
        -- Make sure our buffer is at visible.
        if vim.api.nvim_buf_is_loaded(self.last_parsed_buf) then
          return
        end
      end
      local tabpage = api.nvim_get_current_tabpage()
      local win_name = _make_window_name(tabpage)
      if active_windows[win_name] then
        local wid = active_windows[win_name]
        if not vim.api.nvim_win_is_valid(wid) then
          active_windows[win_name] = nil
          self.activePanel = nil
          active_windows = {}
          return
        end
        local header = self.header_text
        local msg = 'failed to generate pannel filetype: ' .. filetype
        local guihua_buf = api.nvim_win_get_buf(wid)
        if header == nil or guihua_buf == nil then
          log('header or guihua_buf is nil')
          return
        end
        api.nvim_buf_set_option(guihua_buf, 'modifiable', true)
        -- cleanup
        api.nvim_buf_set_lines(guihua_buf, 0, -1, false, {})
        api.nvim_buf_set_lines(guihua_buf, 0, #header, false, header)
        api.nvim_buf_set_lines(guihua_buf, #header, #header + 2, false, { '', msg })
        api.nvim_buf_set_option(guihua_buf, 'modifiable', false)
        self.last_parsed_buf = -1
      end
      return
    end
    self.sections[i].text = {}
    self.sections[i].nodes = nodes
    for _, node in ipairs(nodes) do
      table.insert(self.sections[i].text, self.sections[i].format(node, self.sections[i]))
    end
  end

  -- redraw the panel
  self:draw()

  local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
  if ft ~= '' and ft ~= 'guihua' and ft ~= 'nofile' then
    self.last_parsed_buf = buf
  end
  if not redraw then
    run_on_buf_write(buf)
    run_on_buf_enter()
    close_on_buf_win_leave()
  end
  enable_folding()
end

return Panel
