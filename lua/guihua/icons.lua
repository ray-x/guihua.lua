local _icons = {
  panel = {
    section_separator = '─', --'',
    line_num_left = ':', --'',
    line_num_right = '', --',

    range_left = '', --'',
    range_right = '',
    inner_node = '', --├○',
    folded = '◉',
    unfolded = '○',

    outer_node = '', -- '╰○',
    bracket_left = '', -- ⟪',
    bracket_right = '', -- '⟫',
  },
  syntax = {
    var = ' ', -- "👹", -- Vampaire
    method = 'ƒ ', --  "🍔", -- mac
    ['function'] = ' ', -- "🤣", -- Fun
    ['arrow_function'] = ' ', -- "🤣", -- Fun
    parameter = '', -- Pi
    associated = '🤝',
    namespace = '🚀',
    type = ' ',
    field = '🏈',
    interface = '',
    module = '📦',
    flag = '🎏',
  },
}

local function icons()
  return _icons
end

local function setup(opts)
  if opts and opts.icons then
    _icons = vim.tbl_deep_extend('force', _icons, opts.icons)
  end
end

return {
  icons = icons,
  setup = setup,
}
