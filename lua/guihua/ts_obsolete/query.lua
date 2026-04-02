local api = vim.api
local tsrange = require('guihua.ts_obsolete.tsrange')
local utils = require('guihua.ts_obsolete.utils')
local caching = require('guihua.ts_obsolete.caching')

local M = {}

local EMPTY_ITER = function() end

M.built_in_query_groups = { 'highlights', 'locals', 'folds', 'indents', 'injections' }

-- Creates a function that checks whether a given query exists
-- for a specific language.
---@param query string
---@return fun(string): boolean
local function get_query_guard(query)
  return function(lang)
    -- return M.has_query_files(lang, query)

    return vim.treesitter.query.get(lang, query) ~= nil
  end
end

for _, query in ipairs(M.built_in_query_groups) do
  M['has_' .. query] = get_query_guard(query)
end

---@deprecated Use vim.api.nvim_get_runtime_file('queries/*/*.scm', true) and parse filenames directly
---@return string[]
function M.available_query_groups()
  vim.notify_once(
    'query.available_query_groups() is obsolete: use nvim_get_runtime_file("queries/*/*.scm", true)',
    vim.log.levels.WARN
  )
  local query_files = api.nvim_get_runtime_file('queries/*/*.scm', true)
  local groups = {}
  for _, f in ipairs(query_files) do
    groups[vim.fn.fnamemodify(f, ':t:r')] = true
  end
  local list = {}
  for k, _ in pairs(groups) do
    table.insert(list, k)
  end
  return list
end

do
  local query_cache = caching.create_buffer_cache()

  local function update_cached_matches(bufnr, changed_tick, query_group)
    query_cache.set(query_group, bufnr, {
      tick = changed_tick,
      cache = M.collect_group_results(bufnr, query_group) or {},
    })
  end

  ---@deprecated Use vim.treesitter.query.get(lang, query_group) and query:iter_matches() directly
  ---@param bufnr integer
  ---@param query_group string
  ---@return any
  function M.get_matches(bufnr, query_group)
    vim.notify_once(
      'query.get_matches() is obsolete: use vim.treesitter.query.get(lang, query_group) + query:iter_matches()',
      vim.log.levels.WARN
    )
    bufnr = bufnr or api.nvim_get_current_buf()
    local cached_local = query_cache.get(query_group, bufnr)
    if not cached_local or api.nvim_buf_get_changedtick(bufnr) > cached_local.tick then
      update_cached_matches(bufnr, api.nvim_buf_get_changedtick(bufnr), query_group)
    end

    return query_cache.get(query_group, bufnr).cache
  end
end

---@param lang string
---@param query_name string
---@return string[]
local function runtime_queries(lang, query_name)
  return api.nvim_get_runtime_file(string.format('queries/%s/%s.scm', lang, query_name), true) or {}
end

---@type table<string, table<string, boolean>>
local query_files_cache = {}

---@deprecated Use vim.treesitter.query.get(lang, query_name) ~= nil to check availability
---@param lang string
---@param query_name string
---@return boolean
function M.has_query_files(lang, query_name)
  vim.notify_once(
    'query.has_query_files() is obsolete: use vim.treesitter.query.get(lang, query_name) ~= nil',
    vim.log.levels.WARN
  )
  if not query_files_cache[lang] then
    query_files_cache[lang] = {}
  end
  if query_files_cache[lang][query_name] == nil then
    local files = runtime_queries(lang, query_name)
    query_files_cache[lang][query_name] = files and #files > 0
  end
  return query_files_cache[lang][query_name]
end

