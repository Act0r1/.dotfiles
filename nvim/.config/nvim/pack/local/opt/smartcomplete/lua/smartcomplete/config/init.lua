local M = {}

local defaults = require("smartcomplete.config.defaults")

M._config = nil

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", defaults.defaults, opts or {})

  -- Resolve API keys from environment if not provided
  if not M._config.api_keys.openrouter then
    M._config.api_keys.openrouter = vim.env.OPENROUTER_API_KEY
  end
  if not M._config.api_keys.anthropic then
    M._config.api_keys.anthropic = vim.env.ANTHROPIC_API_KEY or vim.env.ANTROPIC_API_KEY
  end

  return M._config
end

function M.get()
  if not M._config then
    M._config = vim.tbl_deep_extend("force", {}, defaults.defaults)
  end
  return M._config
end

function M.is_enabled_for_filetype(filetype)
  local ft_config = M.get().filetypes
  if ft_config[filetype] ~= nil then
    return ft_config[filetype]
  end
  return ft_config["*"] or false
end

function M.is_excluded_file(filepath)
  if not filepath or filepath == "" then
    return false
  end

  local patterns = M.get().excluded_patterns or {}
  for _, pattern in ipairs(patterns) do
    if filepath:match(pattern) then
      return true
    end
  end
  return false
end

return M
