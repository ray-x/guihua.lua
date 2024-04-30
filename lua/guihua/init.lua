local M = {}
M.view = require('guihua.view')
M.listview = require('guihua.listview')
M.setup = function(opts)
  require('guihua.maps').setup(opts)
  require('guihua.highlight').setup(opts)

  require('guihua.icons').setup(opts) -- opts.icons
end
return M
