local class = require('middleclass')
local View = require('guihua.view')
local log = require('guihua.log').info
local util = require('guihua.util')
local trace = require('guihua.log').trace
local api = vim.api
local Sprite
if Sprite == nil then
  Sprite = class('Sprite', View)
end

local uv = vim.uv or vim.loop
_GH_SETUP = _GH_SETUP or nil
if _GH_SETUP == nil then
  require('guihua.maps').setup()
end
local dots = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local dots2 = { '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' }
local moon = { '🌑 ', '🌒 ', '🌓 ', '🌔 ', '🌕 ', '🌖 ', '🌗 ', '🌘 ' }

local function get_window_position(opts)
  local offset = opts.offset or 0
  local width, height, baseheight
  if opts.relative == 'editor' then
    local statusline_height = 0
    local laststatus = vim.opt.laststatus:get()
    if laststatus == 2 or laststatus == 3 or (laststatus == 1 and #api.nvim_tabpage_list_wins() > 1) then
      statusline_height = 1
    end
    height = vim.opt.lines:get() - (statusline_height + vim.opt.cmdheight:get())
    -- Does not account for &signcolumn or &foldcolumn, but there is no amazing way to get the
    -- actual "viewable" width of the editor
    --
    -- However, I cannot imagine that many people will render fidgets on the left side of their
    -- editor as it will more often overlay text
    width = vim.opt.columns:get()
  else -- fidget relative to window.
    height = api.nvim_win_get_height(0)
    width = api.nvim_win_get_width(0)

    if vim.fn.exists('+winbar') > 0 and vim.opt.winbar:get() ~= '' then
      -- When winbar is enabled, the effective window height should be
      -- decreased by 1. (see :help winbar)
      height = height - 1
    end
  end
  return height - offset, width
end
-- Note, Support only one active view
-- ActiveView = nil
--[[
opts={
  header=true/"headerinfo"
  rect={width, height, pos_x, pos_y}
  loc='center|up_left|center_right'
  background
  prompt
}
opts= {uri = l.uri, width = width, height=height, lnum = l.lnum, col = l.col, pos_x = 0, pos_y = pos_y}

with file uri {
    syntax = syntax,
    rect = {width = 40, height = 20},
    pos_x = opts.pos_x or 0,
    pos_y = opts.pos_y or 10,
    range = range,
    uri = uri,
    allow_edit = true
  }

--]]
function Sprite:initialize(...)
  trace(debug.traceback())

  local opts = select(1, ...) or {}

  log('ctor Sprite start:')
  trace(opts)

  opts.bg = opts.bg or 'GuihuaSpriteDark'

  local h, w = get_window_position(opts)

  self.data = opts.data or { '' }
  self.is_run = true
  self.delay = opts.delay or 100
  self.interval = opts.interval or 200
  self.frame = 1
  self.timeout = opts.timeout or 10000
  self.spinner = opts.spinner or moon
  opts.rect.pos_x = math.max(1, opts.rect.pos_x or w - #self.data[1] - 2)
  opts.rect.pos_y = opts.rect.pos_y or h
  if Sprite.ActiveSprite ~= nil then
    if
      Sprite.ActiveSprite.win ~= nil
      and vim.api.nvim_win_is_valid(Sprite.ActiveSprite.win)
      and vim.api.nvim_buf_is_valid(Sprite.ActiveSprite.buf)
    then
      log('active view ', Sprite.ActiveSprite.buf, Sprite.ActiveSprite.win)
      if Sprite.hl_id ~= nil then
        vim.api.nvim_buf_clear_namespace(0, Sprite.hl_id, 0, -1)
        Sprite.static.hl_id = nil
      end
      trace('active view already existed')
      self = Sprite.ActiveSprite
      -- TODO: delegate, on_load
      if opts.data then
        Sprite.ActiveSprite:on_draw(opts.data)
      end
      return Sprite.ActiveSprite
    else
      -- Sprite.on_close()
      log('active view not valid')
      Sprite.ActiveSprite = nil
    end
  end

  opts.enter = opts.enter or false
  View.initialize(self, opts)

  self.cursor_pos = { 1, 1 }
  if opts.syntax then
    self.syntax = opts.syntax
    trace('hl ', self.buf, opts.syntax)
    require('guihua.util').highlighter(self.buf, opts.syntax, opts.lnum)
  end

  util.close_view_autocmd({ 'BufHidden', 'BufDelete' }, self.win)
  -- controller and data

  local timer = uv.new_timer()
  local start_time = uv.hrtime()
  timer:start(
    self.delay,
    self.interval,
    vim.schedule_wrap(function()
      if not self.is_run then
        return
      end
      local ctime = uv.hrtime()
      if self.timeout and ctime > start_time + self.timeout * 1000000 then
        log('timeout', self.timeout, ctime - start_time)
        self:on_close()
        return
      end
      self:on_draw(self.data)
      self.frame = self.frame + 1
    end)
  )
  self.__timer = timer
  trace(self)
  trace('ctor Sprite: end') -- , View.ActiveView)--, self)
  Sprite.static.ActiveSprite = self
  return self
end

function Sprite.Active()
  if Sprite.ActiveSprite ~= nil then
    return true
  end
  return false
end

function Sprite:on_draw(data)
  self.frame = self.frame or 1
  if not self or not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
    log('buf id invalid', self)

    self.on_close()
    return
  end
  local content = {}
  data = data or self.data or Sprite.ActiveSprite.data
  if type(data) == 'string' then
    content = { data }
  elseif type(data) == 'table' then
    content = util.clone(data)
  elseif type(data) == 'function' then
    content = data()
  else
    log('invalid draw data', data, self.buf, self.win)
    return
  end

  local spinner = self.spinner[self.frame % #self.spinner + 1]
  content[1] = spinner .. content[1]

  trace('draw data: ', data[1], ' size: ', #data, self.buf, self.win)
  if #data < 1 then
    trace('nothing to redraw')
    return
  end
  local start = 0
  if self.header ~= nil then
    start = 1
  end
  local end_at = -1
  local bufnr = self.buf or Sprite.ActiveSprite.buf
  if bufnr == 0 then
    print('Error: plugin failure, please submit a issue')
  end
  trace('bufnr', bufnr)

  vim.api.nvim_set_option_value('readonly', false, {buf=bufnr})
  vim.api.nvim_buf_set_lines(bufnr, start, end_at, true, content)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', {buf=bufnr})
  if Sprite.hl_line ~= nil then
    Sprite.static.hl_id = vim.api.nvim_buf_add_highlight(self.buf, -1, 'GuihuaListSelHl', Sprite.hl_line - 1, 0, -1)
  end
  trace('sprite draw finished')
end

function Sprite.on_close()
  trace(debug.traceback())
  if Sprite.ActiveSprite == nil then
    log('view onclose nil')
    return
  end
  log('Sprite onclose ', Sprite.ActiveSprite.win)

  Sprite.ActiveSprite.is_run = false
  vim.schedule(function()
    if Sprite.ActiveSprite.__timer then
      Sprite.ActiveSprite.__timer:stop()
      uv.timer_stop(Sprite.ActiveSprite.__timer)
    end
    Sprite.ActiveSprite.__timer = nil
    if Sprite.ActiveSprite.__stop then
      Sprite.ActiveSprite.__stop(Sprite.ActiveSprite)
    end
    Sprite.ActiveSprite:close()
    Sprite.static.ActiveView = nil
  end)
end

return Sprite
