-- Treesitter query utilities for Neovim 0.11+
-- Uses modern vim.treesitter.query APIs throughout.

local api = vim.api
local tsrange = require('guihua.ts_obsolete.tsrange')
local utils = require('guihua.ts_obsolete.utils')

local M = {}

local EMPTY_ITER = function() end

M.built_in_query_groups = { 'highlights', 'locals', 'folds', 'indents', 'injections' }

-- Creates a function that checks whether a given query exists for a specific language.
---@param query_name string
---@return fun(lang: string): boolean
local function get_query_guard(query_name)
  return function(lang)
    return vim.treesitter.query.get(lang, query_name) ~= nil
  end
end

for _, q in ipairs(M.built_in_query_groups) do
  M['has_' .. q] = get_query_guard(q)
end

-- Resolve parser, root node, language, and query object for a buffer.
---@param bufnr integer
---@param query_name string
---@param root TSNode|nil
---@param root_lang string|nil
---@return vim.treesitter.Query|nil query
---@return TSNode|nil root
---@return integer|nil source (bufnr)
---@return integer|nil start_row
---@return integer|nil stop_row
local function prepare_query(bufnr, query_name, root, root_lang)
  local buf_lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype) or vim.bo[bufnr].filetype
  if not buf_lang then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, buf_lang)
  if not ok or not parser then
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

  local query = vim.treesitter.query.get(root_lang, query_name)
  if not query then
    return
  end

  return query, root, bufnr, range[1], range[3] + 1
end

