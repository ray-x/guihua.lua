local M = {}
local api = vim.api
local log = require('guihua.log').info
local trace = require('guihua.log').trace
local uv = vim.loop
local os_name = uv.os_uname().sysname
local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'
-- Check whether current buffer contains main function

local HAS_NVIM_0_9 = vim.fn.has('nvim-0.9') == 1
function M.sep()
  if is_windows then
    return '\\'
  end
  return '/'
end

function M.close_view_autocmd(events, winnr)
  vim.cmd(
    'autocmd '
      .. table.concat(events, ',')
      .. ' <buffer> ++once lua pcall(vim.api.nvim_win_close, '
      .. winnr
      .. ', true)'
  )
end

local function lshift(x, by)
  return x * 2 ^ by
end

local function rshift(x, by)
  return math.floor(x / 2 ^ by)
end
-- function M.buf_close_view_event(mode, key, bufnr, winnr)
--   local closer = " <Cmd> lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true) <CR>"
--   vim.api.nvim_buf_set_keymap(bufnr, "n", key, closer, {})
-- end

function M.bgcolor(delta, d2, d3)
  local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'bg#')

  bg = string.sub(bg, 2)
  local bgi = tonumber(bg, 16)
  local light = tonumber('a0a0a0', 16)
  if bgi == nil then
    return 'None' -- '#101b1f' -> None  in case bg is None maybe user want it to be transparent
  end
  if bgi > light then
    if d2 == nil then
      bgi = bgi - delta
    else
      bgi = bgi - delta * 65536 - d2 * 256 - (d3 or 16)
    end
  else
    if d2 == nil then
      bgi = bgi + delta
    else
      bgi = bgi + delta * 65536 + d2 * 256 + (d3 or 16)
    end
  end

  log(string.format('#%06x', bgi))
  return string.format('#%06x', bgi)
end

local function diff_color(bgcolor, sel)
  local b1, b2 = bgcolor, sel
  local diff = math.abs(bit.band(b1, 255) - bit.band(b2, 255))
  local t = math.abs(bit.band(b1, 255))
  b1 = bit.rshift(b1, 8)
  b2 = bit.rshift(b2, 8)
  diff = diff + math.abs(bit.band(b1, 255) - bit.band(b2, 255))
  t = t + math.abs(bit.band(b1, 255))
  b1 = bit.rshift(b1, 8)
  b2 = bit.rshift(b2, 8)
  diff = diff + math.abs(bit.band(b1, 255) - bit.band(b2, 255))
  t = t + math.abs(bit.band(b1, 255))
  return diff, t
end

-- offset the GuihuaListSelHl based on GuihuaListDark
function M.selcolor(Hl)
  vim.validate({ Hl = { Hl, 'string' } })
  log(Hl)
  local bg = tonumber(
    string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('NormalFloat')), 'bg#'), 2),
    16
  ) or tonumber(
    string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'bg#'), 2),
    16
  )

  local fg = tonumber(
    string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('NormalFloat')), 'fg#'), 2),
    16
  ) or tonumber(
    string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'fg#'), 2),
    16
  )

  if
    vim.fn.hlexists('GuihuaListSelHl') == 1
    and vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('GuihuaListSelHl')), 'bg#') ~= ''
  then
    -- already defined
    return
  end
  local bgcolor = tonumber(
    string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('GuihuaListDark')), 'bg#'), 2),
    16
  ) or bg or 0x303030

  vim.validate({ bgcolor = { bgcolor, 'number' } })
  --   local sel = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("PmenuSel")), "bg#") default
  local sel = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(Hl)), 'bg#') or '#434550'

  local sel_gstr = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(Hl)), 'fg#') or '#EFEFEF'

  log('sel, ', sel, sel_gstr)
  sel = tonumber(string.sub(sel, 2), 16)
  local selfg = tonumber(string.sub(sel_gstr, 2), 16)
  log(sel, selfg)
  bg = bg or 0x303030
  if sel == nil then
    sel = 0x506b8f
    if bg > 0xa00000 then
      sel = bg or 0xafafbf
    end
  end

  if selfg == nil then
    selfg = 0xa0abcf
    if bg and bg > 0xa00000 then
      selfg = fg or 0xefefef
    end
  end

  if bgcolor == nil then
    bgcolor = 0x40495f
  end

  local diff, t = diff_color(bgcolor, sel)
  if diff > 24 * 3 then
    local lbg = string.format('#%06x', sel)
    log(diff, sel, bgcolor, Hl)

    if vim.o.background == 'light' and sel_gstr and vim.fn.empty(sel_gstr) ~= 1 then
      vim.api.nvim_set_hl(
        0,
        'GuihuaListSelHl',
        { bg = lbg, fg = sel_gstr, bold = true, default = true }
      )
    else
      vim.api.nvim_set_hl(0, 'GuihuaListSelHl', { bg = lbg, bold = true, default = true })
    end
  else
    log(diff, t, sel, bgcolor, Hl)
    if t > 360 then -- not sure how this plugin works for light schema
      sel = bgcolor - 0x161810
    elseif t > 216 then
      sel = 0x120103
    else
      sel = bgcolor + 0x23202a
    end
    local lbg = string.format('#%6x', sel)
    vim.cmd('hi default GuihuaListSelHl cterm=Bold gui=Bold guibg=' .. lbg)
  end

  return 'GuihuaListSelHl'
