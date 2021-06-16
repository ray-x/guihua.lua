local M = {}
local api = vim.api
local log = require"guihua.log".info
local trace = require"guihua.log".trace

function M.close_view_autocmd(events, winnr)
  api.nvim_command("autocmd " .. table.concat(events, ",")
                       .. " <buffer> ++once lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true)")
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
  local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Normal")), "bg#")
  local sel = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("PmenuSel")), "bg#")

  bg = string.sub(bg, 2)
  local bgi = tonumber(bg, 16)
  if bgi == nil then
    return "#101b3f"
  end
  if d2 == nil then
    bgi = bgi + delta
  else
    bgi = bgi + delta * 65536 + d2 * 256 + d3
  end

  log(string.format("#%06x", bgi))
  return string.format("#%06x", bgi)
end

-- offset the GHListHl based on GHListDark
function M.selcolor(Hl)
  vim.validate {Hl = {Hl, 'string'}}
  local bgcolor = tonumber(string.sub(
                               vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("GHListDark")), "bg#"),
                               2), 16) or 0x303b5f
  vim.validate {bgcolor = {bgcolor, 'number'}}
  local sel = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(Hl)), "bg#")
  sel = tonumber(string.sub(sel, 2), 16)
  if sel == nil then
    print("color scheme ", Hl, "does not have bg")
    sel = 0x506b8f
  end

  if bgcolor == nil then
    print("color scheme GHListDark does not have bg")
    bgcolor = 0x40495f
  end

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
  if diff > 24 * 3 then
    local fg = string.format("#%6x", sel)
    log(diff, sel, bgcolor, Hl)
    vim.cmd("hi default GHListHl cterm=Bold gui=Bold guibg = " .. fg)
  else
    log(diff, t, sel, bgcolor, Hl)
    if t > 360 then -- not sure how this plugin works for light schema
      sel = bgcolor - 0x161810
    elseif t > 216 then
      sel = 0x120103
    else
      sel = bgcolor + 0x171320
    end
    local fg = string.format("#%6x", sel)
    vim.cmd("hi default GHListHl cterm=Bold gui=Bold guibg=" .. fg)
  end

  return "GHListHl"
end

function M.close_view_event(mode, key, winnr, bufnr, enter)
  local closer = " <Cmd> lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true) <CR>"
  enter = enter or false
  bufnr = bufnr or 0

  -- log ("!! closer", winnr, bufnr, enter)
  if enter then
    vim.api.nvim_buf_set_keymap(bufnr, "n", key, closer, {})
    -- api.nvim_command( mode .. "map <buffer> " .. key .. " <Cmd> lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true) <CR>" )
  end
end

function M.clone(st)
  local tab = {}
  for k, v in pairs(st or {}) do
    if type(v) ~= "table" then
      tab[k] = v
    else
      tab[k] = M.clone(v)
    end
  end
  return tab
end

function M.add_escape(s)
  -- / & ! . ^ * $ \ ?
  local special = {"&", "!", "*", "?", "/"}
  local str = s
  for i = 1, #special do
    str = string.gsub(str, special[i], "\\" .. special[i])
  end
  return str
end

function M.add_pec(s)
  -- / & ! . ^ * $ \ ?
  local special = {"%[", "%]", "%-"}
  local str = s
  for i = 1, #special do
    str = string.gsub(str, special[i], "%" .. special[i])
  end
  return str
end

-- lspsaga is using ft
local function apply_syntax_to_region(ft, start, finish)
  if ft == '' then
    return
  end
  local name = ft .. 'guihua'
  local lang = "@" .. ft:upper()
  if not pcall(vim.cmd, string.format("syntax include %s syntax/%s.vim", lang, ft)) then
    return
  end
  vim.cmd(string.format("syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s", name, start,
                        finish + 1, lang))
end

-- Attach ts highlighter
M.highlighter = function(bufnr, ft, lines)
  if ft == nil or ft == "" then
    return false
  end

  local has_ts, _ = pcall(require, "nvim-treesitter")
  if has_ts then
    local _, ts_highlight = pcall(require, "nvim-treesitter.highlight")
    local _, ts_parsers = pcall(require, "nvim-treesitter.parsers")
    local lang = ts_parsers.ft_to_lang(ft)
    if ts_parsers.has_parser(lang) then
      trace("attach ts")
      ts_highlight.attach(bufnr, lang)
      return true
    end
  else
    -- apply_syntax_to_region ?
    log("ts not enable")
    if not lines then
      log("need spcific lines!")
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
  return string.find(input, "%f[%a]" .. word .. "%f[%A]")
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

return M
