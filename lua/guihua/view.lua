local Rect = require "guihua.rect"
local ViewController = require "guihua.viewctrl"
-- prevent view been generated multiple times

local class = require "middleclass"
local View = class("View", Rect)

local log = require "guihua.log".info
local verbose = require "guihua.log".debug

-- Note, Support only one active view
-- ActiveView = nil
--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  loc='center|up_left|center_right'
  background
  prompt
}

--]]
function View:initialize(...)
  verbose(debug.traceback())
  local opts = select(1, ...) or {}

  log("ctor View start with #items", #opts.data)
  verbose("view start opts", opts)

  Rect.initialize(self, opts)
  if opts.prompt == true then
    self.rect.height = self.rect.height + 1
  end
  self.cursor_pos = {1, 1}
  local loc = nil
  if opts.loc ~= nil then
    local location = require "guihua.location"
    if type(opts.loc) == "function" then
      loc = opts.loc
    elseif type(opts.loc) == "string" then
      loc = location[opts.loc]
    end
  end
  self.prompt = opts.prompt == true and true or false
  self.data = opts.data
  self.ft = opts.ft or "guihua"
  self.display_height = self.rect.height

  log("height: ", self.display_height)

  local floatbuf = require "guihua.floating".floating_buf
  -- listview should not have ft enabled
  self.buf, self.win, self.buf_closer =
    floatbuf({win_width=self.rect.width, win_height = self.rect.height, x = self.rect.pos_x, y=self.rect.pos_y, loc = loc, prompt = self.prompt, enter = opts.enter, ft = opts.ft, relative = opts.relative})
  log("floatbuf created ", self.buf, self.win)
  self:set_bg(opts)
  self:on_draw(self.data)
  if self.prompt then
    vim.cmd("startinsert!")
    log("create prompt view")
  end

  View.static.ActiveView = self
  self:bind_ctrl(opts)
  log("ctor View: end") --, View.ActiveView)--, self)
end

function View.Active()
  if View.ActiveView ~= nil then
    return true
  end
  return false
end

function View:set_bg(opts)
  local bg = opts.bg or "GHBgDark"
  vim.cmd([[hi GHBgDark guifg=#d0c8e4 guibg=#1a101f]])

  local cmd = "Normal:" .. bg .. ",NormalNC:" .. bg
  vim.api.nvim_win_set_option(self.win, "winhl", cmd)
  --def_icon = opts.finder_definition_icon or ' '
  -- self.prompt = opts.prompt or " "
  -- api.nvim_buf_add_highlight(self.contents_buf,-1,"TargetWord",0,#def_icon,self.param_length+#def_icon+3)
end

function View:bind_ctrl(opts)
  if self.ctrl then
    return false
  else
    self.ctrl = ViewController:new(self, opts)
    return true
  end
end

function View:get_ctrl(...)
  return self.ctrl
end

local function draw_table_item(buf, item, pos)
  -- deal with filtered data
  verbose("draw_table", buf, item.text, pos)
  if item.text == nil then
    return
  end
  vim.api.nvim_buf_set_lines(buf, pos, pos, true, {item.text})
  --vim.api.nvim_buf_set_lines(buf, 0, 1, true, '{item.text}')
  if item.pos ~= nil then
    for _, v in pairs(item.pos) do
      vim.fn.matchaddpos("IncSearch", {{pos + 1, v}})
    end
  end
  if item.fzy ~= nil then
    for _, v in pairs(item.fzy.pos) do
      vim.fn.matchaddpos("IncSearch", {{pos + 1, v}})
    end
  end
end

-- draw line text
local function draw_lines(buf, start, end_at, data)
  -- the #data should match or < start~end_at
  if #data < 1 then log("empty body") return end
  verbose("draw_lines", buf, start, end_at, #data, data)
  if data == nil then
    return
  end
  vim.fn.clearmatches()
  vim.api.nvim_buf_set_lines(buf, start, end_at, false, {})
  -- vim.api.nvim_buf_set_lines(buf, start, end_at, true, data)
  local draw_end = math.min(end_at - 1, #data - 1)
  for i = start, draw_end, 1 do
    local l = data[i + 1]
    if l == nil then
      log("draw at failed ", i, data)
    end
    if type(l) == "string" then -- plain text display
      vim.api.nvim_buf_set_lines(buf, i, i, true, {l})
    elseif type(l) == "table" and l.text == nil then -- filtered text
      local line = l[1]
      vim.api.nvim_buf_set_lines(buf, i, i, true, {line})
      local pos = l[2]
      for _, v in pairs(pos) do
        vim.fn.matchaddpos("IncSearch", {{i + 1, v}})
      end
    else
      draw_table_item(buf, l, i)
    end
  end
end

function View:on_draw(data)
  if not vim.api.nvim_buf_is_valid(self.buf) then
    log("buf id invalid", self.buf)
    return
  end
  if data == nil then
    log("on_draw data nil")
    if self.display_data == nil or #self.display_data == 0 then
      log("on_draw nothing to be draw")
    end
    data = self.display_data
  end

  vim.api.nvim_buf_set_option(self.buf, "readonly", false)
  local content = {}
  if type(data) == "string" then
    content = {data}
  else
    content = data
  end

  verbose("draw", data[1], data[2])
  local start = 0
  if self.header ~= nil then
    start = 1
  end
  local end_at = self.display_height -- C index
  if self.prompt == true then
    end_at = end_at - 1
  end
  -- vim.api.nvim_buf_set_lines(self.buf, start, end_at, true, content)
  draw_lines(self.buf, start, end_at, content)
  if self.prompt ~= true then
    vim.api.nvim_buf_set_option(self.buf, "readonly", true)
  end
  -- vim.fn.setpos(".", {0, 1, 1, 0})
end

function View:unbind_ctrl(...)
  if self.ctrl then
    self.ctrl = nil
  end
end

function View:close(...)
  log("close View ", self.win)
  -- vim.api.nvim_win_close(self.win, true)
  if self.buf_closer ~= nil then
    self:buf_closer()
  -- vim.api.nvim_win_close
  end
  self:unbind_ctrl()
  -- View.ActiveView = nil
  log("view closed ")
end

function View.on_close()
  log(debug.traceback())
  if View.ActiveView == nil then
    log("view onclose nil")
    return
  end
  log("view onclose ", View.ActiveView.win)
  View.ActiveView:close()
end

function test()
  package.loaded["guihua"] = nil
  package.loaded["guihua.view"] = nil
  --package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd("packadd guihua.lua")

  local data = {"View: test line should show", "view line2", "view line3", "view line4"}
  local win = View:new({loc = "up_left", rect = {height = 5, pos_x = 120}, prompt = true, data = data})
  log("draw data", data)
  --win:on_draw(data)
  -- vim.cmd("startinsert!")
end

-- test()
return View
