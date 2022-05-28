tests:
	nvim --headless --noplugin -u lua/guihua/tests/minimal.vim -c "PlenaryBustedDirectory lua/guihua/tests/ {minimal_init = 'lua/guihua/tests/minimal.vim'}"
