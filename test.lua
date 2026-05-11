local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  'show me something',
})

local win = vim.api.nvim_open_win(buf, true, {
  relative = 'editor',
  row = 3,
  col = 10,
  width = 30,
  height = 5,
  style = 'minimal',
  border = 'single',
})

vim.api.nvim_set_hl(0, 'DemoStrike', { strikethrough = true })

vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace('demo'), 0, 8, {
  end_row = 0,
  end_col = 17,
  hl_group = 'DemoStrike',
})
