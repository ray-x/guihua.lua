-- Sorter.lua
-- Sorter interface for Fuzzy
local lev = require'fuzzy.alg.levenshtein'
local fzy = require'fuzzy.alg.fzy'
local Sorter = {}

local function sort(query, collection)
  if query == '' then
    return collection
  end
  -- collection {line, pos, score}
  -- query = query:sub(2, #query)
  local word_scores = {}
  for _, c in ipairs(collection) do
    local word_score = {score=fzy.score(query, c), word=c}
    table.insert(word_scores, word_score)
  end
  word_scores = require'fzy.quicksort'(word_scores, 1, #word_scores)
  local output = {}
  for i=1,#word_scores do
    table.insert(output, word_scores[#word_scores - i+1].word)
  end
  return output
end



function Sorter.fzy(query, collection)
  return sort(query, collection)
end

return Sorter
