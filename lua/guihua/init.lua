local M = {}
local setup_opts = {}
local setup_complete = false
local lazy_exports = {
  view = 'guihua.view',
  listview = 'guihua.listview',
}

local function apply_setup()
  require('guihua.maps').setup(setup_opts)
  require('guihua.highlight').setup(setup_opts)
  require('guihua.icons').setup(setup_opts)
  -- Merge user-provided setup flags into _GH_SETUP so modules can read configuration.
  if type(setup_opts) == 'table' and _GH_SETUP ~= nil then
    _GH_SETUP = vim.tbl_deep_extend('force', _GH_SETUP, setup_opts)
  end
  -- Default: disable strikethrough in views to avoid single-tilde issues; user may override in setup()
  if _GH_SETUP.disable_strikethrough_in_views == nil then
    _GH_SETUP.disable_strikethrough_in_views = true
  end

  -- Default patch flag: enable Treesitter markdown strikethrough query patch by default
  if _GH_SETUP.patch_markdown_strikethrough_query == nil then
    _GH_SETUP.patch_markdown_strikethrough_query = true
  end

  -- Optional: patch Treesitter markdown highlight queries so that only explicit
  -- strikethrough nodes (usually created for double-tilde/~~) are linked to
  -- @markup.strikethrough. This avoids single-tilde cases being highlighted as
  -- strikethrough. Disabled by default; enable via setup { patch_markdown_strikethrough_query = true }.
  if _GH_SETUP.patch_markdown_strikethrough_query then
    local ok, _ = pcall(function()
      local q = [[
((strikethrough) @markup.strikethrough)
((deleted) @markup.strikethrough)
((del) @markup.strikethrough)
]]
      -- Try both common markdown parser names
      pcall(vim.treesitter.query.set_query, 'markdown', 'highlights', q)
      pcall(vim.treesitter.query.set_query, 'markdown_inline', 'highlights', q)
    end)
    if not ok then
      vim.notify('guihua: failed to apply markdown strikethrough query patch', vim.log.levels.WARN)
    end
  end
  setup_complete = true
  return _GH_SETUP
end

M.setup = function(opts)
  setup_opts = vim.tbl_deep_extend('force', setup_opts, opts or {})
  return apply_setup()
end

M.ensure_setup = function()
  if not setup_complete then
    return apply_setup()
  end
  return _GH_SETUP
end

return setmetatable(M, {
  __index = function(tbl, key)
    local module_name = lazy_exports[key]
    if module_name == nil then
      return nil
    end

    local module = require(module_name)
    rawset(tbl, key, module)
    return module
  end,
})