end

M.get_hl_color = function(group_name)
  if HAS_NVIM_0_9 and vim.api.nvim_get_hl then
    local hl = vim.api.nvim_get_hl(0, { name = group_name })
    local fg = hl.fg and '#' .. bit.tohex(hl.fg, 6)
    local bg = hl.bg and '#' .. bit.tohex(hl.bg, 6)
    return fg, bg
  else -- TODO: deprecated in 0.9
    local ok, hl = pcall(vim.api.nvim_get_hl_by_name, group_name, true)
    if not ok then
      return nil, nil
    end
    local fg = hl.foreground and '#' .. bit.tohex(hl.foreground, 6)
    local bg = hl.background and '#' .. bit.tohex(hl.background, 6)
    return fg, bg
  end
end

function M.close_view_event(_, key, winnr, bufnr, enter)
  if winnr == nil then
    winnr = api.nvim_get_current_win()
  end
  if bufnr == nil then
    bufnr = api.nvim_get_current_buf()
  end
  local closer = ' <Cmd> lua pcall(vim.api.nvim_win_close, ' .. winnr .. ', true) <CR>'
  enter = enter or false

  -- log ("!! closer", winnr, bufnr, enter)
  if enter then
    api.nvim_buf_set_keymap(bufnr, 'n', key, closer, {})
    -- cmd( mode .. "map <buffer> " .. key .. " <Cmd> lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true) <CR>" )
  end
end

function M.clone(st)
  local tab = {}
  for k, v in pairs(st or {}) do
    if type(v) ~= 'table' then
      tab[k] = v
    else
      tab[k] = M.clone(v)
    end
  end
  return tab
end

function M.add_escape(s)
  -- / & ! . ^ * $ \ ?
  local special = { '&', '!', '*', '?', '/' }
  local str = s
  for i = 1, #special do
    str = string.gsub(str, special[i], '\\' .. special[i])
  end
  return str
end

function M.add_pec(s)
  -- / & ! . ^ * $ \ ?
  -- local special = { '%[', '%]', '%-' }
  local special = { '%[', '%]', '%-' }
  local str = s or ''
  for i = 1, #special do
    str = string.gsub(str, special[i], '%' .. special[i])
  end
  return str
end

-- lspsaga is using ft
local function apply_syntax_to_region(ft, start, finish)
  if ft == '' then
    return
  end
  local name = ft .. 'guihua'
  local lang = '@' .. ft:upper()
  if not pcall(vim.cmd, string.format('syntax include %s syntax/%s.vim', lang, ft)) then
    return
  end
  vim.cmd(
    string.format(
      'syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s',
      name,
      start,
      finish + 1,
      lang
    )
  )
end

