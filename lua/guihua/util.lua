local M = {}
local api = vim.api
local log = require "guihua.log".info
local verbose = require "guihua.log".debug

function M.close_view_autocmd(events, winnr)
  api.nvim_command(
    "autocmd " ..
      table.concat(events, ",") .. " <buffer> ++once lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true)"
  )
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
  --api.nvim_command( mode .. "map <buffer> " .. key .. " <Cmd> lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true) <CR>" )
  end
end

function M.trim_space(s)
  return s:match("^%s*(.-)%s*$")
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

local function filename(url)
  return url:match("^.+/(.+)$") or url
end

local function extension(url)
  local ext = url:match("^.+(%..+)$") or 'txt'
  return string.sub(ext, 2)
end

function M.aggregate_filename(items, opts)
  opts = opts or {}
  if items== nil or #items < 1 then
    error("empty fields")
  end
  local item = M.clone(items[1])
  local display_items = {item}
  local last_summary_idx = 1
  local total_ref_in_file = 1
  local icon = " "
  local lspapi = opts.api or "∑"

  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    local fn = filename(items[1].filename)
    local ext = extension(fn)
    icon = devicons.get_icon(fn, ext) or icon
  end
  for i = 1, #items do
    -- verbose(items[i], items[i].filename, last_summary_idx, display_items[last_summary_idx].filename)
    if items[i].filename == display_items[last_summary_idx].filename then
      display_items[last_summary_idx].text =
        string.format(
        "%s  %s  %s %i",
        icon,
        display_items[last_summary_idx].display_filename,
        lspapi,
        total_ref_in_file
      )
      total_ref_in_file = total_ref_in_file + 1
    else
      item = M.clone(items[i])
      item.text = string.format("%s  %s  %s 1", icon, item.display_filename, lspapi)

      verbose(item.text)
      table.insert(display_items, item)
      total_ref_in_file = 1
      last_summary_idx = #display_items
    end
    item = M.clone(items[i])
    item.text = string.format(" %4i:  %s", item.lnum, item.text)
    verbose(item.text)
    table.insert(display_items, item)
  end

  -- display_items[last_summary_idx].text=string.format("%s [%i]", display_items[last_summary_idx].filename,
  -- total_ref_in_file)
  return display_items
end

function M.add_escape(s)
  -- / & ! . ^ * $ \ ?
  local special = {"&", "!", "*", "?", "/"}
  local str = s
  for i = 1, #special do
    str = string.gsub(str, special[i], "\\"..special[i])
  end
  return str
end

return M
