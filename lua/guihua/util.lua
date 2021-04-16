local M = {}
local api = vim.api
local log = require "guihua.log".info

function M.close_view_autocmd(events, winnr)
  api.nvim_command(
    "autocmd " ..
      table.concat(events, ",") .. " <buffer> ++once lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true)"
  )
end

function M.close_view_event(mode, key, winnr)
  api.nvim_command(
    mode .. "map <buffer> " .. key .. " <Cmd> lua pcall(vim.api.nvim_win_close, " .. winnr .. ", true) <CR>"
  )
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
  return url:match("^.+/(.+)$")
end

local function extension(url)
  local ext = url:match("^.+(%..+)$")
  return string.sub(ext, 2)
end

function M.aggregate_filename(items)
  local item = M.clone(items[1])
  local display_items = {item}
  local last_summary_idx = 1
  local total_ref_in_file = 1

  for i = 1, #items do
    local icon = " "
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
      local fn = filename(items[i].filename)
      local ext = extension(fn)
      icon = devicons.get_icon(fn, ext) or icon
    end

    if items[i].filename == display_items[last_summary_idx].filename then
      display_items[last_summary_idx].text =
        string.format("%s %s  ∑  %i", icon, display_items[last_summary_idx].display_filename, total_ref_in_file)
      total_ref_in_file = total_ref_in_file + 1
    else
      item = M.clone(items[i])
      item.text = string.format("%s  %s ∑ 1", icon, item.display_filename)

      log(item.text)
      table.insert(display_items, item)
      total_ref_in_file = 1
      last_summary_idx = #display_items
    end
    item = M.clone(items[i])
    item.text = string.format(" %i: %s", item.lnum, item.text)
    log(item.text)
    table.insert(display_items, item)
  end

  -- display_items[last_summary_idx].text=string.format("%s [%i]", display_items[last_summary_idx].filename,
  -- total_ref_in_file)
  return display_items
end

return M
