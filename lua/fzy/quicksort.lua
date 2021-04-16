-- Quick sort

local function tprint(tbl, indent)
  if not indent then
    indent = 0
  end
  for k, v in pairs(tbl) do
    local formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent + 1)
    elseif type(v) == "boolean" then
      print(formatting .. tostring(v))
    else
      print(formatting .. v)
    end
  end
end

local function partition(arr, low, high)
  local i = (low - 1)
  local pivot = arr[high]

  for j = low, high - 1 do
    if arr[j][3] >= pivot[3] then
      i = i + 1
      arr[i], arr[j] = arr[j], arr[i]
    end
  end
  arr[i + 1], arr[high] = arr[high], arr[i + 1]
  return (i + 1)
end

local function table_with_size(size, default_value)
  local t = {}
  for i = 1, size do
    table.insert(t, default_value)
  end
  return t
end

local function quicksort(arr, l, h)
  l = l or 1
  h = h or #arr
  local size = h - l + 1
  local stack = table_with_size(size, 0)

  local top = -1
  top = top + 1
  stack[top] = l
  top = top + 1
  stack[top] = h

  while top >= 0 do
    h = stack[top]
    top = top - 1
    l = stack[top]
    top = top - 1
    local p = partition(arr, l, h)
    if p - 1 > l then
      top = top + 1
      stack[top] = l
      top = top + 1
      stack[top] = p - 1
    end
    if p + 1 < h then
      top = top + 1
      stack[top] = p + 1
      top = top + 1
      stack[top] = h
    end
  end
  return arr
end

return quicksort
