local function get_vim_range_from_node(node)
  local s_row, s_col, e_row, e_col = node:range()
  return s_row + 1, s_col + 1, e_row + 1, e_col + 1
end

local function each_capture_node(parsed_query, match, cb)
  for capture_id, nodes_for_capture in pairs(match) do
    local capture_name = parsed_query.captures[capture_id]
    if capture_name then
      if type(nodes_for_capture) == 'table' then
        for _, node in ipairs(nodes_for_capture) do
          if node then
            cb(capture_name, node)
          end
        end
      elseif nodes_for_capture then
        cb(capture_name, nodes_for_capture)
      end
    end
  end
end

local function recurse_local_nodes(local_def, accumulator, full_match, last_match)
  if type(local_def) ~= 'table' then
    return
  end

  if local_def.node then
    accumulator(local_def, local_def.node, full_match, last_match)
  else
    for match_key, def in pairs(local_def) do
      recurse_local_nodes(
        def,
        accumulator,
        full_match and (full_match .. '.' .. match_key) or match_key,
        match_key
      )
    end
  end
end

local function get_locals_query(lang)
  if vim.treesitter.query and vim.treesitter.query.get then
    return vim.treesitter.query.get(lang, 'locals')
  end

  local ok_query, ts_query = pcall(require, 'nvim-treesitter.query')
  if ok_query and ts_query.get_query then
    return ts_query.get_query(lang, 'locals')
  end
end

local function add_capture(result, capture_name, node)
  if not capture_name or not capture_name:match('^local') then
    return
  end

  local current = result
  for part in capture_name:gmatch('[^%.]+') do
    current[part] = current[part] or {}
    current = current[part]
  end

  if current.node == nil then
    current.node = node
  end
end

local function resolve_tree_lang(tree, parser, bufnr)
  if tree and type(tree.lang) == 'function' then
    local ok, lang = pcall(tree.lang, tree)
    if ok and type(lang) == 'string' and lang ~= '' then
      return lang
    end
  end

  if tree and type(tree.language) == 'function' then
    local ok, lang = pcall(tree.language, tree)
    if ok and type(lang) == 'string' and lang ~= '' then
      return lang
    end
  end

  if parser and type(parser.lang) == 'function' then
    local ok, lang = pcall(parser.lang, parser)
    if ok and type(lang) == 'string' and lang ~= '' then
      return lang
    end
  end

  local ft = vim.bo[bufnr].filetype
  if vim.treesitter.language and vim.treesitter.language.get_lang then
    local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
    if ok and type(lang) == 'string' and lang ~= '' then
      return lang
    end
  end

  return ft
end

local function collect_local_matches(bufnr)
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return {}
  end

  local local_nodes = {}
  for _, tree in ipairs(parser:parse()) do
    local root = tree:root()
    local lang = resolve_tree_lang(tree, parser, bufnr)
    local query = get_locals_query(lang)
    if query then
      for _, match in query:iter_matches(root, bufnr, 0, -1) do
        local result = {}
        for id, node in pairs(match) do
          local capture_name = query.captures[id]
          if type(node) == 'table' then
            for _, n in pairs(node) do
              if type(n) == 'userdata' then
                add_capture(result, capture_name, n)
              end
            end
          else
            add_capture(result, capture_name, node)
          end
        end
        if result['local'] then
          table.insert(local_nodes, result)
        end
      end
    end
  end

  return local_nodes
end

local function get_scopes(bufnr)
  local scopes = {}
  for _, nodes in ipairs(collect_local_matches(bufnr)) do
    local loc = nodes['local']
    if loc and loc.scope and loc.scope.node then
      table.insert(scopes, loc.scope.node)
    end
  end
  return scopes
end

local function get_references(bufnr)
  local refs = {}
  for _, nodes in ipairs(collect_local_matches(bufnr)) do
    local loc = nodes['local']
    if loc and loc.reference and loc.reference.node then
      table.insert(refs, loc.reference.node)
    end
  end
  return refs
end

local function get_node_text(node, bufnr)
  return vim.treesitter.get_node_text(node, bufnr) or ''
end

