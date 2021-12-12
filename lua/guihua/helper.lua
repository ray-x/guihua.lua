local uv = vim.loop
local DIR_SEP = package.config:sub(1, 1)

local function is_installed(bin)
  local env_path = os.getenv('PATH')
  local base_paths = vim.split(env_path, ':', true)

  for key, value in pairs(base_paths) do
    if uv.fs_stat(value .. DIR_SEP .. bin) then
      return true
    end
  end
  return false
end


return {is_installed = is_installed}
