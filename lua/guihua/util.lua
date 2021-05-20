local M = {}
local api = vim.api
local log = require"guihua.log".info
local trace = require"guihua.log".trace

function M.close_view_autocmd(events, winnr)
  api.nvim_command("autocmd " .. table.concat(events, ",") ..
                       " <buffer> ++once lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true)")
end

-- function M.buf_close_view_event(mode, key, bufnr, winnr)
--   local closer = " <Cmd> lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true) <CR>"
--   vim.api.nvim_buf_set_keymap(bufnr, "n", key, closer, {})
-- end

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

return M