-- Attach ts highlighter
M.highlighter = function(bufnr, ft, lines)
  if ft == nil or ft == '' then
    return false
  end

  local has_ts, _ = pcall(require, 'nvim-treesitter')
  if has_ts then
    local _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
    local _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
    local lang = ts_parsers.ft_to_lang(ft)
    if ts_parsers.has_parser(lang) then
      trace('attach ts')
      ts_highlight.attach(bufnr, lang)
      return true
    end
  else
    -- apply_syntax_to_region ?
    log('ts not enable')
    if not lines then
      log('need spcific lines!')
      -- TODO: did not verify this part of code yet
      lines = 12
    end
    apply_syntax_to_region(ft, 1, lines)
    return
  end

  return false
end

-- find whole word
function M.word_find(input, word)
  if input == nil or word == nil then
    return nil
  end
  return string.find(input, '%f[%a]' .. word .. '%f[%A]')
end

function M.fzy_idx(data_list, pos)
  -- first check if fzy is set
  local fzy_on = false
  for _, value in ipairs(data_list) do
    if value.fzy ~= nil then
      fzy_on = true
      break
    end
    if value.fzy ~= nil then
      fzy_on = true
      break
    end
  end
  if fzy_on == true then
    local i = 1
    for _, value in ipairs(data_list) do
      if value.fzy ~= nil then
        if i == pos then
          return value
        end
        i = i + 1
      end
    end
  end
  return data_list[pos]
end

M.split_str = function(str)
  local lines = {}
  for s in str:gmatch('[^\r\n]+') do
    table.insert(lines, s)
  end
  return lines
end

M.open_file_at = function(filename, line, col, split)
  log('open ' .. filename)
  local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(filename))
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
    vim.api.nvim_buf_attach(bufnr, true, {})
  end

  -- local bufname = vim.fn.bufname(filename)
  if split == nil then
    -- code
    vim.cmd(string.format('drop  %s', filename))
  elseif split == 'v' then
    if M.split_existed() then
      vim.cmd(string.format('drop  %s', filename))
    else
      vim.cmd(string.format('vsp! %s', filename))
    end
  elseif split == 's' then
    if M.split_existed() then
      vim.cmd(string.format('drop  %s', filename))
    else
      vim.cmd(string.format('sp! %s', filename))
    end
  elseif split == 't' then
    vim.cmd(string.format('tabnew! %s', filename))
  end
  vim.cmd('doautocmd FileType')
  col = col or 1
  vim.fn.cursor(line, col)
  -- sometime highlight failed because lazyloading
  local has_ts, _ = pcall(require, 'nvim-treesitter')
  if has_ts then
    local _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
    local _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
    local lang = ts_parsers.ft_to_lang(vim.o.ft)
    if ts_parsers.has_parser(lang) then
      trace('attach ts', lang)
      ts_highlight.attach(0, lang)
      return true
    else
      log('ts not enable')
      return false
    end
  end
end