-- Split a dotted string into segments.
---@param s string
---@return string[]
local function split_dot(s)
  local t = {}
  for seg in s:gmatch('([^.]+)') do
    t[#t + 1] = seg
  end
  return t
end

-- Set a value at a nested path inside a table, creating intermediate tables as needed.
---@param object table
---@param path string[]
---@param value any
function M.insert_to_path(object, path, value)
  local cur = object
  for i = 1, #path - 1 do
    if cur[path[i]] == nil then
      cur[path[i]] = {}
    end
    cur = cur[path[i]]
  end
  cur[path[#path]] = value
end

-- Unwrap a match value that may be a TSNode[] table (Neovim 0.11+) to a single TSNode.
---@param v TSNode|TSNode[]
---@return TSNode
local function unwrap_node(v)
  if type(v) == 'table' then
    return v[#v]
  end
  return v
end

-- Iterate over prepared match tables from a query.
-- Each yielded value is a table whose keys follow the capture-name dot-path convention
-- (e.g. capture `@definition.var` produces `{ definition = { var = { node = TSNode } } }`).
---@param query vim.treesitter.Query
---@param qnode TSNode
---@param bufnr integer
---@param start_row integer
---@param end_row integer
---@return fun(): table|nil
function M.iter_prepared_matches(query, qnode, bufnr, start_row, end_row)
  local matches = query:iter_matches(qnode, bufnr, start_row, end_row)

  return function()
    local pattern, match, metadata = matches()
    if pattern == nil then
      return nil
    end

    local prepared = {}

    for id, nodes in pairs(match) do
      local name = query.captures[id]
      if name then
        local node = unwrap_node(nodes)
        M.insert_to_path(prepared, split_dot(name .. '.node'), node)
        M.insert_to_path(prepared, split_dot(name .. '.metadata'), metadata[id])
      end
    end

    -- Handle set! and make-range! predicates
    local preds = query.info.patterns[pattern]
    if preds then
      for _, pred in pairs(preds) do
        if pred[1] == 'set!' and type(pred[2]) == 'string' then
          M.insert_to_path(prepared, split_dot(pred[2]), pred[3])
        end
        if pred[1] == 'make-range!' and type(pred[2]) == 'string' and #pred == 4 then
          M.insert_to_path(
            prepared,
            split_dot(pred[2] .. '.node'),
            tsrange.TSRange.from_nodes(bufnr, unwrap_node(match[pred[3]]), unwrap_node(match[pred[4]]))
          )
        end
      end
    end

    return prepared
  end
end

-- Iterate over prepared match tables for a query group in a buffer.
---@param bufnr integer
---@param query_group string
---@param root TSNode|nil
---@param root_lang string|nil
---@return fun(): table|nil
function M.iter_group_results(bufnr, query_group, root, root_lang)
  local query, qnode, source, start_row, stop_row = prepare_query(bufnr, query_group, root, root_lang)
  if not query then
    return EMPTY_ITER
  end
  return M.iter_prepared_matches(query, qnode, source, start_row, stop_row)
end

-- Collect all prepared match tables for a query group in a buffer.
---@param bufnr integer
---@param query_group string
---@param root TSNode|nil
---@param lang string|nil
---@return table[]
function M.collect_group_results(bufnr, query_group, root, lang)
  local results = {}
  for prepared in M.iter_group_results(bufnr, query_group, root, lang) do
    results[#results + 1] = prepared
  end
  return results
end

do
  ---@type table<integer, table<string, { tick: integer, cache: table[] }>>
  local match_cache = {}

  -- Get cached match results for a query group, recomputing when the buffer changes.
  ---@param bufnr integer
  ---@param query_group string
  ---@return table[]
  function M.get_matches(bufnr, query_group)
    bufnr = bufnr or api.nvim_get_current_buf()
    if not match_cache[bufnr] then
      match_cache[bufnr] = {}
      -- Clean up on buffer detach
      api.nvim_buf_attach(bufnr, false, {
        on_detach = function()
          match_cache[bufnr] = nil
          return true
        end,
        on_reload = function() end,
      })
    end

    local tick = api.nvim_buf_get_changedtick(bufnr)
    local entry = match_cache[bufnr][query_group]
    if not entry or entry.tick < tick then
      entry = { tick = tick, cache = M.collect_group_results(bufnr, query_group) }
      match_cache[bufnr][query_group] = entry
    end
    return entry.cache
  end
end

-- Return all nodes matching specific capture paths (e.g. "@definition.var", "@reference.type").
---@param bufnr integer
---@param captures string|string[]
---@param query_group string
---@param root TSNode|nil
---@param lang string|nil
---@return table[]
function M.get_capture_matches(bufnr, captures, query_group, root, lang)
  if type(captures) == 'string' then
    captures = { captures }
  end

  local strip = {} ---@type string[]
  for i, cap in ipairs(captures) do
    if cap:sub(1, 1) ~= '@' then
      error('Captures must start with "@"')
    end
    strip[i] = cap:sub(2)
  end

  local results = {}
  for match in M.iter_group_results(bufnr, query_group, root, lang) do
    for _, cap in ipairs(strip) do
      local found = utils.get_at_path(match, cap)
      if found then
        results[#results + 1] = found
      end
    end
  end
  return results
end

-- Iterate over captures from a query, yielding (name, node, metadata).
---@param bufnr integer
---@param query_name string
---@param root TSNode|nil
---@param lang string|nil
---@return fun(): string|nil, TSNode|nil, table|nil
function M.iter_captures(bufnr, query_name, root, lang)
  local query, qnode, source, start_row, stop_row = prepare_query(bufnr, query_name, root, lang)
  if not query then
    return EMPTY_ITER
  end

  local iter = query:iter_captures(qnode, source, start_row, stop_row)

  local function wrapped()
    local id, node, metadata = iter()
    if not id then
      return
    end
    local name = query.captures[id]
    -- Skip internal captures starting with '_'
    if name:sub(1, 1) == '_' then
      return wrapped()
    end
    return name, node, metadata
  end
  return wrapped
end

-- Find the best match for a capture within a query group, using custom filter and scoring.
---@param bufnr integer
---@param capture_string string
---@param query_group string
---@param filter_predicate fun(match: table): boolean
---@param scoring_function fun(match: table): number
---@param root TSNode|nil
---@return table|nil
function M.find_best_match(bufnr, capture_string, query_group, filter_predicate, scoring_function, root)
  if capture_string:sub(1, 1) == '@' then
    capture_string = capture_string:sub(2)
  end

  local best ---@type table|nil
  local best_score ---@type number

  for maybe in M.iter_group_results(bufnr, query_group, root) do
    local match = utils.get_at_path(maybe, capture_string)
    if match and filter_predicate(match) then
      local score = scoring_function(match)
      if not best or score > best_score then
        best = match
        best_score = score
      end
    end
  end
  return best
end

---@alias CaptureResFn fun(lang: string, tree: TSTree, lang_tree: vim.treesitter.LanguageTree): string|nil, string|nil

-- Get capture matches recursively across all language trees in a buffer.
---@param bufnr integer
---@param capture_or_fn string|CaptureResFn
---@param query_type string|nil
---@return table[]
function M.get_capture_matches_recursively(bufnr, capture_or_fn, query_type)
  ---@type CaptureResFn
  local resolve_fn
  if type(capture_or_fn) == 'function' then
    resolve_fn = capture_or_fn
  else
    resolve_fn = function()
      return capture_or_fn, query_type
    end
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return {}
  end

  local results = {}
  parser:for_each_tree(function(tree, lang_tree)
    local lang = lang_tree:lang()
    local capture, type_ = resolve_fn(lang, tree, lang_tree)
    if capture then
      vim.list_extend(results, M.get_capture_matches(bufnr, capture, type_, tree:root(), lang))
    end
  end)
  return results
end

-- Kept for backward compatibility: no-op functions that previously managed caches.
-- vim.treesitter.query.get() handles its own caching in Neovim 0.11+.
function M.get_query(lang, query_name)
  return vim.treesitter.query.get(lang, query_name)
end

function M.invalidate_query_cache() end
function M.invalidate_query_file() end

function M.has_query_files(lang, query_name)
  return vim.treesitter.query.get(lang, query_name) ~= nil
end

function M.available_query_groups()
  local files = api.nvim_get_runtime_file('queries/*/*.scm', true)
  local groups = {}
  for _, f in ipairs(files) do
    groups[vim.fn.fnamemodify(f, ':t:r')] = true
  end
  return vim.tbl_keys(groups)
end

return M
