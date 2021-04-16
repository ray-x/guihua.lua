require "luakit.core"
local viewcontroller = class()
viewcontroller._class_name = "viewctrl"

function viewcontroller:ctor(delegate, ...)
  self.m_delegate = delegate

  local opts = select(1, ...) or {}
  self.display_data = opts.data or {}
  --log("view ctrl opts", opts)
  self.data = opts.data or {}
  -- ... is the view
  vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<C-e>", "<cmd> lua require'guihua.view':on_close()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "n", "<C-e>", "<cmd> lua require'guihua.view':on_close()<CR>", {})
end

function viewcontroller:get_ui()
  return self.m_delegate
end

function viewcontroller:on_draw(data)
  local ui = self:get_ui()
  if ui then
    ui:on_draw(data)
  end
end

function viewcontroller:dtor(...)
  self.m_delegate = nil
end
