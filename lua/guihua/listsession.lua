local api = vim.api

local ListSession = {}
ListSession.__index = ListSession

local next_session_id = 0

local function alloc_session_id()
  next_session_id = next_session_id + 1
  return next_session_id
end

local function is_valid_view(view)
  return view ~= nil and view.win ~= nil and api.nvim_win_is_valid(view.win)
end

function ListSession.new(opts)
  opts = opts or {}
  local self = setmetatable({}, ListSession)
  self.id = opts.id or alloc_session_id()
  self.kind = opts.kind or 'list'
  self.list_view = nil
  self.controller = nil
  self.preview_view = nil
  self.closed = false
  return self
end

function ListSession:attach_list_view(view)
  self.closed = false
  self.list_view = view
  if view ~= nil then
    view.session = self
  end
end

function ListSession:detach_list_view(view)
  if view == nil or self.list_view == view then
    self.list_view = nil
  end
end

function ListSession:attach_controller(controller)
  self.closed = false
  self.controller = controller
  if controller ~= nil then
    controller.session = self
  end
end

function ListSession:detach_controller(controller)
  if controller == nil or self.controller == controller then
    self.controller = nil
  end
end

function ListSession:resolve_preview_view(preview)
  if preview ~= nil and preview.class ~= nil and preview.class.name == 'TextView' and is_valid_view(preview) then
    return preview
  end
  return nil
end

function ListSession:attach_preview_view(preview)
  local TextView = require('guihua.textview')
  if TextView.is_preview_spec(preview) then
    self.preview_view = TextView.open_preview(self.preview_view, preview)
    return self.preview_view
  end

  local current_preview = self:resolve_preview_view(self.preview_view)
  local next_preview = self:resolve_preview_view(preview)
  if current_preview ~= nil and current_preview ~= next_preview then
    self:close_preview()
  end

  self.preview_view = next_preview
  return self.preview_view
end

function ListSession:close_preview()
  local preview = self.preview_view
  self.preview_view = nil
  if preview == nil or preview.class == nil or preview.class.name ~= 'TextView' then
    return
  end

  local TextView = require('guihua.textview')
  if TextView.ActiveTextView == preview then
    TextView.static.ActiveTextView = nil
  end
  if is_valid_view(preview) then
    preview:close()
  end
end

function ListSession:is_valid_list_view()
  return is_valid_view(self.list_view)
end

function ListSession:is_empty()
  return self.list_view == nil and self.controller == nil and self.preview_view == nil
end

return ListSession
