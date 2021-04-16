local rect = require "guihua.rect"
local vctl = require "guihua.viewctrl"
-- prevent view been generated multiple times
if view == nil then
  view = class(rect)
  view._class_name = "View"
end
local log = require "luakit.utils.log".log

-- Note, Support only one active view
Active_view = nil
--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  loc='center|up_left|center_right'
  background
  prompt
}

--]]
function view:ctor(...)
  log("ctor View start:")
  -- log(debug.traceback())
  local opts = select(1, ...) or {}
  self.opts = opts
  self.cursor_pos = {1, 1}
  if opts.loc ~= nil then
    local loc = nil
    local location = require "guihua.location"
    if type(opts.loc) == "function" then
      loc = opts.loc
    elseif type(opts.loc) == "string" then
      loc = location[opts.loc]
    end
  end
  self.prompt = opts.prompt == true and true or false

  self.display_height = self.rect.height or 10
  if opts.header ~= nil then
    self.display_height = self.display_height - 1
  end
  if opts.prompt ~= nil then
    self.display_height = self.display_height - 1
  end
  local floatbuf = require "guihua.floating".floating_buf

  self.buf, self.win, self.buf_closer =
    floatbuf(self.rect.width, self.rect.height, self.pos_x, self.pos_y, nil, self.prompt, nil)
  log("floatbuf created ", self.buf, self.win)
  if self.prompt then
    vim.cmd("startinsert!")
    log("create prompt view")
  end
  self:set_bg()
  self:bind_ctrl(opts)
  Active_view = self
  log("ctor View: end")
end

function view:new(...)
  vim.cmd("highlight default BgDark guibg=#130317")
  view = require "guihua.view"
  -- self.win = new(view, ...)
  -- return self.win
end

function view:set_bg(...)
  local bg = "BgDark"
  if self.opts ~= nil and self.opts.background ~= nil then
    bg = self.opts.background
  end
  local cmd = "Normal:" .. bg .. ",NormalNC:" .. bg
  vim.api.nvim_win_set_option(self.win, "winhl", cmd)
  --def_icon = self.opts.finder_definition_icon or ' '
  -- self.prompt = opts.prompt or " "
  -- api.nvim_buf_add_highlight(self.contents_buf,-1,"TargetWord",0,#def_icon,self.param_length+#def_icon+3)
end

function view:bind_ctrl(opts)
  if self.ctrl then
    return false
  else
    self.ctrl = new(vctl, self)
    return true
  end
end

function view:get_ctrl(...)
  return self.ctrl
end

local function draw_lines(buf, start, end_at, data)
  -- the #data should match or < start~end_at
  if data == nil then
    return
  end
  vim.fn.clearmatches()
  vim.api.nvim_buf_set_lines(buf, start, end_at, true, {})
  -- vim.api.nvim_buf_set_lines(buf, start, end_at, true, data)

  for i = start, #data - 1, 1 do
    local l = data[i + 1]
    if l == nil then
      log("draw at failed ", i, data)
    end
    if type(l) == "string" then
      vim.api.nvim_buf_set_lines(buf, i, end_at, true, {l})
    else
      local line = l[1]
      vim.api.nvim_buf_set_lines(buf, i, end_at, true, {line})
      local pos = l[2]
      for _, v in pairs(pos) do
        vim.fn.matchaddpos("IncSearch", {{i + 1, v}})
      end
    end
  end
end

function view:on_draw(data)
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

  verbose("draw", data)
  local start = 0
  if self.header ~= nil then
    start = 1
  end
  end_at = -1
  if self.prompt == true then
    end_at = -2
  end
  -- vim.api.nvim_buf_set_lines(self.buf, start, end_at, true, content)
  draw_lines(self.buf, start, end_at, content)
  if self.prompt ~= true then
    vim.api.nvim_buf_set_option(self.buf, "readonly", true)
  end
  -- vim.fn.setpos(".", {0, 1, 1, 0})
end

function view:unbind_ctrl(...)
  if self.ctrl then
    delete(self.ctrl)
    self.ctrl = nil
  end
end

function view:dtor(...)
  log("dtor View ", self.win)
  -- vim.api.nvim_win_close(self.win, true)
  if self.buf_closer ~= nil then
    self:buf_closer()
  end
  self:unbind_ctrl()
end

function view.on_close()
  log(debug.traceback())
  log("view onclose ")
  if Active_view == nil then
    return
  end
  Active_view:dtor()
  Active_view = nil
end

function test()
  package.loaded["guihua"] = nil
  package.loaded["guihua.view"] = nil
  --package.loaded.packer_plugins['guihua.lua'].loaded = false
  vim.cmd("packadd guihua.lua")

  vim.g.debug_output = true
  local data = {"View: test line should show", "view line2", "view line3", "view line4"}
  local win = new(view, {loc = "up_left", rect = {height = 5}, prompt = true, data = data})
  log("draw data", data)
  win:on_draw(data)
  vim.cmd("startinsert!")
end

-- test()
return view
