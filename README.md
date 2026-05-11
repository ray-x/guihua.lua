![guihua](https://github.com/ray-x/files/blob/master/img/guihua/guihua_800.png)
Guihua: A Lua Gui and util library for nvim plugins

- Provide floating windows
- A modified wrapper for fzy
- TextView, ListView, Preview etc

* Listview
  ![listview](https://github.com/ray-x/files/blob/master/img/guihua/listview.png)

* Listview with fzy finder
  ![listview](https://github.com/ray-x/files/blob/master/img/navigator/fzy_reference.jpg?raw=true)

* Neovim multigrid external buffer/terminal

![multigrid](https://user-images.githubusercontent.com/1681295/133234734-93817aaa-23a3-4c28-b164-b129be449dee.jpg)

- Neovim vim.ui.input and vim.ui.select patch

This cool screen shows an external terminal running lazygit and an external floating window running guihua listview

More screen shot please refer to [Navigator.lua](https://github.com/ray-x/navigator.lua)

Please refer to test file of how to use it

Lua OOP is powered by [middleclass](https://github.com/kikito/middleclass)
fzy is powered by [romgrk fzy-lua-native](https://github.com/romgrk/fzy-lua-native) with modified version of sorter/quicksort to sort list of tables

# Install

Plugin has implementation of fzy with both ffi and native lua. If you like to try ffi please run make

## Packer

```lua
 use {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}
```

## lazy.nvim

```lua
{
  'ray-x/guihua.lua',
  build = 'cd lua/fzy && make',
  lazy = true,
  init = function()
    local configured = false

    local function ensure_guihua()
      if configured then
        return
      end

      configured = true
      require('guihua').setup({})
    end

    vim.ui.select = function(...)
      ensure_guihua()
      return require('guihua.gui').select(...)
    end

    vim.ui.input = function(...)
      ensure_guihua()
      return require('guihua.gui').input(...)
    end
  end,
}
```

The lazy.nvim example above keeps guihua unloaded until the first `vim.ui.select()` or
`vim.ui.input()` call, which avoids paying the UI startup cost during Neovim startup.

## Setup

```lua
local icons = {
  panel_icons = {
    section_separator = '─', -- '',
    line_num_left = ':', -- '',
    line_num_right = '', -- '',

    range_left = '', -- '',
    range_right = '',
    inner_node = '', -- '├○',
    folded = '◉',
    unfolded = '○',

    outer_node = '', -- '╰○',
    bracket_left = '', -- '⟪',
    bracket_right = '', -- '⟫',
  },
  syntax_icons = {
    var = ' ', -- "👹", -- Vampire
    method = 'ƒ ', -- "🍔", -- mac
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

require('guihua').setup({
  maps = {
    close_view = '<C-x>',
    send_qf = '<C-q>',
    save = '<C-s>',
    jump_to_list = '<C-w>k',
    jump_to_preview = '<C-w>j',
    prev = '<C-p>',
    next = '<C-n>',
    pageup = '<C-b>',
    pagedown = '<C-f>',
    confirm = '<C-o>',
    split = '<C-s>',
    vsplit = '<C-v>',
    tabnew = '<C-t>',
  },
  icons = icons,

  -- Optional: disable markdown/strikethrough highlights inside guihua views.
  -- This avoids accidental single-tilde (~) strikethrough rendering (useful for paths like ~/foo).
  -- Default: true
  disable_strikethrough_in_views = true,
  -- When true, guihua will attempt to patch Treesitter markdown highlight queries
  -- so that only explicit strikethrough nodes (usually produced for double-tilde
  -- syntax like ~~strike~~) are linked to @markup.strikethrough. Default: true
  patch_markdown_strikethrough_query = true,
})
```

Defaults

- patch_markdown_strikethrough_query: true — guihua will attempt to set a Treesitter highlights query so double-tilde (~~) is treated as strikethrough. Set to false to skip the patch.
- disable_strikethrough_in_views: true — guihua disables several common strikethrough highlight groups inside its floating views by default to avoid accidental single-tilde (~) highlighting.

Addendum: Treating only double-tilde (~~) as strikethrough

The official Markdown/GFM syntax uses double tildes (~~) for strikethrough. Treesitter grammars or highlight queries sometimes mark single tildes as strikethrough depending on the parser or injected inline grammar. There are two approaches to ensure only double-tilde is highlighted as strikethrough:

1) Prefer disabling guihua's window-local strikethrough override (see above) and instead adjust your Treesitter highlight queries so that only true strikethrough nodes are linked to the strikethrough highlight. Create or override the highlights query for markdown:

- Create a file at: ~/.config/nvim/queries/markdown/highlights.scm (or queries/markdown_inline depending on your parser)
- Add patterns that explicitly capture the strikethrough node, for example:

```
;; match markdown strikethrough nodes and link them to @markup.strikethrough
((strikethrough) @markup.strikethrough)
```

This ensures only nodes the parser recognizes as `strikethrough` (usually created for double-tilde syntax) get the highlight.

2) Keep guihua's default override (recommended for safety):
- guihua disables several common strikethrough groups inside its floating views to avoid incorrect single-tilde rendering. If you want double-tilde highlighting inside guihua views, first enable disable_strikethrough_in_views=false, then use approach (1) to make the parser highlight only double-tilde nodes.

If you'd like, I can implement an automatic query patch that prefers double-tilde nodes, or expose which highlight groups guihua adjusts so you can tune them in setup().

## Plug

```vim
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
```

Usage: check the test files on how the api is used.

## Git commit agent

This repository includes a repo-local commit helper at `scripts/git_commit_agent.py`.

It will:

- use the current staged diff, or stage everything with `--all`
- run the repo sanity checks before committing
- block the commit if `selene lua` or `make tests` fails
- generate a conventional-style commit message from the staged changes
- optionally push the commit to GitHub or GitLab remotes with `--push`

Examples:

```sh
python3 scripts/git_commit_agent.py --dry-run
python3 scripts/git_commit_agent.py --all
python3 scripts/git_commit_agent.py --all --push
```
