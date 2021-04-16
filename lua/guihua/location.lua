return {
  center = function(win_height, win_width)
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)
    return row, col
  end,
  top_center = function(win_height, win_width)
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    local row = math.ceil((8))
    local col = math.ceil((width - win_width) / 2)
    return row, col
  end,
  bottom_center = function(win_height, win_width)
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    local row = math.ceil((height - win_height))
    local col = math.ceil((width - win_width) / 2)
    return row, col
  end,
  center_right = function(win_height, win_width)
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 3)
    return row, col
  end,
  up_left = function(win_height, win_width)
    return 5, 5
  end,

--   cur_pos = function(win_height, win_width, x, y)
--     x = x or 10
--     y = y or 10
--     local width = vim.api.nvim_get_option("columns")
--     local height = vim.api.nvim_get_option("lines")
   -- local row = math.ceil((height - win_height) / 2 - 1)
   -- local col = math.ceil((width - win_width) / 3)
--     if y + win_height + 3 > height then
--       y = height - win_height - 5
--     end
--     --return row, col
--     return x + 4, y
--   end
}
