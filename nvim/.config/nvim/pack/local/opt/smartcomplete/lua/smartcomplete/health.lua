local M = {}

function M.check()
  vim.health.start("smartcomplete.nvim")

  -- Check Neovim version
  local version = vim.version()
  local version_str = string.format("%d.%d.%d", version.major, version.minor, version.patch)

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim version: " .. version_str)
  else
    vim.health.error("Requires Neovim 0.10+, found: " .. version_str)
  end

  -- Check curl availability
  if vim.fn.executable("curl") == 1 then
    vim.health.ok("curl is available")
  else
    vim.health.error("curl is required but not found in PATH")
  end

  -- Check vim.system availability
  if vim.system then
    vim.health.ok("vim.system is available")
  else
    vim.health.error("vim.system not available (requires Neovim 0.10+)")
  end

  -- Check API keys
  local config = require("smartcomplete.config").get()

  if config.api_keys.openrouter then
    vim.health.ok("OpenRouter API key configured")
  else
    vim.health.warn("OpenRouter API key not set (set OPENROUTER_API_KEY env var or config)")
  end

  if config.api_keys.anthropic then
    vim.health.ok("Anthropic API key configured")
  else
    vim.health.warn("Anthropic API key not set (set ANTHROPIC_API_KEY or ANTROPIC_API_KEY env var)")
  end

  -- Check current provider
  local api = require("smartcomplete.api")
  local ok, provider = pcall(function()
    return api.get_provider()
  end)

  if ok and provider then
    if provider:is_available() then
      vim.health.ok("Current provider (" .. config.provider .. ") is available")
    else
      vim.health.error("Current provider (" .. config.provider .. ") is NOT available - check API key")
    end
  else
    vim.health.error("Failed to initialize provider: " .. config.provider)
  end

  -- Check completion plugin integration
  local has_blink = pcall(require, "blink.cmp")
  local has_cmp = pcall(require, "cmp")

  if has_blink then
    vim.health.ok("blink.cmp detected - integration available")
  elseif has_cmp then
    vim.health.ok("nvim-cmp detected - integration available")
  else
    vim.health.info("No completion plugin detected (blink.cmp or nvim-cmp)")
  end

  -- Check suggestion system
  local suggestion = require("smartcomplete.suggestion")
  if suggestion.is_enabled() then
    vim.health.ok("Suggestion system is enabled")
  else
    vim.health.info("Suggestion system is disabled")
  end
end

return M
