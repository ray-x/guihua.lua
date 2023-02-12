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

* Neovim vim.ui.input and vim.ui.select patch

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

## Setup

```lua
  -- default mapping
  maps = {
    close_view = '<C-e>',
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
  }

  --
  require('guihua.maps').setup({
  maps = {
    close_view = '<C-x>',
  }
  })
```

## Plug

```vim
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
```

Usage: check the test files on how the api is used.
