local M={}
-- add log to you lsp.log
function M.log(...)
  local arg = {...}
  if vim.g.debug_output == true then
    local str = " "
    for i, v in ipairs(arg) do
      if type(v) == "table" then
        str = str .. " |" .. tostring(i) .. ": " .. vim.inspect(v) .. "\n"
      else
        str = str .. " |" .. tostring(i) .. ": " .. tostring(v)
      end
    end
    if #str > 2 then
      if M.log_path ~= nil and #M.log_path > 3 then
        local f = io.open(M.log_path, "a+")
        io.output(f)
        io.write(str)
        io.close(f)
      else
        print(str .. '\n')
      end
    end
  end
end

function M.verbose(...)
  if vim.g.debug_verbose_output == true then
    M.log(...)
  end
end

return M