do
  local mt = {}
  mt.__index = function(tbl, key)
    if rawget(tbl, key) == nil then
      rawset(tbl, key, {})
    end
    return rawget(tbl, key)
  end

  -- cache will auto set the table for each lang if it is nil
  ---@type table<string, table<string, Query>>
  local cache = setmetatable({}, mt)

  ---@deprecated Use vim.treesitter.query.get(lang, query_name) which has its own caching
  ---@param lang string
  ---@param query_name string
  function M.get_query(lang, query_name)
    vim.notify_once(
      'query.get_query() is obsolete: use vim.treesitter.query.get(lang, query_name)',
      vim.log.levels.WARN
    )
    if cache[lang][query_name] == nil then
      -- cache[lang][query_name] = ts.get_query(lang, query_name)
      cache[lang][query_name] = vim.treesitter.query.get(lang, query_name) --ts.get_query(lang, query_name)
    end

    return cache[lang][query_name]
  end

  -- Invalidates the query file cache.
  --
  -- If lang and query_name is both present, will reload for only the lang and query_name.
  -- If only lang is present, will reload all query_names for that lang
  -- If none are present, will reload everything
  ---@deprecated No longer needed; vim.treesitter.query.get() manages its own cache
  ---@param lang? string
  ---@param query_name? string
  function M.invalidate_query_cache(lang, query_name)
    vim.notify_once(
      'query.invalidate_query_cache() is obsolete: vim.treesitter.query.get() manages its own cache',
      vim.log.levels.WARN
    )
    if lang and query_name then
      cache[lang][query_name] = nil
      if query_files_cache[lang] then
        query_files_cache[lang][query_name] = nil
      end
    elseif lang and not query_name then
      query_files_cache[lang] = nil
      for query_name0, _ in pairs(cache[lang]) do
        M.invalidate_query_cache(lang, query_name0)
      end
    elseif not lang and not query_name then
      query_files_cache = {}
      for lang0, _ in pairs(cache) do
        for query_name0, _ in pairs(cache[lang0]) do
          M.invalidate_query_cache(lang0, query_name0)
        end
      end
    else
      error('Cannot have query_name by itself!')
    end
  end
end

---@deprecated No longer needed; vim.treesitter.query.get() manages its own cache
---@param fname string
function M.invalidate_query_file(fname)
  vim.notify_once(
    'query.invalidate_query_file() is obsolete: vim.treesitter.query.get() manages its own cache',
    vim.log.levels.WARN
  )
  local fnamemodify = vim.fn.fnamemodify
  M.invalidate_query_cache(fnamemodify(fname, ':p:h:t'), fnamemodify(fname, ':t:r'))
end

---@class QueryInfo
---@field root TSNode
---@field source integer
---@field start integer
---@field stop integer

---@param bufnr integer
---@param query_name string
---@param root TSNode
---@param root_lang string|nil
---@return Query|nil, QueryInfo|nil
local function prepare_query(bufnr, query_name, root, root_lang)
  local parsers = require('guihua.ts_obsolete.parsers')
  local buf_lang = parsers.get_buf_lang(bufnr)

  if not buf_lang then
    return
  end

  local parser = vim.treesitter.get_parser(bufnr, buf_lang)
  if not parser then
    return
  end

  if not root then
    local first_tree = parser:trees()[1]

    if first_tree then
      root = first_tree:root()
    end
  end

  if not root then
    return
  end

  local range = { root:range() }

  if not root_lang then
    local lang_tree = parser:language_for_range(range)

    if lang_tree then
      root_lang = lang_tree:lang()
    end
  end

  if not root_lang then
    return
  end

  -- local query = M.get_query(root_lang, query_name)
  local query = vim.treesitter.query.get(root_lang, query_name)
  if not query then
    return
  end

  return query,
    {
      root = root,
      source = bufnr,
      start = range[1],
      -- The end row is exclusive so we need to add 1 to it.
      stop = range[3] + 1,
    }
end

