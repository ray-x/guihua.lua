local M = {}
local api = vim.api
local log = require('guihua.log').info
local trace = require('guihua.log').trace

local os_name = vim.loop.os_uname().sysname
local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'
-- Check whether current buffer contains main function

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
    return '#101b3f'
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

-- offset the GuihuaListHl based on GuihuaListDark
function M.selcolor(Hl)
  vim.validate({ Hl = { Hl, 'string' } })
  log(Hl)
  local bg = tonumber(string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('NormalFloat')), 'bg#'), 2), 16)
    or tonumber(string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'bg#'), 2), 16)

  local fg = tonumber(string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('NormalFloat')), 'fg#'), 2), 16)
    or tonumber(string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'fg#'), 2), 16)

  if vim.fn.hlexists('GuihuaListHl') == 1 and vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('GuihuaListHl')), 'bg#') ~= '' then
    -- already defined
    return
  end
  local bgcolor = tonumber(string.sub(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('GuihuaListDark')), 'bg#'), 2), 16)
    or bg
    or 0x303030

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

    local hi = [[hi default GuihuaListHl cterm=Bold gui=Bold guibg=]] .. lbg
    if vim.o.background == 'light' and sel_gstr then
      hi = hi .. ' guifg=' .. sel_gstr
    end

    vim.cmd(hi)
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
    vim.cmd('hi default GuihuaListHl cterm=Bold gui=Bold guibg=' .. lbg)
  end

  return 'GuihuaListHl'
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
  vim.cmd(string.format('syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s', name, start, finish + 1, lang))
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

M.map = function(modes, key, result, options)
  options = M.merge({ noremap = true, silent = false, expr = false, nowait = false }, options or {})
  local buffer = options.buffer
  options.buffer = nil

  if type(modes) ~= 'table' then
    modes = { modes }
  end

  for i = 1, #modes do
    if buffer then
      api.nvim_buf_set_keymap(0, modes[i], key, result, options)
    else
      api.nvim_set_keymap(modes[i], key, result, options)
    end
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
return M
