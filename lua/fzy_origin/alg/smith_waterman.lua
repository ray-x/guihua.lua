-- Smith-Waterman algorithm
-- https://tiefenauer.github.io/blog/smith-waterman/
local function cartesian(a1, a2)
  local out = {}
  for _, i in ipairs(a1) do
    for _,j in ipairs(a2) do
      table.insert(out, {i,j})
    end
  end
  return out
end

local function range(start, _end)
  local out = {}
  for i=start,_end do
    table.insert(out, i)
  end
  return out
end
local function tprint (tbl, indent)
  if not indent then indent = 0 end
  if not tbl then return end 
  for k, v in pairs(tbl) do
    local formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))      
    else
      print(formatting .. v)
    end
  end
end




local function fill_with_zeros(a, x, y)
  for i=1,x do
    local inner = {}
    for j=1,y do
      table.insert(inner, 0)
    end
    table.insert(a, inner)
  end
  return a
end

local function matrix(s1, s2, match_score, gap_cost)
  match_score = match_score or 3
  gap_cost = gap_cost or 2
  local H = {}
  H = fill_with_zeros(H, #s1+1, #s2+1)
  -- tprint(H)
  local loop_var = cartesian(range(2, #s1+1), range(2, #s2+1))
  -- tprint(loop_var)
  
  for _, c in ipairs(loop_var) do
    local i = c[1]
    local j = c[2]
    local p = match_score
    if string.sub(s1, i-1,i-1) == string.sub(s2, j-1, j-1) then
      p = -match_score
    end
    -- print(i,j)
    local match = H[i-1][j-1] + p
    local delete = H[i-1][j] - gap_cost
    local insert = H[i][j-1] - gap_cost
    -- print(match, delete, insert)
    local to_put = math.max(match, delete, insert, 0)
    -- print(to_put)
    H[i][j] = to_put
  end
  return H
end

local function flip_matrix_0(H)
  local new = {}
  for i=1,#H do
    table.insert(new, H[#H+1-i])
  end
  return new 
end


local function flip_matrix_1(H)
  for i=1,#H do
    local new_ax = {}
    for j=1,#H[i] do
      table.insert(new_ax, H[i][#H+1-j])
    end
    H[i] = new_ax
    new_ax = {}
  end
  return H
end
local function flip_matrix(H, axis)
  axis = axis or 0
  if axis == 0 then
    return flip_matrix_0(H)
  else
    return flip_matrix_1(H)
  end
end

local function matrix_argmax(H)
  local max = 0
  for i=1,#H do
    for j=1,#H[i] do
      if H[i][j] > max then
        max = H[i][j]
      end
    end
  end
  return max
end

local function matrix_unravel_index(idx, H)
  local counter = 1
  for i=1,#H do
    for j=1,#H[i] do
      if counter == idx then
        return i,j
      end
      counter = counter + 1
    end
  end
end

local function matrix_shape(H)
  return #H, #H[1]
end

local function traceback(H, b, b_, old_i)
  b_ = b_ or ''
  old_i = old_i or 0
  local h_flip = flip_matrix(flip_matrix(H, 0), 1)
  tprint(h_flip)
  local i_, j_ = matrix_unravel_index(matrix_argmax(h_flip), h_flip)
  -- print(i_, j_)
  local sh1, sh2 = matrix_shape(h_flip)
  local i, j = sh1-i_, sh2-j_ 
  -- print(i,j)
  if H[i][j] == 0 then
    return b_, j
  end
  if old_i -i > 1 then
    b_ = b[j-1]+'-'+b_
  else
    b_ = b[j-1]+b_
  end
  local new_h = {}
  for x=1,i do
    local hh = {}
    for y=1,j do
      table.insert(hh, H[i][j])
    end
    table.insert(new_h, hh)
  end
  return traceback(new_h, b, b_, i)
end
H = matrix('abc', 'abc')
b_, pos = traceback(H, 'abc')
print(b_, pos)