---@deprecated Internal helper, no core replacement. Use vim.treesitter.query.get() + query:iter_matches() instead.
---@param object any
---@param path string[]
---@param value any
function M.insert_to_path(object, path, value)
  local curr_obj = object

  for index = 1, (#path - 1) do
    if curr_obj[path[index]] == nil then
      curr_obj[path[index]] = {}
    end

    curr_obj = curr_obj[path[index]]
  end

  curr_obj[path[#path]] = value
end

---@deprecated Use query:iter_matches(root, bufnr, start_row, end_row) directly
---@param query Query
---@param bufnr integer
---@param start_row integer
---@param end_row integer
function M.iter_prepared_matches(query, qnode, bufnr, start_row, end_row)
  -- vim.notify_once(
  -- 'query.iter_prepared_matches() is obsolete: use query:iter_matches(root, bufnr, start, stop) directly',
  -- vim.log.levels.WARN
  -- )
  -- A function that splits  a string on '.'
  ---@param to_split string
  ---@return string[]
  local function split(to_split)
    local t = {}
    for str in string.gmatch(to_split, '([^.]+)') do
      table.insert(t, str)
    end

    return t
  end

  local matches = query:iter_matches(qnode, bufnr, start_row, end_row, { all = false })

  local function iterator()
    local pattern, match, metadata = matches()
    if pattern ~= nil then
      local prepared_match = {}

      -- Extract capture names from each match
      for id, node in pairs(match) do
        local name = query.captures[id] -- name of the capture in the query
        if name ~= nil then
          local path = split(name .. '.node')
          M.insert_to_path(prepared_match, path, node)
          local metadata_path = split(name .. '.metadata')
          M.insert_to_path(prepared_match, metadata_path, metadata[id])
        end
      end

      -- Add some predicates for testing
      ---@type string[][] ( TODO: make pred type so this can be pred[])
      local preds = query.info.patterns[pattern]
      if preds then
        for _, pred in pairs(preds) do
          -- functions
          if pred[1] == 'set!' and type(pred[2]) == 'string' then
            M.insert_to_path(prepared_match, split(pred[2]), pred[3])
          end
          if pred[1] == 'make-range!' and type(pred[2]) == 'string' and #pred == 4 then
            M.insert_to_path(
              prepared_match,
              split(pred[2] .. '.node'),
              tsrange.TSRange.from_nodes(bufnr, match[pred[3]], match[pred[4]])
            )
          end
        end
      end

      return prepared_match
    end
  end
  return iterator
end

-- Return all nodes corresponding to a specific capture path (like @definition.var, @reference.type)
-- Works like M.get_references or M.get_scopes except you can choose the capture
-- Can also be a nested capture like @definition.function to get all nodes defining a function.
--
---@param bufnr integer the buffer
---@param captures string|string[]
---@param query_group string the name of query group (highlights or injections for example)
---@param root TSNode|nil node from where to start the search
---@param lang string|nil the language from where to get the captures.
---              Root nodes can have several languages.
---@deprecated Use vim.treesitter.query.get(lang, query_group) + query:iter_captures() directly
---@return table|nil
function M.get_capture_matches(bufnr, captures, query_group, root, lang)
  -- vim.notify_once(
  -- 'query.get_capture_matches() is obsolete: use vim.treesitter.query.get(lang, group) + query:iter_captures()',
  -- vim.log.levels.WARN
  -- )
  if type(captures) == 'string' then
    captures = { captures }
  end
  local strip_captures = {} ---@type string[]
  for i, capture in ipairs(captures) do
    if capture:sub(1, 1) ~= '@' then
      error('Captures must start with "@"')
      return
    end
    -- Remove leading "@".
    strip_captures[i] = capture:sub(2)
  end

  local matches = {}
  for match in M.iter_group_results(bufnr, query_group, root, lang) do
    for _, capture in ipairs(strip_captures) do
      local insert = utils.get_at_path(match, capture)
      if insert then
        table.insert(matches, insert)
      end
    end
  end
  return matches
end

---@deprecated Use vim.treesitter.query.get(lang, query_name) + query:iter_captures(root, bufnr, start, stop)
function M.iter_captures(bufnr, query_name, root, lang)
  vim.notify_once(
    'query.iter_captures() is obsolete: use vim.treesitter.query.get(lang, name) + query:iter_captures()',
    vim.log.levels.WARN
  )
  local query, params = prepare_query(bufnr, query_name, root, lang)
  if not query then
    return EMPTY_ITER
  end
  assert(params, 'params should be set if query is set')

  local iter = query:iter_captures(params.root, params.source, params.start, params.stop)

  local function wrapped_iter()
    local id, node, metadata = iter()
    if not id then
      return
    end

    local name = query.captures[id]
    if string.sub(name, 1, 1) == '_' then
      return wrapped_iter()
    end

    return name, node, metadata
  end

  return wrapped_iter
end

---@param bufnr integer
---@param capture_string string
---@param query_group string
---@param filter_predicate fun(match: table): boolean
---@param scoring_function fun(match: table): number
---@param root TSNode
---@return table|unknown
---@deprecated Use vim.treesitter.query.get() + query:iter_matches() with custom filtering
function M.find_best_match(bufnr, capture_string, query_group, filter_predicate, scoring_function, root)
  vim.notify_once(
    'query.find_best_match() is obsolete: use vim.treesitter.query.get() + query:iter_matches() with filtering',
    vim.log.levels.WARN
  )
  if string.sub(capture_string, 1, 1) == '@' then
    --remove leading "@"
    capture_string = string.sub(capture_string, 2)
  end

  local best ---@type table|nil
  local best_score ---@type number

  for maybe_match in M.iter_group_results(bufnr, query_group, root) do
    local match = utils.get_at_path(maybe_match, capture_string)

    if match and filter_predicate(match) then
      local current_score = scoring_function(match)
      if not best then
        best = match
        best_score = current_score
      end
      if current_score > best_score then
        best = match
        best_score = current_score
      end
    end
  end
  return best
end

---@deprecated Use vim.treesitter.query.get(lang, query_group) + query:iter_matches(root, bufnr, start, stop)
---@param bufnr integer the buffer
---@param query_group string the query file to use
---@param root TSNode the root node
---@param root_lang? string the root node lang, if known
function M.iter_group_results(bufnr, query_group, root, root_lang)
  -- vim.notify_once(
  -- 'query.iter_group_results() is obsolete: use vim.treesitter.query.get(lang, group) + query:iter_matches()',
  -- vim.log.levels.WARN
  -- )
  local query, params = prepare_query(bufnr, query_group, root, root_lang)
  if not query then
    return EMPTY_ITER
  end
  assert(params, 'params should be set if query is set')

  return M.iter_prepared_matches(query, params.root, params.source, params.start, params.stop)
end

---@deprecated Use vim.treesitter.query.get(lang, query_group) + query:iter_matches() and collect results
function M.collect_group_results(bufnr, query_group, root, lang)
  vim.notify_once(
    'query.collect_group_results() is obsolete: use vim.treesitter.query.get() + query:iter_matches()',
    vim.log.levels.WARN
  )
  local matches = {}

  for prepared_match in M.iter_group_results(bufnr, query_group, root, lang) do
    table.insert(matches, prepared_match)
  end

  return matches
end

---@alias CaptureResFn function(string, LanguageTree, LanguageTree): string, string

-- Same as get_capture_matches except this will recursively get matches for every language in the tree.
---@param bufnr integer The buffer
---@param capture_or_fn string|CaptureResFn The capture to get. If a function is provided then that
---                       function will be used to resolve both the capture and query argument.
---                       The function can return `nil` to ignore that tree.
---@param query_type string? The query to get the capture from. This is ignored if a function is provided
---                    for the capture argument.
---@deprecated Use vim.treesitter.get_parser():for_each_tree() + vim.treesitter.query.get() + query:iter_captures()
---@return table[]
function M.get_capture_matches_recursively(bufnr, capture_or_fn, query_type)
  -- vim.notify_once(
  -- 'query.get_capture_matches_recursively() is obsolete: use parser:for_each_tree() + query.get() + query:iter_captures()',
  -- vim.log.levels.WARN
  -- )
  ---@type CaptureResFn
  local type_fn
  if type(capture_or_fn) == 'function' then
    type_fn = capture_or_fn
  else
    type_fn = function(_, _, _)
      return capture_or_fn, query_type
    end
  end

  -- local parsers = require('guihua.ts_obsolete.parsers')
  -- local parser = parsers.get_parser(bufnr)
  local parser = vim.treesitter.get_parser(bufnr)
  local matches = {}

  if parser then
    parser:for_each_tree(function(tree, lang_tree)
      local lang = lang_tree:lang()
      local capture, type_ = type_fn(lang, tree, lang_tree)

      if capture then
        vim.list_extend(matches, M.get_capture_matches(bufnr, capture, type_, tree:root(), lang) or {})
      end
    end)
  end

  return matches
end

return M
