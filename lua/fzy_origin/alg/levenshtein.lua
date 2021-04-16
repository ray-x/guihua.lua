local quicksort = require'fuzzy.lib.alg.quicksort'

local __ngrams_cache = {}

local function ngrams_of(s, n)
  n = n or 3
  local ngrams = __ngrams_cache[s] or {}
  if #vim.split(s, ' ') > 1 then
    local words = vim.split(s, ' ')
    for _, w in ipairs(words) do
      if __ngrams_cache[w] == nil then
        __ngrams_cache[w] = ngrams_of(w)
      end
      for _, c in ipairs(__ngrams_cache[w]) do
        table.insert(ngrams, c)
      end
    end
  end
  if #ngrams > 0 then
    return ngrams
  end
  for i=1,#s do
    local last = i+n-1
    if last >= #s then
      last = #s
    end
    local this_ngram = string.sub(s, i, last)    
    table.insert(ngrams, this_ngram)
  end
  __ngrams_cache[s] = ngrams
  return ngrams
end

local __cache_score = {}

local function levenshtein_distance(str1, str2)
  if str1 == str2 then
    return 0
  end
  if #str1 == 0 then
    return #str2
  end
  if #str2 == 0 then
    return #str1
  end
  if __cache_score[str1..str2] ~= nil then
    return __cache_score[str1..str2]
  end
  local len1, len2 = #str1, #str2
  local char1, char2, distance = {}, {}, {}
  str1:gsub('.', function (c) table.insert(char1, c) end)
  str2:gsub('.', function (c) table.insert(char2, c) end)
  for i = 0, len1 do distance[i] = {} end
  for i = 0, len1 do distance[i][0] = i end
  for i = 0, len2 do distance[0][i] = i end
  for i = 1, len1 do
      for j = 1, len2 do
          distance[i][j] = math.min(
              distance[i-1][j  ] + 1,
              distance[i  ][j-1] + 1,
              distance[i-1][j-1] + (char1[i] == char2[j] and 0 or 1)
              )
      end
  end
  __cache_score[str1..str2] = distance[len1][len2]
  return distance[len1][len2]
end

local function sort(list)
  list = quicksort(list, 1, #list)
  return list
end

local function match(query, collection)
  local list = {}
  for i=1,#collection do
    if query == nil or collection[i] == nil then
      goto continue
    end
    local ngrams_data = ngrams_of(string.gsub(collection[i], ' ', ''), 3)
    local ngrams_query = ngrams_of(query:gsub(' ', ''), 3)
    local total = 0
    for _, nq in ipairs(ngrams_query) do
      local min_distance_of_ngrams = 100000
      for _, nd in ipairs(ngrams_data) do
        local distance = levenshtein_distance(string.lower(nq), string.lower(nd))
        if distance < min_distance_of_ngrams then
          min_distance_of_ngrams = distance
        end
      end
      total = total + min_distance_of_ngrams 
    end
    local word_score = {score=total, word=collection[i]}
    table.insert(list, word_score)
    ::continue::
  end
  local output = {}
  list = sort(list)
  for _, v in ipairs(list) do
    table.insert(output, v.word) 
  end
  return output 
end

return {
  match = match,
  clean = function()
    __cache_score = {}
    __ngrams_cache = {}
  end,
}
