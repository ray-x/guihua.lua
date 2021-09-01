![guihua](https://github.com/ray-x/files/blob/master/img/guihua/guihua_800.png)
Guihua: A Lua Gui and util library for nvim plugins

- Provide floating windows
- A modified wrapper for fzy
- TextView, ListView, Preview etc

* Listview
  ![listview](https://github.com/ray-x/files/blob/master/img/guihua/listview.png)

* Listview with fzy finder
  ![listview](https://github.com/ray-x/files/blob/master/img/navigator/fzy_reference.jpg?raw=true)

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

## Plug

```vim
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
```

Usage: check the test files on how the api is used.