local function node_identity(node)
  if not node then
    return nil
  end
  local ok_r, sr, sc, er, ec = pcall(node.range, node)
  local ok_t, nt = pcall(node.type, node)
  if not ok_r or not ok_t then
    return nil
  end
  return table.concat({ sr, sc, er, ec, nt }, ':')
end

local function node_equal(a, b)
  if a == b then
    return true
  end
  local ka = node_identity(a)
  local kb = node_identity(b)
  return ka ~= nil and kb ~= nil and ka == kb
end

local function node_contains(container, node)
  if not container or not node then
    return false
  end

  local ok_c, csr, csc, cer, cec = pcall(container.range, container)
  local ok_n, nsr, nsc, ner, nec = pcall(node.range, node)
  if not ok_c or not ok_n then
    return false
  end

  local starts_inside = (nsr > csr) or (nsr == csr and nsc >= csc)
  local ends_inside = (ner < cer) or (ner == cer and nec <= cec)
  return starts_inside and ends_inside
end

local function append_unique(nodes, node)
  for _, n in ipairs(nodes) do
    if node_equal(n, node) then
      return
    end
  end
  table.insert(nodes, node)
end

local function scope_size(scope)
  if not scope then
    return math.huge
  end
  local ok, sr, sc, er, ec = pcall(scope.range, scope)
  if not ok then
    return math.huge
  end
  return (er - sr) * 100000 + (ec - sc)
end

local function find_definition_node(node, bufnr, root_provider)
  if not node then
    return
  end

  local node_text = get_node_text(node, bufnr)
  if node_text == '' then
    if root_provider then
      return node, root_provider(node), nil
    end
    return node, nil, nil
  end

  local definitions = {}
  for _, nodes in ipairs(collect_local_matches(bufnr)) do
    local loc = nodes['local']
    if loc and loc.definition then
      recurse_local_nodes(loc.definition, function(_, def_node, _, kind)
        table.insert(definitions, {
          node = def_node,
          kind = kind,
          scope = loc.scope and loc.scope.node,
        })
      end)
    end
  end

  local best_entry
  for _, entry in ipairs(definitions) do
    if get_node_text(entry.node, bufnr) == node_text then
      if entry.scope == nil or node_contains(entry.scope, node) then
        if best_entry == nil or scope_size(entry.scope) < scope_size(best_entry.scope) then
          best_entry = entry
        end
      end
    end
  end

  if best_entry then
    if best_entry.scope then
      return best_entry.node, best_entry.scope, best_entry.kind
    end
    if root_provider then
      return best_entry.node, root_provider(node), best_entry.kind
    end
    return best_entry.node, nil, best_entry.kind
  end

  if root_provider then
    return node, root_provider(node), nil
  end
  return node, nil, nil
end

local function find_usages(node, scope_node, bufnr, root_provider)
  if not node then
    return {}
  end

  local usages = {}
  local relaxed_usages = {}
  local node_text = get_node_text(node, bufnr)
  local scope = scope_node
  if scope == nil and root_provider then
    scope = root_provider(node)
  end
  if scope == nil then
    return usages
  end

  for _, nodes in ipairs(collect_local_matches(bufnr)) do
    local loc = nodes['local']
    if loc and loc.reference and loc.reference.node then
      local ref_node = loc.reference.node
      if get_node_text(ref_node, bufnr) == node_text and node_contains(scope, ref_node) then
        append_unique(relaxed_usages, ref_node)
        local def_node, _, kind = find_definition_node(ref_node, bufnr, root_provider)
        if kind == nil or node_equal(def_node, node) then
          append_unique(usages, ref_node)
        end
      end
    end
  end

  -- Ensure definition is always part of the jump cycle.
  append_unique(usages, node)
  append_unique(relaxed_usages, node)

  if #usages > 1 then
    return usages
  end

  return relaxed_usages
end

return {
  get_vim_range_from_node = get_vim_range_from_node,
  each_capture_node = each_capture_node,
  recurse_local_nodes = recurse_local_nodes,
  collect_local_matches = collect_local_matches,
  get_scopes = get_scopes,
  get_references = get_references,
  find_definition_node = find_definition_node,
  find_usages = find_usages,
}
