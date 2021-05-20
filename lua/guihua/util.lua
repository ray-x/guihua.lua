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
  local ext = url:match("^.+(%..+)$") or "txt"
  return string.sub(ext, 2)
end

local function get_pads(win_width, text, call_by)
  local margin = win_width - #text - #call_by
  if margin < 0 then
    if #call_by > 1 then
      text = text:sub(1, #text - 20)
    end
  end
  local sz = #text
  if sz < 30 then
    sz = 30
  end
  local pad = 0
  local space = ''
  local i = math.floor((sz + 10) / 10)
  i = i * 10 - #text
  space = string.rep(' ', i)
  return space
end

function M.prepare_for_render(items, opts)
  opts = opts or {}
  if items == nil or #items < 1 then
    print("no item found or empty fields")
    return
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
  local maxLen = 4
  local call_by_presented = false

  opts.width = opts.width or 100
  local win_width = opts.width - 2 -- buf
  for i = 1, #items do
    maxLen = math.max(maxLen, #items[i].text + 7, #items[i].display_filename + #lspapi)
    maxLen = math.min(maxLen, 100)
    if items[i].call_by and #items[i].call_by > 0 then
      call_by_presented = true
    end
  end

  for i = 1, #items do
    local space = ''
    -- trace(items[i], items[i].filename, last_summary_idx, display_items[last_summary_idx].filename)
    if items[i].filename == display_items[last_summary_idx].filename then
      space = get_pads(opts.width, display_items[last_summary_idx].display_filename, lspapi)
      display_items[last_summary_idx].text = string.format("%s  %s%s%s %i", icon,
                                                           display_items[last_summary_idx]
                                                               .display_filename, space, lspapi,
                                                           total_ref_in_file)
      total_ref_in_file = total_ref_in_file + 1
    else
      item = M.clone(items[i])

      space = get_pads(opts.width, item.display_filename, lspapi)
      item.text = string.format("%s  %s%s%s 1", icon, item.display_filename, space, lspapi)

      trace(item.text)
      table.insert(display_items, item)
      total_ref_in_file = 1
      last_summary_idx = #display_items
    end
    item = M.clone(items[i])
    item.text = string.format("%4i:  %s", item.lnum, item.text)
    local call_by = ""
    if item.call_by ~= nil and #item.call_by > 0 then
      log("call_by:", #item.call_by)
      call_by = ' '

      for _, value in pairs(item.call_by) do
        if value.node_text then
          local txt = value.node_text:gsub('%s*[%[%(%{]*%s*$', '')
          local endwise = '{}'
          if value.type == 'method' or value.type == 'function' then
            endwise = '()'
            call_by = ' '
          end
          if #call_by > 6 then
            call_by = call_by .. '  '
          end
          call_by = call_by .. value.kind .. txt .. endwise
          trace(item)
        end
      end
      item.text = item.text:gsub('%s*[%[%(%{]*%s*$', '')

      -- lets show call-by at 64/72/80

      if call_by_presented and #call_by > 1 then
        space = get_pads(win_width, item.text, call_by)
        if #space + #item.text + #call_by >= win_width then
          if #item.text + #call_by > win_width then
            log("exceeding", #item.text, #call_by, win_width)
            space = '   '
          else
            local remain = win_width - #item.text - #call_by
            log("remain", remain)
            space = string.rep(' ', remain)
          end
        end
        item.text = item.text .. space .. call_by
      end
    end
    local tail = display_items[#display_items].text
    if tail ~= item.text then -- deduplicate
      trace(item.text)
      trace(item.call_by)
      table.insert(display_items, item)
    end
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

local has_ts, _ = pcall(require, "nvim-treesitter")
local _, ts_highlight = pcall(require, "nvim-treesitter.highlight")
local _, ts_parsers = pcall(require, "nvim-treesitter.parsers")

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

  has_ts, _ = pcall(require, "nvim-treesitter")
  if not has_ts then
    if has_ts then
      _, ts_highlight = pcall(require, "nvim-treesitter.highlight")
      _, ts_parsers = pcall(require, "nvim-treesitter.parsers")
    else
      -- apply_syntax_to_region ?
      if not lines then
        log("ts not enable, need spcific lines!")
        -- TODO: did not verify this part of code yet
        lines = 12
      end
      apply_syntax_to_region(ft, 1, lines)
      return
    end
  end

  if has_ts then
    local lang = ts_parsers.ft_to_lang(ft)
    if ts_parsers.has_parser(lang) then
      trace("attach ts")
      ts_highlight.attach(bufnr, lang)
      return true
    end
  end

  return false
end

return M
