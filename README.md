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

`vim.ui.select()` callers can attach preview content directly by adding `preview` to each
item or by passing `preview_item = function(item) return ... end`. Guihua will turn that
content into a preview window automatically.

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

  -- guihua disables strikethrough highlights inside its floating views to avoid accidental single-tilde (~) rendering (useful for paths like ~/foo).
})
```

Note: guihua disables the common strikethrough highlight groups for its floating views by default. You can control this behavior with setup options:

- disable_strikethrough_in_views (default: true): when true, guihua disables common strikethrough highlight groups inside its floating views (no ~ or ~~ will show strike).
- patch_markdown_strikethrough_query (default: false): when true, guihua will attempt to set a Treesitter highlights query so only explicit strikethrough nodes (usually produced for ~~double-tilde~~) are linked to @markup.strikethrough. To test double-tilde-only behavior set disable_strikethrough_in_views=false and patch_markdown_strikethrough_query=true in your setup.
- Long or multiline input prompts are rendered inside the same input popup, with a vertical split glyph separating the prompt text area from the editable input line.
- `vim.ui.input()` uses a window title: explicit `title` wins, otherwise the first prompt line is truncated to 20 characters.
- Diff previews are available via `require('guihua.gui').diffview({ title = ..., description = ..., diff = ..., syntax = ... })`.
- Diff previews support `close_keymap` and `autoclose = 'InsertLeave'` (or `{ events = { 'WinLeave' }, timeout = 5000 }`).
- `diffview()` opts:
  - `title`: border title.
  - `description`: rendered before the diff body.
  - `diff`: unified diff text.
  - `syntax`: optional syntax for the diff body.
  - `close_keymap`: buffer-local close key, default `<C-c>`.
  - `autoclose`: event name, event list, or `{ events = {...}, timeout = ms }`.
  - `autoclose_focus_moved`: shorthand for `WinLeave`/`BufLeave`.

Example:

require('guihua').setup({
  disable_strikethrough_in_views = false, -- allow strikethrough in guihua views
  patch_markdown_strikethrough_query = true, -- make Treesitter highlight only double-tilde as strikethrough
})

`guihua.gui.catalog()` adds a tabbed floating browser for TOC-style data. It keeps the
`@markup.strikethrough` override local to guihua popups and opens the selected path on Enter by default.
Use `<Left>` / `<Right>` to move between tabs.

Catalog options:
- `tabs`: keyed table (`{ agents = {...}, skills = {...} }`) or list form (`{ { key = 'agents', items = {...} } }`)
- `tab_order`/`order`: explicit order for keyed tabs
- `loc`: list placement (default `top_center`)
- `rect` or `width`/`height`: list size (default height auto-fits item count)
- `list_height_ratio`: max list height ratio (default `0.45`)
- `preview_height_ratio`: preview height ratio (default `0.4`)
- `on_confirm(item, active_tab)`: callback when confirming a selection

```lua
require('guihua.gui').catalog({
  title = 'Browse',
  tabs = {
    agents = {
      { name = 'grep', description = { 'this is a grep agent' }, path = '/path/to/agent.lua' },
    },
    skills = {
      { name = 'lint', description = 'this is a lint skill', path = '/path/to/skill.lua' },
    },
  },
  tab_order = { 'agents', 'skills' },
})
```


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
