local api = vim.api

function float()
  local columns = api.nvim_get_option('columns')
  local lines = api.nvim_get_option('lines')

  local height = math.ceil((lines - 2) * 0.6)
  local row = math.ceil((lines - height) / 2)
  local width = math.ceil(columns * 0.6)
  local col = math.ceil((columns - width) / 2)

  local border_opts = {
    relative = 'editor',
    row = row - 1,
    col = col - 2,
    width = width + 4,
    height = height + 2,
    style = 'minimal',
  }

  local opts = {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
  }

  local top = '╭' .. string.rep('─', width + 2) .. '╮'
  local mid = '│' .. string.rep(' ', width + 2) .. '│'
  local bot = '╰' .. string.rep('─', width + 2) .. '╯'

  lines = { top }
  for _ = 1, height, 1 do
    table.insert(lines, mid)
  end
  table.insert(lines, bot)

  local bbuf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(bbuf, 0, -1, true, lines)
  vim.g.float_term_border_win = api.nvim_open_win(bbuf, true, border_opts)
  -- local buf = api.nvim_create_buf(false, true)
  -- local float_term_win = api.nvim_open_win(buf, true, opts)

  api.nvim_set_option_value('winhl', 'Normal:NormalFloat', {win=vim.g.float_term_border_win})
  -- api.nvim_set_option_value('winhl', 'Normal:NormalFloat', {win=float_term_win})
end
float()
