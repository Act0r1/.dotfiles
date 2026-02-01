local config = require("smartcomplete.config")

local M = {}

M._provider = nil

--- Get the current API provider instance
---@return table provider The provider instance
function M.get_provider()
  if M._provider then
    return M._provider
  end

  local cfg = config.get()
  local provider_name = cfg.provider

  if provider_name == "openrouter" then
    M._provider = require("smartcomplete.api.openrouter").new()
  elseif provider_name == "anthropic" then
    M._provider = require("smartcomplete.api.anthropic").new()
  else
    error("Unknown provider: " .. provider_name)
  end

  return M._provider
end

--- Switch to a different provider
---@param provider_name string The provider name ("openrouter" or "anthropic")
---@return table provider The new provider instance
function M.switch_provider(provider_name)
  local cfg = config.get()
  cfg.provider = provider_name
  M._provider = nil
  return M.get_provider()
end

--- Request a completion from the current provider
---@param context table The context object with prefix, suffix, etc.
---@param callback function Called with the completion text
---@param on_error function|nil Called on error with error message
function M.complete(context, callback, on_error)
  return M.get_provider():complete(context, callback, on_error)
end

--- Cancel any pending request
---@return boolean Whether a request was cancelled
function M.cancel()
  if M._provider then
    return M._provider:cancel()
  end
  return false
end

--- Check if the current provider is available
---@return boolean
function M.is_available()
  return M.get_provider():is_available()
end

return M