M.merge = function(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end
  return t1
end

M.map = function(modes, key, rhs, options)
  options = M.merge({ noremap = true, silent = false, expr = false, nowait = false }, options or {})

  if options.buffer == true then
    options.buffer = vim.api.nvim_get_current_buf()
  elseif options.buffer == false then
    options.buffer = nil
  end
  if type(modes) ~= 'table' then
    modes = { modes }
  end

  if options.callback then
    local fn = options.callback
    options.callback = nil
    vim.keymap.set(modes, key, fn, options)
  else
    vim.keymap.set(modes, key, rhs, options)
  end
end

-- if split existed, cursor will move to next split and return true
M.split_existed = function()
  local curNr = vim.fn.winnr()
  vim.cmd('wincmd h')
  if vim.fn.winnr() ~= curNr then
    return true
  end
  vim.cmd('wincmd l')
  if vim.fn.winnr() ~= curNr then
    return true
  end
  return false
end

M.trim = function(s)
  return s:match('^%s*(.-)%s*$')
end

-- remove duplicate element in a table
M.dedup = function(list, key1, key2)
  local map = {}
  local result = {}
  if key2 == nil then
    key2 = key1
  end

  for i = 1, #list do
    local item = list[i]
    if map[item[key1] .. tostring(item[key2])] == nil then
      map[item[key1] .. tostring(item[key2])] = true
      table.insert(result, item)
    end
  end
  return result
end

-- remove item from list based on value
M.tbl_remove = function(input, val)
  for i = #input, 1, -1 do
    if input[i] == val then
      table.remove(input, i)
    end
  end
  return input
end

local protocol = require('vim.lsp.protocol')
function M._get_symbol_kind_name(symbol_kind)
  return protocol.SymbolKind[symbol_kind] or 'Unknown'
end

M.home = uv.os_homedir()

M.sep = (function()
  if jit then
    local os = string.lower(jit.os)
    if os == 'linux' or os == 'osx' or os == 'bsd' then
      return '/'
    else
      return '\\'
    end
  else
    return package.config:sub(1, 1)
  end
end)()

function M.symbols_to_items(symbols, bufnr)
  ---@private
  local function _symbols_to_items(_symbols, _items, _bufnr)
    for _, symbol in ipairs(_symbols) do
      local range = symbol.range or symbol.selectionRange
      local kind = M._get_symbol_kind_name(symbol.kind)
      local kind_text = ''
      if kind ~= 'Unknown' then
        kind_text = '[' .. kind .. ']'
      end
      table.insert(_items, {
        filename = vim.uri_to_fname(symbol.uri),
        lnum = range.start.line + 1,
        col = range.start.character + 1,
        kind = kind,
        text = kind_text .. (symbol.text or symbol.symbol_name),
      })
      if symbol.children then
        for _, v in ipairs(_symbols_to_items(symbol.children, _items, _bufnr)) do
          for _, s in ipairs(v) do
            table.insert(_items, s)
          end
        end
      end
    end
    return _items
  end
  return _symbols_to_items(symbols, {}, bufnr or 0)
end

-- shorten_len shorten the filename to a given length
-- this part is copied from plenary.nvim
function M.shorten_len(filename, len, exclude)
  len = len or 1
  exclude = exclude or { -1 }
  local exc = {}

  -- get parts in a table
  local parts = {}
  local empty_pos = {}
  for m in (filename .. M.sep):gmatch('(.-)' .. M.sep) do
    if m ~= '' then
      parts[#parts + 1] = m
    else
      table.insert(empty_pos, #parts + 1)
    end
  end

  for _, v in pairs(exclude) do
    if v < 0 then
      exc[v + #parts + 1] = true
    else
      exc[v] = true
    end
  end

  local final_path_components = {}
  local count = 1
  for _, match in ipairs(parts) do
    if not exc[count] and #match > len then
      table.insert(final_path_components, string.sub(match, 1, len))
    else
      table.insert(final_path_components, match)
    end
    table.insert(final_path_components, M.sep)
    count = count + 1
  end

  local l = #final_path_components -- so that we don't need to keep calculating length
  table.remove(final_path_components, l) -- remove final slash

  -- add back empty positions
  for i = #empty_pos, 1, -1 do
    table.insert(final_path_components, empty_pos[i], M.sep)
  end

  return table.concat(final_path_components)
end
local is_uri = function(filename)
  return string.match(filename, '^%w+://') ~= nil
end

M.shorten = (function()
  if jit and M.sep ~= '\\' then
    local ffi = require('ffi')
    ffi.cdef([[
    typedef unsigned char char_u;
    void shorten_dir(char_u *str);
    ]])
    return function(filename)
      if not filename or is_uri(filename) then
        return filename
      end

      local c_str = ffi.new('char[?]', #filename + 1)
      ffi.copy(c_str, filename)
      ffi.C.shorten_dir(c_str)
      return ffi.string(c_str)
    end
  end
  return function(filename)
    return M.shorten_len(filename, 1)
  end
end)()

local hsl = require('guihua.hsl')
M.rgb_to_hsl = function(rgb)
  local h, s, l = hsl.rgb_string_to_hsl(rgb)
  return hsl.new(h, s, l, rgb)
end

M.get_hsl_color = function(hl)
  local c1, c2 = M.get_hl_color(hl)
  local fg, bg
  if c1 then
    fg = M.rgb_to_hsl(c1)
  end
  if c2 then
    bg = M.rgb_to_hsl(c2)
  end
  return fg, bg
end

local title_colors = {
  -- stylua: ignore start
  nord = {'#ECEFF4', '#ACEFD4', '#9CCFD4', '#81A1C1', '#88B0D0', '#93BE8C', '#A3BE8C',
    '#B48EAD', '#B08770', '#EBCB8B'},
  monokai = {'#E6DB74', '#B6DB54', '#A6E22E', '#A6E22E', '#66D9EF', '#AE81FF', '#C8B8F2',
    '#F8F8F2', '#F8B892', '#F87842', '#F95642', '#FD971F'},
  solarized = {'#6C71C4', '#7C81C9', '#8C91B4', '#98A8F2', '#68A8E2', '#468BD2', '#268BD2',
    '#268BD2', '#268BD2', '#2AA198', '#859900', '#A5B900', '#B58900', '#CB4B16', '#DC322F',
    '#D33682'},
  dracula = {'#BD93F9', '#6272A4', '#84A7BA', '#F8F8F2', '#50FA7B', '#60EAAB', '#67EABB',
    '#8BE9FD', '#8BE9FD', '#FF5555', '#FF79C6' },
  rainbow = {'#FF0000', '#FF4000', '#FF8F00', '#FFDF00', '#FFFF00', '#BFFF00', '#8FFF00',
    '#6FFF00', '#4FFF00', '#00FF00', '#00FF20', '#00FF40', '#00FF60', '#00BFA0', '#00A0FF',
    '#4080FF', '#6A40FF', '#7A40FF', '#8B00FF', '#AB00FF', '#FB00FF', '#FB00AF', '#FB008F',
    '#FB004F' },
  -- stylua: ignore end
}

local list_color = function(colors, start, _end)
  local tbl = {}
  start = start or 1
  _end = _end or #colors
  local idx = start
  for _, color in pairs(colors) do
    if type(color) == 'string' then
      table.insert(tbl, M.rgb_to_hsl(color))
    else
      table.insert(tbl, color)
    end
  end
  return function()
    local value = tbl[idx]
    idx = idx + 1
    if idx > _end then
      idx = start
    end
    return value
  end
end

M.rainbow = function(colors, start, _end)
  return list_color(colors or title_colors, start, _end)
end

M.title_options = function(title_input, colors, color_start, color_end)
  if not title_input then
    return
  end
  local title = title_input
  if type(title_input) == 'table' then
    title = table.concat(title_input, ' ')
  end
  if vim.fn.has('nvim-0.9') == 0 then
    return
  end
  colors = colors or 'nord'
  if type(colors) == 'string' then
    colors = title_colors[colors]
  end
  local rainbow = M.rainbow(colors, color_start, color_end)
  local base = 'GHRainbow'
  local title_with_color = {}
  local c = rainbow().rgb
  for i = 1, #title do
    local name = base .. tostring(i)
    if title:sub(i, i) == ' ' then
      c = rainbow().rgb
    end
    vim.api.nvim_set_hl(0, name, { fg = c, bold = true, default = true })
    title_with_color[i] = { title:sub(i, i), name }
  end
  return title_with_color
end

M.throttle = function(func, duration)
  local timer = uv.new_timer()
  -- util.log(func, duration)
  local function inner(...)
    -- util.log('throttle', ...)
    if not timer:is_active() then
      timer:start(duration, 0, function() end)
      pcall(vim.schedule_wrap(func), select(1, ...))
    end
  end

  local group = vim.api.nvim_create_augroup('gonvim__CleanupLuvTimers', {})
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    pattern = '*',
    callback = function()
      if timer then
        if timer:has_ref() then
          timer:stop()
          if not timer:is_closing() then
            timer:close()
          end
        end
        timer = nil
      end
    end,
  })

  return inner, timer
end

-- for i, v in ipairs(M.rainbow_colors) do
--   print(1, v)
-- end

return M
