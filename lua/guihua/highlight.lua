return {
  setup = function(opts)
    opts = opts or {}
    local sel, listbg, textbg, border = 'Visual', 'NormalFloat', 'NormalFloat', 'FloatBorder'
    if vim.fn.hlID('TelescopePromptBorder') > 0 then
      border = 'TelescopePromptBorder'
      listbg = 'TelescopeNormal'
      textbg = 'TelescopePreviewNormal'
      sel = 'TelescopeSelection'
    end

    local highlights = {
      -- Sets the highlight for selected items within the picker.
      GuihuaListSelHl = { default = true, link = opts.list_sel_hl or sel },
      GuihuaListDark = { default = true, link = opts.list_bg or listbg },
      GuihuaTextViewDark = { default = true, link = opts.preview_bg or textbg },
      GuihuaBgDark = { default = true, link = opts.bg or textbg },
    }
    for k, v in pairs(highlights) do
      vim.api.nvim_set_hl(0, k, v)
    end
  end,
}
