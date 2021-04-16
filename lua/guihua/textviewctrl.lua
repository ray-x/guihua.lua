local viewctrl=require"guihua.viewctrl"
local listviewctrl = class(viewctrl)
listviewctrl._class_name = "textviewctrl"

function listviewctrl:ctor(delegate, ...)
  self.m_delegate = delegate
  -- ... is the view
  -- todo location, readonly? and filetype


  -- vim.api.nvim_buf_set_keymap(buf, "i", "<C-p>", "<cmd> lua CURRENT_FUZZY.drawer:selection_up()<CR>", {})
  -- vim.api.nvim_buf_set_keymap(buf, "i", "<C-k>", "<cmd> lua CURRENT_FUZZY.drawer:selection_up()<CR>", {})
  -- vim.api.nvim_buf_set_keymap(buf, "i", "<C-n>", "<cmd> lua CURRENT_FUZZY.drawer:selection_down()<CR>", {})
  -- vim.api.nvim_buf_set_keymap(buf, "i", "<C-j>", "<cmd> lua CURRENT_FUZZY.drawer:selection_down()<CR>", {})
  -- vim.api.nvim_buf_set_keymap(buf, "i", "<CR>", "<cmd> lua __Fuzzy_handler()<CR>", {})
  vim.api.nvim_buf_set_keymap(delegate.buf, "i", "<esc>", "<cmd> lua __Fuzzy_close()<CR>", {})
  --vim.api.nvim_buf_set_keymap(view.buf, "n", "<esc>", "<cmd> lua require'guihua..view':dtor() <CR>", {})
  -- vim.api.nvim_buf_set_keymap(buf, "i", "<C-c>", "<cmd> lua __Fuzzy_close()<CR>", {})

end

function listviewctrl:get_ui()
  return self.m_delegate
end

function listviewctrl:on_draw(data)
  log("ctrl ondraw ")
  -- Ctr负责逻辑处理，转换视图可识别的数据
  -- data = process(data)

  -- 由View负责刷新视图
  local ui = self:get_ui()
  if ui then
    ui:on_draw(data)
  end
end

function listviewctrl:dtor(...)
  log("ctrl dtor ")
  self.buf_closer()
  self.m_delegate = nil
end

return listviewctrl
