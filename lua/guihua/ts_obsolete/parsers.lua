local api = vim.api
local ts = vim.treesitter

local is_012 = vim.fn.has('nvim-0.12') == 1

local M = {}

M.list = {}

-- Get a list of all available parsers
---@deprecated Use vim.treesitter.language.get_lang() and check parser availability directly
---@return string[]
function M.available_parsers()
  vim.notify_once('guihua.ts_obsolete.parsers.available_parsers() is deprecated', vim.log.levels.WARN)
  local parsers = vim.tbl_keys(M.list)
  table.sort(parsers)
  return parsers
end

---@param ft string
---@return string
function M.ft_to_lang(ft)
  vim.notify_once(
    'guihua.ts_obsolete.parsers.ft_to_lang() is deprecated: use vim.treesitter.language.get_lang()',
    vim.log.levels.WARN
  )
  local result = ts.language.get_lang(ft)
  if result then
    return result
  else
    ft = vim.split(ft, '.', { plain = true })[1]
    return ts.language.get_lang(ft) or ft
  end
end

local parser_files

function M.reset_cache()
  parser_files = setmetatable({}, {
    __index = function(tbl, key)
      rawset(tbl, key, api.nvim_get_runtime_file('parser/' .. key .. '.*', false))
      return rawget(tbl, key)
    end,
  })
end

M.reset_cache()

---@param lang string?
---@return boolean
function M.has_parser(lang)
  vim.notify_once(
    'guihua.ts_obsolete.parsers.has_parser() is deprecated: check parser availability directly',
    vim.log.levels.WARN
  )
  lang = lang or M.get_buf_lang(api.nvim_get_current_buf())

  if not lang or #lang == 0 then
    return false
  end
  -- nvim 0.12+: use vim.treesitter.language.add() which returns true/false
  if is_012 then
    local lok = pcall(ts.language.add, lang)
    return lok
  end
  -- HACK: nvim internal API
  if vim._ts_has_language then
    if vim._ts_has_language(lang) then
      return true
    end
  end
  return #parser_files[lang] > 0
end

---@param bufnr integer?
---@param lang string?
---@return vim.treesitter.LanguageTree?
function M.get_parser(bufnr, lang)
  vim.notify_once(
    'guihua.ts_obsolete.parsers.get_parser() is deprecated: use vim.treesitter.get_parser()',
    vim.log.levels.WARN
  )
  bufnr = bufnr or api.nvim_get_current_buf()
  lang = lang or M.get_buf_lang(bufnr)

  if M.has_parser(lang) then
    return ts.get_parser(bufnr, lang)
  end
end

---@deprecated All root nodes should be accounted for.
function M.get_tree_root(bufnr)
  vim.notify_once(
    'guihua.ts_obsolete.parsers.get_tree_root() is deprecated: use vim.treesitter.get_parser():parse()',
    vim.log.levels.WARN
  )
  bufnr = bufnr or api.nvim_get_current_buf()
  return M.get_parser(bufnr):parse()[1]:root()
end

-- Gets the language of a given buffer
---@param bufnr number? or current buffer
---@return string
function M.get_buf_lang(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  -- return M.ft_to_lang(vim.bo[bufnr].filetype)
  return vim.treesitter.language.get_lang(vim.bo[bufnr].filetype) or vim.bo[bufnr].filetype
end

return M
