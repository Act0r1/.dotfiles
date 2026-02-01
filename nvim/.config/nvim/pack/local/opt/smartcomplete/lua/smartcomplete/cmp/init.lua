local config = require("smartcomplete.config")

local M = {}

M._registered = false
M._backend = nil -- "blink" | "nvim-cmp" | nil

--- Setup completion integration (auto-detects blink.cmp or nvim-cmp)
function M.setup()
  local cfg = config.get()

  if not cfg.cmp.enabled then
    return
  end

  if M._registered then
    return
  end

  -- Try blink.cmp first (preferred)
  local has_blink, blink = pcall(require, "blink.cmp")
  if has_blink then
    M._setup_blink()
    return
  end

  -- Fall back to nvim-cmp
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    M._setup_nvim_cmp(cmp)
    return
  end

  -- Neither available, skip silently
end

--- Setup blink.cmp integration
function M._setup_blink()
  M._backend = "blink"
  M._registered = true
  -- Blink.cmp sources are registered via user config
  -- We just expose the source module
end

--- Setup nvim-cmp integration
---@param cmp table The nvim-cmp module
function M._setup_nvim_cmp(cmp)
  local source = require("smartcomplete.cmp.source")
  cmp.register_source("smartcomplete", source.new())
  M._backend = "nvim-cmp"
  M._registered = true
end

--- Get the blink.cmp source (for user config)
---@return table source The blink source instance
function M.get_blink_source()
  return require("smartcomplete.cmp.blink").new()
end

--- Get source configuration for users to add to their cmp sources
---@return table source_config
function M.get_source_config()
  local cfg = config.get()
  return {
    name = "smartcomplete",
    priority = cfg.cmp.priority,
    group_index = 1,
  }
end

--- Get which backend is being used
---@return string|nil backend "blink" | "nvim-cmp" | nil
function M.get_backend()
  return M._backend
end

return M
