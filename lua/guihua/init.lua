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
