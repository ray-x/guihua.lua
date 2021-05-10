local class = require "middleclass"
local ViewController = class("ViewController")
local util = require "guihua.util"
local log = require "guihua.log".info

function ViewController:initialize(delegate, ...)
  self.m_delegate = delegate
  -- log(debug.traceback())
  local opts = select(1, ...) or {}
  self.display_data = opts.data or {}
  log("view ctrl")
  self.data = opts.data or {}
  -- log("viewctrl", delegate)
  util.close_view_autocmd({"BufHidden", "BufDelete"}, delegate.win)

  -- ... is the view
  --   vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<C-e>", "<cmd> lua require'guihua.view':on_close()<CR>", {})
  --   vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-e>", "<cmd> lua require'guihua.view':on_close()<CR>", {})
end

function ViewController:get_ui()
  return self.m_delegate
end

function ViewController:on_draw(data)
  local ui = self:get_ui()
  if ui then
    ui:on_draw(data)
  end
end

return ViewController
