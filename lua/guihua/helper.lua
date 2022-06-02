local uv = vim.loop
local DIR_SEP = package.config:sub(1, 1)
local os_name = uv.os_uname().sysname
local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'
local path_sep = is_windows and ";" or ":"
local exe = is_windows and ".exe" or ""

local function is_installed(bin)
  local env_path = os.getenv('PATH')
  local base_paths = vim.split(env_path, path_sep, true)

  for _, value in pairs(base_paths) do
    if uv.fs_stat(value .. DIR_SEP .. bin .. exe) then
      return true
    end
  end
  return false
end


return {is_installed = is_installed}
