local M = {}

local util = require('guihua.util')
local SessionRegistry = require('guihua.session_registry')
local TextView = require('guihua.textview')
local location = require('guihua.location')

local function is_list(value)
  return vim.islist(value)
end

local function to_text(value)
  if value == nil then
    return ''
  end
  if type(value) == 'table' then
    local parts = {}
    for _, v in ipairs(value) do
      parts[#parts + 1] = tostring(v)
    end
    return table.concat(parts, ' ')
  end
  return tostring(value)
end

local function to_abs_path(path)
  if type(path) ~= 'string' or path == '' then
    return ''
  end
  if path:sub(1, 1) == '~' then
    path = vim.fn.expand(path)
  end
  return vim.fn.fnamemodify(path, ':p')
end

local function to_display_path(path, project_root)
  if type(path) ~= 'string' or path == '' then
    return ''
  end
  if path:sub(1, 1) ~= '/' then
    return path
  end
  local root = to_abs_path(project_root or vim.fn.getcwd())
  if root ~= '' then
    root = root:gsub('/+$', '')
    if path == root then
      return '.'
    end
    if path:sub(1, #root + 1) == root .. '/' then
      return path:sub(#root + 2)
    end
  end
  return path
end

local function normalize_item(item, project_root)
  item = item or {}
  local path = item.path or item.filename or ''
  if (path == nil or path == '') and type(item.uri) == 'string' and item.uri:match('^file://') then
    path = vim.uri_to_fname(item.uri)
  end
  path = to_abs_path(path)
  local display_path = item.display_path or to_display_path(path, project_root)
  return {
    raw = item,
    name = item.name or item.label or item.text or item.title or '',
    description = to_text(item.description or item.desc or item.docs),
    path = path,
    display_path = display_path,
    uri = item.uri or (path ~= '' and vim.uri_from_fname(path) or nil),
  }
end

local function normalize_tabs(tabs, tab_order, project_root)
  tabs = tabs or {}
  tab_order = tab_order or {}
  local result = {}

  if is_list(tabs) then
    for _, tab in ipairs(tabs) do
      local key = tab.key or tab.name or tab.label or tostring(#result + 1)
      result[#result + 1] = {
        key = key,
        label = tab.label or tab.name or key,
        hotkey = (tab.hotkey or key:sub(1, 1)):lower(),
        items = vim.tbl_map(function(v)
          return normalize_item(v, project_root)
        end, tab.items or tab.data or {}),
      }
    end
    return result
  end

  if #tab_order == 0 then
    for key in pairs(tabs) do
      tab_order[#tab_order + 1] = key
    end
    table.sort(tab_order)
  end

  for _, key in ipairs(tab_order) do
    local value = tabs[key]
    if value ~= nil then
      local items = value
      local label = key
      local hotkey = key:sub(1, 1):lower()
      if type(value) == 'table' and not is_list(value) then
        label = value.label or key
        hotkey = (value.hotkey or key:sub(1, 1)):lower()
        items = value.items or value.data or {}
      end
      result[#result + 1] = {
        key = key,
        label = label,
        hotkey = hotkey,
        items = vim.tbl_map(function(v)
          return normalize_item(v, project_root)
        end, items),
      }
    end
  end

  return result
end

local function item_label(item)
  local text = item.name or ''
  if item.description ~= '' then
    text = text .. ' — ' .. item.description
  end
  local shown_path = item.display_path or item.path or ''
  if shown_path ~= '' then
    text = text .. ' (' .. shown_path .. ')'
  end
  return text
end

local function chunks_width(chunks)
  local width = 0
  for _, chunk in ipairs(chunks) do
    if type(chunk) == 'table' and type(chunk[1]) == 'string' then
      width = width + vim.fn.strdisplaywidth(chunk[1])
    elseif type(chunk) == 'string' then
      width = width + vim.fn.strdisplaywidth(chunk)
    end
  end
  return width
end

local function tab_title_chunks(title, tabs, active_index, close_hint_text, win_width)
  local title_text = title or 'Catalog'
  local chunks = {
    { '────', 'FloatBorder' },
    { title_text, 'GuihuaCatalogTitle' },
    { '────│', 'FloatBorder' },
  }
  for i, tab in ipairs(tabs) do
    if i > 1 then
      chunks[#chunks + 1] = { '│', 'FloatBorder' }
    end
    local label = tab.label or tab.key or ''
    local hotkey = label:sub(1, 1)
    local rest = label:sub(2)
    local active = i == active_index
    chunks[#chunks + 1] = { hotkey, active and 'GuihuaCatalogTabHotkeyActive' or 'GuihuaCatalogTabHotkey' }
    if rest ~= '' then
      chunks[#chunks + 1] = { rest, active and 'GuihuaCatalogTabActive' or 'GuihuaCatalogTab' }
    end
  end
  if close_hint_text ~= nil and close_hint_text ~= '' then
    local right_pad = 4
    local hint_width = vim.fn.strdisplaywidth(close_hint_text)
    local fixed_width = chunks_width(chunks) + 1 + hint_width + right_pad -- +1 for separator
    local gap = 4
    if type(win_width) == 'number' and win_width > fixed_width then
      gap = math.max(gap, win_width - fixed_width)
    end
    chunks[#chunks + 1] = { '│' .. string.rep('─', gap), 'FloatBorder' }
    chunks[#chunks + 1] = { close_hint_text, 'GuihuaCatalogHint' }
    chunks[#chunks + 1] = { string.rep('─', right_pad), 'FloatBorder' }
  end
  return chunks
end

local function make_display_items(tab, state)
  local display = {}
  local item_icon = (state and state.item_icon) or ''
  local current_item_icon = (state and state.current_item_icon) or ''
  for _, item in ipairs(tab.items or {}) do
    display[#display + 1] = {
      text = item_label(item),
      icon = item.icon or item_icon,
      current_icon = item.current_icon or current_item_icon,
      value = item,
      filename = item.path ~= '' and item.path or nil,
      uri = item.uri,
      path = item.path,
      name = item.name,
      description = item.description,
    }
  end
  return display
end

local function filetype_for_path(path)
  if path == nil or path == '' then
    return 'markdown'
  end
  local ext = path:match('%.([%w_%-]+)$')
  if ext == 'md' or ext == 'markdown' then
    return 'markdown'
  end
  return vim.filetype and vim.filetype.match and vim.filetype.match({ filename = path }) or nil
end

local function border_rows(border)
  if border == nil or border == 'none' then
    return 0
  end
  if border == 'shadow' then
    return 1
  end
  return 2
end

local function desired_list_height(item_count, ratio)
  local lines = vim.api.nvim_get_option_value('lines', {})
  local cap = math.max(3, math.floor(lines * (ratio or 0.45)))
  local rows = math.max(1, item_count or 0)
  return math.max(1, math.min(rows, cap))
end

local function minimum_title_width(tabs, title, close_hint_text)
  local width = vim.fn.strdisplaywidth('────') + vim.fn.strdisplaywidth(title or 'Catalog') + vim.fn.strdisplaywidth('────│')
  for i, tab in ipairs(tabs or {}) do
    local label = (tab and (tab.label or tab.key)) or ''
    if i > 1 then
      width = width + vim.fn.strdisplaywidth('│')
    end
    width = width + vim.fn.strdisplaywidth(label)
  end
  if close_hint_text ~= nil and close_hint_text ~= '' then
    width = width + vim.fn.strdisplaywidth('│────') + vim.fn.strdisplaywidth(close_hint_text) + vim.fn.strdisplaywidth('────')
  end
  return width
end

local function desired_list_width(tabs, title, close_hint_text, ratio)
  local columns = vim.api.nvim_get_option_value('columns', {})
  local cap = math.max(40, math.floor(columns * (ratio or 0.9)))
  local max_label_width = 0
  for _, tab in ipairs(tabs or {}) do
    for _, item in ipairs((tab and tab.items) or {}) do
      max_label_width = math.max(max_label_width, vim.fn.strdisplaywidth(item_label(item)) + 2)
    end
  end
  local min_width = minimum_title_width(tabs, title, close_hint_text)
  local base = math.max(min_width + 2, max_label_width + 6)
  return math.max(40, math.min(base, cap))
end

local function preview_anchor(state)
  local loc_fn = nil
  if type(state.loc) == 'function' then
    loc_fn = state.loc
  elseif type(state.loc) == 'string' and state.loc ~= 'none' then
    loc_fn = location[state.loc]
  end
  if loc_fn ~= nil then
    return loc_fn(state.list_height, state.list_width)
  end

  local view = state.view
  if view ~= nil and view.win ~= nil and vim.api.nvim_win_is_valid(view.win) then
    local cfg = vim.api.nvim_win_get_config(view.win) or {}
    local row = math.floor(tonumber(cfg.row) or 0)
    local col = math.floor(tonumber(cfg.col) or 0)
    return row, col
  end
  return 0, 0
end

local function list_geometry(state)
  local view = state.view
  if view ~= nil and view.win ~= nil and vim.api.nvim_win_is_valid(view.win) then
    local cfg = vim.api.nvim_win_get_config(view.win) or {}
    local width = math.floor(tonumber(cfg.width) or state.list_width)
    local height = math.floor(tonumber(cfg.height) or (state.list_height + (state.prompt and 1 or 0)))
    local row = math.floor(tonumber(cfg.row) or 0)
    local col = math.floor(tonumber(cfg.col) or 0)
    return row, col, width, height
  end

  local row, col = preview_anchor(state)
  return row, col, state.list_width, state.list_height + (state.prompt and 1 or 0)
end

local function resize_listview(state, item_count)
  if state.fixed_height == true then
    return
  end
  local previous_list_height = state.list_height
  local new_list_height = desired_list_height(item_count, state.list_height_ratio)
  if new_list_height == state.list_height then
    return
  end

  state.list_height = new_list_height
  local win_height = new_list_height + (state.prompt and 1 or 0)
  local view = state.view
  if view == nil then
    return
  end

  if previous_list_height ~= nil and new_list_height < previous_list_height and view.buf ~= nil and vim.api.nvim_buf_is_valid(view.buf) then
    -- Remove stale content rows when shrinking; View:on_draw clears only the current visible rows.
    vim.api.nvim_buf_set_lines(view.buf, new_list_height, previous_list_height, false, {})
  end

  view.rect.height = win_height
  view.display_height = win_height

  local ctrl = view:get_ctrl()
  if ctrl ~= nil and ctrl.state ~= nil then
    ctrl.state.display_height = win_height
    ctrl.display_height = win_height
    ctrl.state:refresh_display()
    ctrl:sync_state()
  end

  if view.win ~= nil and vim.api.nvim_win_is_valid(view.win) then
    local cfg = vim.api.nvim_win_get_config(view.win)
    cfg.height = win_height
    vim.api.nvim_win_set_config(view.win, cfg)
  end
end

local function preview_spec(state, item)
  if item == nil then
    return nil
  end
  local path = item.path or item.filename or ''
  if path == '' then
    return nil
  end
  if item.uri == nil then
    item.uri = vim.uri_from_fname(path)
  end
  local list_row, list_col, list_width, list_height = list_geometry(state)
  local preview_y = list_row + list_height + border_rows(state.border)
  local lines = vim.api.nvim_get_option_value('lines', {})
  local base_list_height = math.max(1, list_height - (state.prompt and 1 or 0))
  local below_height = math.min(lines - base_list_height - 3, math.floor(lines * (state.preview_height_ratio or 0.4)))
  if below_height < 3 then
    below_height = 3
  end
  local status_line_extra = (item.status_line and #item.status_line > 0 and 1) or 0
  return require('guihua.gui').preview_uri_spec({
    uri = item.uri,
    syntax = item.syntax or filetype_for_path(path) or 'text',
    lnum = item.lnum or 1,
    status_line = item.status_line,
    width = list_width,
    height = below_height + status_line_extra,
    preview_height = below_height + status_line_extra,
    preview_lines_before = 1,
    loc = location.none,
    relative = 'editor',
    offset_x = list_col,
    offset_y = preview_y,
    border = state.border or 'rounded',
  })
end

local function current_items(state)
  return state.tabs[state.current_tab].items or {}
end

local function filter_items(state, query)
  query = (query or ''):lower()
  local items = current_items(state)
  local result = {}
  for _, item in ipairs(items) do
    local haystack = table.concat({ item.name, item.description, item.path }, ' '):lower()
    if query == '' or haystack:find(query, 1, true) then
      result[#result + 1] = {
        text = item_label(item),
        value = item,
        filename = item.path ~= '' and item.path or nil,
        uri = item.uri,
        path = item.path,
        name = item.name,
        description = item.description,
      }
    end
  end
  return result
end

local function apply_display(state, display_items, query)
  local ctrl = state.view:get_ctrl()
  if ctrl == nil or ctrl.state == nil then
    return
  end
  local result = ctrl.state:apply_filter(display_items, query or '')
  ctrl:apply_state_result(result, { preview = true })
  if result.redraw then
    state.view:on_draw(ctrl.state.display_data)
  end
end

local function select_first_item(state)
  local ctrl = state.view:get_ctrl()
  if ctrl == nil or ctrl.state == nil then
    return
  end
  local data = ctrl.state:active_data() or {}
  for i, item in ipairs(data) do
    if type(item) == 'table' and item.value ~= nil then
      local result = ctrl.state:set_selection(i)
      ctrl:apply_state_result(result, { preview = true })
      if result.redraw then
        state.view:on_draw(ctrl.state.display_data)
      end
      return
    end
  end
end

local function set_catalog_hls()
  pcall(vim.api.nvim_set_hl, 0, 'GuihuaCatalogTitle', { default = true, bold = true })
  pcall(vim.api.nvim_set_hl, 0, 'GuihuaCatalogTab', { default = true, bold = true })
  pcall(vim.api.nvim_set_hl, 0, 'GuihuaCatalogTabActive', { default = true, reverse = true, bold = true })
  pcall(vim.api.nvim_set_hl, 0, 'GuihuaCatalogTabHotkey', { default = true, underline = true, bold = true, fg = 0x7aa2f7 })
  pcall(vim.api.nvim_set_hl, 0, 'GuihuaCatalogTabHotkeyActive', { default = true, underline = true, bold = true, reverse = true, fg = 0x7aa2f7 })
  pcall(vim.api.nvim_set_hl, 0, 'GuihuaCatalogHint', { default = true, bold = true })
end

local function set_window_title(state)
  if state.view == nil or state.view.win == nil or not vim.api.nvim_win_is_valid(state.view.win) then
    return
  end
  local cfg = vim.api.nvim_win_get_config(state.view.win)
  if vim.fn.has('nvim-0.9') == 1 then
    cfg.title = tab_title_chunks(state.title, state.tabs, state.current_tab, state.close_hint_text, cfg.width)
    cfg.title_pos = 'left'
  end
  vim.api.nvim_win_set_config(state.view.win, cfg)
end

local function prompt_prefix(view)
  if view == nil or view.buf == nil or not vim.api.nvim_buf_is_valid(view.buf) then
    return ''
  end
  local prompt = vim.fn.prompt_getprompt(view.buf)
  if prompt == nil or prompt == '' then
    return '󱩾 '
  end
  return prompt
end

local function reset_prompt_line(state)
  if state.view == nil or state.view.buf == nil or not vim.api.nvim_buf_is_valid(state.view.buf) then
    return
  end
  local buf = state.view.buf
  local prompt = prompt_prefix(state.view)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines >= 1 then
    vim.api.nvim_buf_set_lines(buf, #lines - 1, #lines, false, { prompt })
  end
end

local function switch_tab_data(state, index)
  if index < 1 or index > #state.tabs then
    return
  end
  state.current_tab = index
  state.filter = ''
  resize_listview(state, #(state.tabs[index].items or {}))
  set_window_title(state)
  reset_prompt_line(state)
  local items = make_display_items(state.tabs[index], state)
  local ctrl = state.view:get_ctrl()
  if ctrl ~= nil then
    ctrl:on_data_update(items)
    ctrl:apply_state_result(ctrl.state:apply_filter(nil, ''), { preview = true })
  else
    apply_display(state, items, '')
    select_first_item(state)
  end
end

local function close(state)
  if state.closed then
    return
  end
  state.closed = true
  SessionRegistry.close_preview(state.session)
  if state.view ~= nil then
    if state.close_impl ~= nil then
      state.close_impl(state.view)
    elseif state.view.close ~= nil then
      state.view:close()
    end
  end
end

local function set_tab(state, index)
  switch_tab_data(state, index)
end

local function cycle_tab(state, step)
  local tab_count = #state.tabs
  if tab_count == 0 then
    return
  end

  local next_tab = state.current_tab + step
  if next_tab < 1 then
    next_tab = tab_count
  elseif next_tab > tab_count then
    next_tab = 1
  end

  switch_tab_data(state, next_tab)
end

local function set_filter(state, query)
  state.filter = query or ''
  local filtered = filter_items(state, state.filter)
  resize_listview(state, #filtered)
  apply_display(state, filtered, state.filter)
  select_first_item(state)
end

local function current_item(state)
  local ctrl = state.view:get_ctrl()
  if ctrl == nil or ctrl.state == nil then
    return nil
  end
  local item = ctrl.state:current_item()
  return type(item) == 'table' and item.value or nil
end

local function confirm(state)
  local item = current_item(state)
  if item == nil then
    return
  end
  local on_confirm = state.on_confirm
    or function(selected)
      local path = selected.path
      if path ~= nil and path ~= '' then
        vim.schedule(function()
          util.open_file_at(path, 1, 1)
        end)
      end
    end
  close(state)
  on_confirm(item, state.tabs[state.current_tab])
end

-- Open a tabbed catalog list view with a synchronized preview window.
--
-- opts:
--   title                (string) Border title. Default: "Catalog".
--   tabs                 (table)  Tab data. Supports:
--                                 - keyed table: { tab_key = items_or_tab_spec, ... }
--                                 - list form:   { { key=..., label=..., hotkey=..., items=... }, ... }
--   tab_order / order    (table)  Tab key order when tabs is a keyed table.
--   loc                  (string|function) List location. Default: "top_center".
--   rect                 (table)  Explicit list rect { width, height }.
--   width / height       (number) List size shortcut when rect is not provided.
--                                 Without explicit height, list height auto-fits item count.
--   list_height_ratio    (number) Max list height ratio against editor lines. Default: 0.45.
--   width_ratio          (number) Max list width ratio against editor columns. Default: 0.9.
--   border               (string) Border style for list + preview. Default: "rounded".
--   ft                   (string) List buffer filetype. Default: "guihua".
--   session              (table)  Optional guihua session to reuse.
--   preview_height_ratio (number) Preview height ratio against editor lines. Default: 0.4.
--   root                 (string) Project root used to derive display_path. Default: cwd.
--   item_icon            (string) Icon prefix for non-current items. Default: "".
--   current_item_icon    (string) Icon prefix for the current item. Default: "".
--   close_hint           (string) Optional custom close hint text shown in the title.
--   on_confirm           (function) Callback(item, active_tab). If omitted, opens item.path.
--   on_cancel            (function) Reserved cancel callback hook.
--
-- Tab item fields (normalized):
--   name/label/text/title, description/desc/docs, path/filename/uri, display_path.
--
-- Returns:
--   listview|nil   A listview object exposing set_tab/next_tab/prev_tab/set_filter/current_item/confirm/refresh/close.
local function open_catalog(opts, on_confirm)
  opts = opts or {}
  local project_root = opts.root or vim.fn.getcwd()
  local tabs = normalize_tabs(opts.tabs or {}, opts.tab_order or opts.order, project_root)
  if #tabs == 0 then
    return nil
  end
  local setup = require('guihua').ensure_setup()
  local close_keymap = (setup.maps or {}).close_view or '<C-e>'
  local close_hint_text = close_keymap .. ' to close'
  if type(opts.close_hint) == 'string' and opts.close_hint ~= '' then
    close_hint_text = opts.close_hint
  end

  local state = {
    tabs = tabs,
    current_tab = 1,
    filter = '',
    title = opts.title or 'Catalog',
    project_root = project_root,
    item_icon = opts.item_icon or '',
    current_item_icon = opts.current_item_icon or '',
    close_keymap = close_keymap,
    close_hint_text = close_hint_text,
    loc = opts.loc or 'top_center',
    prompt = true,
    fixed_height = opts.height ~= nil or (opts.rect ~= nil and opts.rect.height ~= nil),
    list_height_ratio = opts.list_height_ratio or 0.45,
    preview_height_ratio = opts.preview_height_ratio or 0.4,
    on_confirm = on_confirm or opts.on_confirm,
    on_cancel = opts.on_cancel,
    session = nil,
    border = opts.border or 'rounded',
  }

  set_catalog_hls()
  local list_rect = opts.rect
    or {
      height = opts.height or desired_list_height(#tabs[1].items, state.list_height_ratio),
      width = opts.width or desired_list_width(tabs, state.title, state.close_hint_text, opts.width_ratio or 0.9),
    }
  local columns = vim.api.nvim_get_option_value('columns', {})
  local lines = vim.api.nvim_get_option_value('lines', {})
  if type(list_rect.height) ~= 'number' then
    list_rect.height = tonumber(list_rect.height) or 10
  end
  if type(list_rect.width) ~= 'number' then
    list_rect.width = tonumber(list_rect.width) or 80
  end
  if list_rect.height > 0 and list_rect.height < 1 then
    list_rect.height = math.floor(lines * list_rect.height)
  end
  if list_rect.width > 0 and list_rect.width < 1 then
    list_rect.width = math.floor(columns * list_rect.width)
  end
  list_rect.height = math.max(1, math.floor(list_rect.height))
  list_rect.width = math.max(1, math.floor(list_rect.width))
  if state.fixed_height ~= true then
    list_rect.height = desired_list_height(#tabs[1].items, state.list_height_ratio)
  end
  state.list_height = list_rect.height
  state.list_width = list_rect.width
  local function close_catalog()
    vim.schedule(function()
      close(state)
    end)
  end
  local function close_catalog_expr()
    close_catalog()
    return ''
  end
  local function bind_preview_close_keymaps()
    local session = SessionRegistry.get(state.session and state.session.id or state.session)
    local preview = session and session.preview_view or nil
    if preview == nil or preview.buf == nil or not vim.api.nvim_buf_is_valid(preview.buf) then
      return
    end
    vim.keymap.set('n', state.close_keymap, close_catalog, { buffer = preview.buf, noremap = true, silent = true })
    vim.keymap.set('i', state.close_keymap, close_catalog_expr, { buffer = preview.buf, noremap = true, silent = true, expr = true })
    vim.keymap.set('n', '<Esc><Esc>', close_catalog, { buffer = preview.buf, noremap = true, silent = true })
    vim.keymap.set('i', '<Esc><Esc>', close_catalog_expr, { buffer = preview.buf, noremap = true, silent = true, expr = true })
  end

  local view = require('guihua.listview'):new({
    loc = state.loc,
    border = opts.border or 'rounded',
    prompt = state.prompt,
    enter = true,
    rect = list_rect,
    data = make_display_items(tabs[1], state),
    ft = opts.ft or 'guihua',
    session = opts.session,
    persist = true,
    on_confirm = function(item)
      if item == nil or item.value == nil then
        return
      end
      confirm(state)
    end,
    on_move = function(item)
      local value = item and item.value or nil
      local spec = preview_spec(state, value)
      vim.schedule(bind_preview_close_keymaps)
      return spec
    end,
    on_input_filter = function(text, items)
      state.filter = text or ''
      local active = current_items(state)
      if items ~= nil and #items > 0 then
        active = {}
        for _, item in ipairs(items) do
          if type(item) == 'table' and item.value ~= nil then
            active[#active + 1] = item.value
          end
        end
      end
      local filtered = {}
      local q = state.filter:lower()
      for _, item in ipairs(active) do
        local haystack = table.concat({ item.name, item.description, item.path }, ' '):lower()
        if q == '' or haystack:find(q, 1, true) then
          filtered[#filtered + 1] = {
            text = item_label(item),
            icon = item.icon or state.item_icon,
            current_icon = item.current_icon or state.current_item_icon,
            value = item,
            filename = item.path ~= '' and item.path or nil,
            uri = item.uri,
            path = item.path,
            name = item.name,
            description = item.description,
          }
        end
      end
      return filtered
    end,
  })

  state.view = view
  state.session = view.session
  state.close_impl = view.close
  set_window_title(state)

  function view:set_tab(index)
    set_tab(state, index)
  end

  function view:next_tab()
    cycle_tab(state, 1)
  end

  function view:prev_tab()
    cycle_tab(state, -1)
  end

  function view:set_filter(query)
    reset_prompt_line(state)
    set_filter(state, query)
  end

  function view:current_item()
    return current_item(state)
  end

  function view:confirm()
    confirm(state)
  end

  function view:close()
    close(state)
  end

  function view:refresh()
    apply_display(state, make_display_items(state.tabs[state.current_tab], state), state.filter)
    select_first_item(state)
  end

  for i, tab in ipairs(state.tabs) do
    local key = tab.hotkey
    vim.keymap.set('n', key, function()
      set_tab(state, i)
    end, { buffer = view.buf, noremap = true, silent = true, nowait = true })
    vim.keymap.set('i', key, function()
      local line = vim.api.nvim_get_current_line() or ''
      local prompt = prompt_prefix(state.view)
      if line == prompt then
        set_tab(state, i)
        return ''
      end
      if line:find('^' .. vim.pesc(prompt)) then
        return key
      end
      set_tab(state, i)
      return ''
    end, { buffer = view.buf, noremap = true, silent = true, expr = true, nowait = true })
  end

  vim.keymap.set({ 'n', 'i' }, '<Left>', function()
    view:prev_tab()
  end, { buffer = view.buf, noremap = true, silent = true })
  vim.keymap.set({ 'n', 'i' }, '<Right>', function()
    view:next_tab()
  end, { buffer = view.buf, noremap = true, silent = true })
  vim.keymap.set('n', state.close_keymap, function()
    close_catalog()
  end, { buffer = view.buf, noremap = true, silent = true })
  vim.keymap.set('i', state.close_keymap, close_catalog_expr, { buffer = view.buf, noremap = true, silent = true, expr = true })
  vim.keymap.set('n', '<ESC><ESC>', function()
    close_catalog()
  end, { buffer = view.buf, noremap = true, silent = true })
  vim.keymap.set('i', '<ESC><ESC>', close_catalog_expr, { buffer = view.buf, noremap = true, silent = true, expr = true })

  local ctrl = view:get_ctrl()
  if ctrl ~= nil then
    select_first_item(state)
    vim.schedule(bind_preview_close_keymaps)
  end

  return view
end

M.open = open_catalog
M.close = close

if false then
  local test_item_icon = vim.g.guihua_catalog_test_item_icon or ''
  local test_current_item_icon = vim.g.guihua_catalog_test_current_item_icon or ''
  open_catalog({
    title = 'Catalog Preview Layout',
    tabs = {
      agents = {
        { name = 'catalog.lua', description = 'current impl', path = '~/github/ray-x/guihua.lua/lua/guihua/catalog.lua' },
        { name = 'gui.lua', description = 'new_list_view reference', path = '~/github/ray-x/guihua.lua/lua/guihua/gui.lua' },
      },
      docs = {
        { name = 'README', description = 'docs', path = '~/github/ray-x/guihua.lua/README.md' },
      },
    },
    tab_order = { 'agents', 'docs' },
    border = 'rounded',
    close_hint = '<C-e> to close',
    item_icon = test_item_icon,
    current_item_icon = test_current_item_icon,
    -- height = 12,
    -- width = 100,
  })
end
return M
