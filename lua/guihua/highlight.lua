return {
  setup = function(opts)
    opts = opts or {}
    local highlights = {
      -- Sets the highlight for selected items within the picker.
      GuihuaListSelHl = { default = true, link = opts.list_sel_hl or 'Visual' },
      GuihuaListDark = { default = true, link = opts.list_bg or 'NormalFloat' },
      GuihuaTextViewDark = { default = true, link = opts.preview_bg or 'NormalFloat' },
      GuihuaBgDark = { default = true, link = opts.bg or 'NormalFloat' },
    }
    for k, v in pairs(highlights) do
      vim.api.nvim_set_hl(0, k, v)
    end
  end,
}
