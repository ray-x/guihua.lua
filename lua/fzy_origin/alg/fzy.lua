-- Fzy sorting algorithm
-- credits to: https://github.com/swarn/fzy-lua

local helpers = require'fuzzy.lib.helpers'
local SCORE_GAP_LEADING = -0.005
local SCORE_GAP_TRAILING = -0.005
local SCORE_GAP_INNER = -0.01
local SCORE_MATCH_CONSECUTIVE = 1.0
local SCORE_MATCH_SLASH = 0.9
local SCORE_MATCH_WORD = 0.8
local SCORE_MATCH_CAPITAL = 0.7
local SCORE_MATCH_DOT = 0.6
local SCORE_MAX = math.huge
local SCORE_MIN = -math.huge
local MATCH_MAX_LENGTH = 1024

local fzy = {}

-- Return `true` if `needle` is a subsequence of `haystack`.
function fzy.has_match(needle, haystack, case_sensitive)
  if not case_sensitive then
    needle = string.lower(needle)
    haystack = string.lower(haystack)
  end

  local j = 1
  for i = 1, string.len(needle) do
    j = string.find(haystack, needle:sub(i, i), j, true)
    if not j then
      return false
    else
      j = j + 1
    end
  end

  return true
end

local function is_lower(c)
  return c:match("%l")
end

local function is_upper(c)
  return c:match("%u")
end

local function precompute_bonus(haystack)
  local match_bonus = {}

  local last_char = "/"
  for i = 1, string.len(haystack) do
    local this_char = haystack:sub(i, i)
    if last_char == "/" or last_char == "\\" then
      match_bonus[i] = SCORE_MATCH_SLASH
    elseif last_char == "-" or last_char == "_" or last_char == " " then
      match_bonus[i] = SCORE_MATCH_WORD
    elseif last_char == "." then
      match_bonus[i] = SCORE_MATCH_DOT
    elseif is_lower(last_char) and is_upper(this_char) then
      match_bonus[i] = SCORE_MATCH_CAPITAL
    else
      match_bonus[i] = 0
    end

    last_char = this_char
  end

  return match_bonus
end

local function compute(needle, haystack, D, M, case_sensitive)
  -- Note that the match bonuses must be computed before the arguments are
  -- converted to lowercase, since there are bonuses for camelCase.
  local match_bonus = precompute_bonus(haystack)
  local n = string.len(needle)
  local m = string.len(haystack)

  if not case_sensitive then
    needle = string.lower(needle)
    haystack = string.lower(haystack)
  end

  -- Because lua only grants access to chars through substring extraction,
  -- get all the characters from the haystack once now, to reuse below.
  local haystack_chars = {}
  for i = 1, m do
    haystack_chars[i] = haystack:sub(i, i)
  end

  for i = 1, n do
    D[i] = {}
    M[i] = {}

    local prev_score = SCORE_MIN
    local gap_score = i == n and SCORE_GAP_TRAILING or SCORE_GAP_INNER
    local needle_char = needle:sub(i, i)

    for j = 1, m do
      if needle_char == haystack_chars[j] then
        local score = SCORE_MIN
        if i == 1 then
          score = ((j - 1) * SCORE_GAP_LEADING) + match_bonus[j]
        elseif j > 1 then
          local a = M[i - 1][j - 1] + match_bonus[j]
          local b = D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE
          score = math.max(a, b)
        end
        D[i][j] = score
        prev_score = math.max(score, prev_score + gap_score)
        M[i][j] = prev_score
      else
        D[i][j] = SCORE_MIN
        prev_score = prev_score + gap_score
        M[i][j] = prev_score
      end
    end
  end
end

-- Compute a matching score for two strings.
--
-- Where `needle` is a subsequence of `haystack`, this returns a score
-- measuring the quality of their match. Better matches get higher scores.
--
-- `needle` must be a subsequence of `haystack`, the result is undefined
-- otherwise. Call `has_match()` before calling `score`.
--
-- returns `get_score_min()` where a or b are longer than `get_max_length()`
--
-- returns `get_score_min()` when a or b are empty strings.
--
-- returns `get_score_max()` when a and b are the same string.
--
-- When the return value is not covered by the above rules, it is a number
-- in the range (`get_score_floor()`, `get_score_ceiling()`)
function fzy.score(needle, haystack, case_sensitive)
  local n = string.len(needle)
  local m = string.len(haystack)

  if n == 0 or m == 0 or m > MATCH_MAX_LENGTH or n > MATCH_MAX_LENGTH then
    return SCORE_MIN
  elseif n == m then
    return SCORE_MAX
  else
    local D = {}
    local M = {}
    compute(needle, haystack, D, M, case_sensitive)
    return M[n][m]
  end
end

-- Find the locations where fzy matched a string.
--
-- Returns {score, indices}, where indices is an array showing where each
-- character of the needle matches the haystack in the best match.
function fzy.score_and_positions(needle, haystack, case_sensitive)
  local n = string.len(needle)
  local m = string.len(haystack)

  if n == 0 or m == 0 or m > MATCH_MAX_LENGTH or n > MATCH_MAX_LENGTH then
    return SCORE_MIN, {}
  elseif n == m then
    local consecutive = {}
    for i = 1, n do
      consecutive[i] = i
    end
    return SCORE_MAX, consecutive
  end

  local D = {}
  local M = {}
  compute(needle, haystack, D, M, case_sensitive)

  local positions = {}
  local match_required = false
  local j = m
  for i = n, 1, -1 do
    while j >= 1 do
      if D[i][j] ~= SCORE_MIN and (match_required or D[i][j] == M[i][j]) then
        match_required = (i ~= 1) and (j ~= 1) and (
        M[i][j] == D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE)
        positions[i] = j
        j = j - 1
        break
      else
        j = j - 1
      end
    end
  end

  return M[n][m], positions
end

-- Return only the positions of a match.
function fzy.positions(needle, haystack, case_sensitive)
  local _, positions = fzy.score_and_positions(needle, haystack, case_sensitive)
  return positions
end

function fzy.get_score_min()
  return SCORE_MIN
end

function fzy.get_score_max()
  return SCORE_MAX
end

function fzy.get_max_length()
  return MATCH_MAX_LENGTH
end

function fzy.get_score_floor()
  return MATCH_MAX_LENGTH * SCORE_GAP_INNER
end

function fzy.get_score_ceiling()
  return MATCH_MAX_LENGTH * SCORE_MATCH_CONSECUTIVE
end

function fzy.get_implementation_name()
  return "lua"
end


function fzy.sort(query, collection)
  if query == '' then
    return collection
  end
  query = query:sub(2, #query)
  local word_scores = {}
  for _, c in ipairs(collection) do
    local word_score = {score=fzy.score(query, c), word=c}
    table.insert(word_scores, word_score)
  end
  word_scores = require'fuzzy.lib.alg.quicksort'(word_scores, 1, #word_scores)
  local output = {}
  for i=1,#word_scores do
    table.insert(output, word_scores[#word_scores - i+1].word)
  end
  return output
end

return fzy

