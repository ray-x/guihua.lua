![guihua](https://github.com/ray-x/files/blob/master/img/guihua/guihua_800.png)
Guihua: A Lua Gui and util liberary for nvim plugins

- Provide floating windows
- A modified wrapper for fzy
- TextView, ListView, Preview etc

* Listview
  ![listview](https://github.com/ray-x/files/blob/master/img/guihua/listview.png)

Please refer to test file of how to use it

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
