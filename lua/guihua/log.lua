-- log.lua
--
-- Inspired by rxi/log.lua
-- Modified by tjdevries and can be found at github.com/tjdevries/vlog.nvim
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
-- User configuration section
local default_config = {
  -- Name of the plugin. Prepended to log messages
  plugin = 'gh', --  ',
  -- Should print the output to neovim while running
  use_console = false,
  -- Should highlighting be used in console (using echohl)
  highlights = true,
  -- Should write to a file
  use_file = true,
  log_file = 'gh',
  -- Any messages above this level will be logged.
  level = 'error',
  -- Level configuration
  log_size = 10000000,
  modes = {
    { name = 'trace', hl = 'Comment' },
    { name = 'debug', hl = 'Comment' },
    { name = 'info', hl = 'None' },
    { name = 'warn', hl = 'WarningMsg' },
    { name = 'error', hl = 'ErrorMsg' },
    { name = 'fatal', hl = 'ErrorMsg' },
  },
  -- Can limit the number of decimals displayed for floats
  float_precision = 0.01,
}

-- {{{ NO NEED TO CHANGE
local log = {}

local unpack = unpack or table.unpack

local os_name = vim.loop.os_uname().sysname
local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'
-- Check whether current buffer contains main function

local function sep()
  if is_windows then
    return '\\'
  end
  return '/'
end

log.new = function(config, standalone)
  config = vim.tbl_deep_extend('force', default_config, config)
  -- path ~/.local/share/nvim

  local cache_dir = vim.fn.stdpath('cache') -- ' stdpath('log') '
  config.log_file = config.log_file or config.plugin or 'gh'
  local outfile = string.format('%s%s%s.log', cache_dir, sep(), config.log_file)

  if config.use_file then
    local fp = io.open(outfile, 'r')
    if fp then
      local size = fp:seek('end')
      fp:close()
      if size > config.log_size then
        os.remove(outfile)
      end
    end
  end

  local obj
  if standalone then
    obj = log
  else
    obj = {}
  end

  local levels = {}
  for i, v in ipairs(config.modes) do
    levels[v.name] = i
  end

  local round = function(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
  end

  local make_string = function(...)
    local t = {}
    for i = 1, select('#', ...) do
      local x = select(i, ...)

      if type(x) == 'number' and config.float_precision then
        x = tostring(round(x, config.float_precision))
      elseif type(x) == 'table' then
        x = vim.inspect(x)
      else
        x = tostring(x)
      end

      t[#t + 1] = x
    end
    return table.concat(t, ' ')
  end

  local log_at_level = function(level, level_config, message_maker, ...)
    -- Return early if we're below the config.level
    if level < levels[config.level] then
      return
    end
    local nameupper = level_config.name:upper()

    local msg = message_maker(...)
    local info = debug.getinfo(2, 'Sl')
    local lineinfo = string.format('[%s]%s:%s', level, info.short_src, info.currentline)

    -- Output to console
    if config.use_console then
      local console_string = string.format('[%-4s][%s] %s: %s', nameupper, os.date('%H:%M:%S'), lineinfo, msg)

      if config.highlights and level_config.hl then
        vim.cmd(string.format('echohl %s', level_config.hl))
      end

      local split_console = vim.split(console_string, '\n')
      for _, v in ipairs(split_console) do
        vim.cmd(string.format([[echom "[%s] %s"]], config.plugin, vim.fn.escape(v, '"')))
      end

      if config.highlights and level_config.hl then
        vim.cmd('echohl NONE')
      end
    end

    -- Output to log file
    if config.use_file then
      -- check file size

      local fp = io.open(outfile, 'a+')
      local str = string.format('[%-4s][%s] %s: %s\n', nameupper, os.date(), lineinfo, msg)
      if fp then
        fp:write(str) -- return true if successful
        fp:flush()
        fp:close()
      else
        print('Could not open log file')
      end
    end
  end

  for i, x in ipairs(config.modes) do
    obj[x.name] = function(...)
      return log_at_level(i, x, make_string, ...)
    end

    obj[('fmt_%s'):format(x.name)] = function()
      return log_at_level(i, x, function(...)
        local passed = { ... }
        local fmt = table.remove(passed, 1)
        local inspected = {}
        for _, v in ipairs(passed) do
          table.insert(inspected, vim.inspect(v or 'nil'))
        end
        return string.format(fmt, unpack(inspected))
      end)
    end
  end

  obj.config = function()
    return config
  end
  return obj
end

log.new(default_config, true)

-- function log.log(...)
--   local arg = {...}
--   if vim.g.debug_output == true then
--     local str = " "
--     for i, v in ipairs(arg) do
--       if type(v) == "table" then
--         str = str .. " |" .. tostring(i) .. ": " .. vim.inspect(v) .. "\n"
--       else
--         str = str .. " |" .. tostring(i) .. ": " .. tostring(v)
--       end
--     end
--     if #str > 2 then
--       if M.log_path ~= nil and #M.log_path > 3 then
--         local f = io.open(M.log_path, "a+")
--         io.output(f)
--         io.write(str)
--         io.close(f)
--       else
--         print(str .. '\n')
--       end
--     end
--   end
-- end
--
-- function log.trace(...)
--   if vim.g.debug_trace_output == true then
--     M.log(...)
--   end
-- end

-- local l = log.new ({level = "info"}, true)
--
return log
