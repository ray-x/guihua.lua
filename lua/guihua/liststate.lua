local util = require('guihua.util')

local ListState = {}
ListState.__index = ListState

local function slice_items(items, start_idx, end_idx)
  local result = {}
  if type(items) ~= 'table' or start_idx > end_idx then
    return result
  end

  for i = start_idx, math.min(end_idx, #items) do
    result[#result + 1] = items[i]
  end
  return result
end

local function contains(items, value)
  return vim.tbl_contains(items or {}, value)
end

local function is_filename_only(item)
  return type(item) == 'table' and item.filename_only == true
end

function ListState.new(opts)
  opts = opts or {}
  local self = setmetatable({}, ListState)
  self.prompt = opts.prompt == true
  self.display_height = opts.display_height or 10
  self.data = opts.data or {}
  self.filtered_data = vim.deepcopy(self.data)
  self.filter_applied = false
  self.selected_line = 1
  self.selected_lines = {}
  self.display_start_at = 1
  self.display_data = {}
  self.search_item = nil
  self:refresh_display()
  return self
end

function ListState:visible_height()
  local height = self.display_height or 0
  if self.prompt then
    height = height - 1
  end
  return math.max(height, 1)
end

function ListState:active_data()
  if self.filter_applied == true then
    return self.filtered_data or {}
  end
  return self.data or {}
end

function ListState:current_item()
  return self:active_data()[self.selected_line]
end

function ListState:cursor_line()
  local data = self:active_data()
  if #data == 0 then
    return 1
  end

  local relative = self.selected_line - self.display_start_at + 1
  return math.max(1, math.min(relative, math.max(#self.display_data, 1)))
end

function ListState:clamp_bounds()
  local data = self:active_data()
  local visible_height = self:visible_height()
  local max_start = math.max(1, #data - visible_height + 1)

  self.display_start_at = math.max(1, math.min(self.display_start_at or 1, max_start))
  if #data == 0 then
    self.selected_line = 1
    return
  end

  self.selected_line = math.max(1, math.min(self.selected_line or 1, #data))
end

function ListState:refresh_display()
  self:clamp_bounds()
  local data = self:active_data()
  local visible_height = self:visible_height()
  self.display_data = slice_items(data, self.display_start_at, self.display_start_at + visible_height - 1)
  return self.display_data
end

function ListState:set_selection(line)
  local previous_start = self.display_start_at
  self.selected_line = line or 1
  self:clamp_bounds()

  if self.selected_line < self.display_start_at then
    self.display_start_at = self.selected_line
  end

  local visible_height = self:visible_height()
  local last_visible = self.display_start_at + visible_height - 1
  if self.selected_line > last_visible then
    self.display_start_at = self.selected_line - visible_height + 1
  end

  self:refresh_display()
  return {
    item = self:current_item(),
    cursor_line = self:cursor_line(),
    redraw = previous_start ~= self.display_start_at,
  }
end

function ListState:move_next()
  local data = self:active_data()
  if #data == 0 then
    return nil
  end

  local next_line = (self.selected_line or 1) + 1
  if next_line > #data then
    return nil
  end

  if is_filename_only(data[next_line]) and self.filter_applied ~= true then
    if next_line + 1 > #data then
      return nil
    end
    next_line = next_line + 1
  end

  return self:set_selection(next_line)
end

function ListState:move_prev()
  local data = self:active_data()
  if #data == 0 then
    return nil
  end

  local prev_line = (self.selected_line or 1) - 1
  if prev_line < 1 then
    return {
      item = data[1],
      cursor_line = 1,
      redraw = false,
    }
  end

  if is_filename_only(data[prev_line]) and self.filter_applied ~= true and prev_line > 1 then
    prev_line = prev_line - 1
  end

  return self:set_selection(prev_line)
end

function ListState:draw_page(offset_direction)
  local data = self:active_data()
  if #data == 0 then
    return nil
  end

  local visible_height = self:visible_height()
  local target = self.display_start_at + offset_direction * visible_height
  target = math.max(1, math.min(target, #data))

  self.display_start_at = target
  self.selected_line = target
  self:refresh_display()

  return {
    item = self:current_item(),
    cursor_line = 1,
    redraw = true,
  }
end

function ListState:select_item(i)
  local data = self:active_data()
  if #data == 0 then
    return nil
  end

  i = math.max(1, math.min(i, #data))

  local idx = nil
  for j = i, math.min(i + 3, #data) do
    if type(data[j]) == 'table' and data[j].idx == i then
      idx = j
      break
    end

    local text = nil
    if type(data[j]) == 'string' then
      text = data[j]
    elseif type(data[j]) == 'table' then
      text = data[j].display_data or data[j].text
    end

    if text ~= nil then
      local found = string.find(text, tostring(i))
      if found ~= nil and found < 4 then
        idx = j
        break
      end
    end
  end

  return self:set_selection(idx or i)
end

function ListState:toggle_current()
  local data = self:active_data()
  local item = data[self.selected_line]
  if item == nil or type(item) ~= 'table' then
    return nil
  end

  if contains(self.selected_lines, self.selected_line) then
    util.tbl_remove(self.selected_lines, self.selected_line)
    item.selected = false
  else
    self.selected_lines[#self.selected_lines + 1] = self.selected_line
    item.selected = true
  end

  self:refresh_display()
  return {
    item = item,
    cursor_line = self:cursor_line(),
    redraw = true,
  }
end

function ListState:apply_filter(filtered_data, search_item)
  self.search_item = search_item
  if search_item == nil or #search_item == 0 then
    self.filter_applied = false
    self.filtered_data = vim.deepcopy(self.data)
  else
    self.filter_applied = true
    self.filtered_data = filtered_data or {}
  end

  self.display_start_at = 1
  self.selected_line = 1
  self:refresh_display()

  return {
    item = self:current_item(),
    cursor_line = 1,
    redraw = true,
  }
end

function ListState:set_data(data)
  self.data = data or {}
  self.filtered_data = vim.deepcopy(self.data)
  self.filter_applied = false
  self.search_item = nil
  self.selected_line = 1
  self.display_start_at = 1
  self.selected_lines = {}
  self:refresh_display()
end

return ListState
