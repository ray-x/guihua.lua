local api = vim.api
local ListSession = require('guihua.listsession')
local View = require('guihua.view')

local SessionRegistry = {
  sessions = {},
  session_order = {},
  sessions_by_buf = {},
  sessions_by_win = {},
}

local function resolve_session(session)
  if session == nil then
    return nil
  end
  if type(session) == 'number' then
    return SessionRegistry.sessions[session]
  end
  if session.id ~= nil and SessionRegistry.sessions[session.id] == nil then
    SessionRegistry.sessions[session.id] = session
  end
  return session
end

local function remove_from_order(session_id)
  for i = #SessionRegistry.session_order, 1, -1 do
    if SessionRegistry.session_order[i] == session_id then
      table.remove(SessionRegistry.session_order, i)
      return
    end
  end
end

function SessionRegistry.get_active()
  for i = #SessionRegistry.session_order, 1, -1 do
    local session = resolve_session(SessionRegistry.session_order[i])
    if session ~= nil and session:is_valid_list_view() then
      return session
    end
    if session ~= nil then
      SessionRegistry.prune(session)
    else
      table.remove(SessionRegistry.session_order, i)
    end
  end
  return nil
end

local function sync_active_view()
  local active_session = SessionRegistry.get_active()
  View.static.ActiveView = active_session and active_session.list_view or nil
end

function SessionRegistry.ensure(session)
  session = resolve_session(session)
  if session ~= nil then
    return session
  end

  session = ListSession.new()
  SessionRegistry.sessions[session.id] = session
  return session
end

function SessionRegistry.activate(session)
  session = SessionRegistry.ensure(session)
  remove_from_order(session.id)
  table.insert(SessionRegistry.session_order, session.id)
  sync_active_view()
  return session
end

function SessionRegistry.get(session_id)
  return resolve_session(session_id)
end

function SessionRegistry.get_by_buf(bufnr)
  local session_id = SessionRegistry.sessions_by_buf[bufnr]
  local session = resolve_session(session_id)
  if session ~= nil and session.list_view ~= nil and session.list_view.buf == bufnr then
    return session
  end
  if session_id ~= nil then
    SessionRegistry.sessions_by_buf[bufnr] = nil
  end
  return nil
end

function SessionRegistry.get_by_win(winnr)
  local session_id = SessionRegistry.sessions_by_win[winnr]
  local session = resolve_session(session_id)
  if session ~= nil and session.list_view ~= nil and session.list_view.win == winnr then
    return session
  end
  if session_id ~= nil then
    SessionRegistry.sessions_by_win[winnr] = nil
  end
  return nil
end

function SessionRegistry.current()
  return SessionRegistry.get_by_buf(api.nvim_get_current_buf())
    or SessionRegistry.get_by_win(api.nvim_get_current_win())
    or SessionRegistry.get_active()
end

function SessionRegistry.attach_list_view(session, view)
  session = SessionRegistry.ensure(session)
  session:attach_list_view(view)
  if view ~= nil and view.buf ~= nil then
    SessionRegistry.sessions_by_buf[view.buf] = session.id
  end
  if view ~= nil and view.win ~= nil then
    SessionRegistry.sessions_by_win[view.win] = session.id
  end
  SessionRegistry.activate(session)
  return session
end

function SessionRegistry.detach_list_view(session, view)
  session = resolve_session(session)
    or (view ~= nil and (SessionRegistry.get_by_buf(view.buf) or SessionRegistry.get_by_win(view.win)))
  if session == nil then
    return
  end

  local list_view = view or session.list_view
  if list_view ~= nil and list_view.buf ~= nil and SessionRegistry.sessions_by_buf[list_view.buf] == session.id then
    SessionRegistry.sessions_by_buf[list_view.buf] = nil
  end
  if list_view ~= nil and list_view.win ~= nil and SessionRegistry.sessions_by_win[list_view.win] == session.id then
    SessionRegistry.sessions_by_win[list_view.win] = nil
  end

  session:detach_list_view(list_view)
  if not session:is_valid_list_view() then
    remove_from_order(session.id)
  end
  SessionRegistry.prune(session)
  sync_active_view()
end

function SessionRegistry.attach_controller(session, controller)
  session = SessionRegistry.ensure(session)
  session:attach_controller(controller)
  return session
end

function SessionRegistry.detach_controller(session, controller)
  session = resolve_session(session)
  if session == nil then
    return
  end
  session:detach_controller(controller)
  SessionRegistry.prune(session)
end

function SessionRegistry.attach_preview(session, preview)
  session = SessionRegistry.ensure(session)
  return session:attach_preview_view(preview)
end

function SessionRegistry.close_preview(session)
  session = resolve_session(session)
  if session == nil then
    return
  end
  session:close_preview()
  SessionRegistry.prune(session)
end

function SessionRegistry.prune(session)
  session = resolve_session(session)
  if session == nil or not session:is_empty() then
    return
  end
  SessionRegistry.sessions[session.id] = nil
  remove_from_order(session.id)
  sync_active_view()
end

return SessionRegistry
