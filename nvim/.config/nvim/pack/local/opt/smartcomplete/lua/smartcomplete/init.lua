local M = {}

M._setup_done = false

--- Setup smartcomplete with user configuration
---@param opts table|nil User configuration options
function M.setup(opts)
  if M._setup_done then
    return
  end

  -- Initialize configuration
  local cfg = require("smartcomplete.config").setup(opts)

  -- Setup suggestion system (ghost text)
  if cfg.suggestion.enabled then
    require("smartcomplete.suggestion").setup()
  end

  -- Setup nvim-cmp integration
  if cfg.cmp.enabled then
    require("smartcomplete.cmp").setup()
  end

  -- Setup propagation feature
  if cfg.propagate.enabled then
    require("smartcomplete.propagate").setup()
  end

  -- Setup commands
  require("smartcomplete.commands").setup()

  -- Setup highlights
  M._setup_highlights()

  M._setup_done = true
end

--- Setup highlight groups
function M._setup_highlights()
  -- Ghost text highlight (default links to Comment)
  vim.api.nvim_set_hl(0, "SmartcompleteGhost", {
    default = true,
    link = "Comment",
  })

  -- nvim-cmp kind highlight
  vim.api.nvim_set_hl(0, "CmpItemKindSmartcomplete", {
    default = true,
    fg = "#6CC644", -- Green color
  })
end

-- Public API

--- Manually trigger a completion
function M.trigger()
  require("smartcomplete.suggestion").manual_trigger()
end

--- Accept the current suggestion
---@return boolean Whether a suggestion was accepted
function M.accept()
  return require("smartcomplete.suggestion").accept()
end

--- Accept the next word from the suggestion
---@return boolean Whether a word was accepted
function M.accept_word()
  return require("smartcomplete.suggestion").accept_word()
end

--- Accept the next line from the suggestion
---@return boolean Whether a line was accepted
function M.accept_line()
  return require("smartcomplete.suggestion").accept_line()
end

--- Dismiss the current suggestion
---@return boolean Whether a suggestion was dismissed
function M.dismiss()
  return require("smartcomplete.suggestion").dismiss()
end

--- Enable suggestions
function M.enable()
  require("smartcomplete.suggestion").enable()
end

--- Disable suggestions
function M.disable()
  require("smartcomplete.suggestion").disable()
end

--- Toggle suggestions on/off
---@return boolean The new enabled state
function M.toggle()
  return require("smartcomplete.suggestion").toggle()
end

--- Check if suggestions are enabled
---@return boolean
function M.is_enabled()
  return require("smartcomplete.suggestion").is_enabled()
end

--- Check if there's a visible suggestion
---@return boolean
function M.has_suggestion()
  return require("smartcomplete.suggestion").has_suggestion()
end

--- Switch to a different provider
---@param provider string Provider name ("openrouter" or "anthropic")
function M.switch_provider(provider)
  require("smartcomplete.api").switch_provider(provider)
end

--- Get the current configuration
---@return table config
function M.get_config()
  return require("smartcomplete.config").get()
end

-- Propagation API

--- Manually trigger propagation analysis
function M.propagate()
  require("smartcomplete.propagate").manual_trigger()
end

--- Clear all propagation suggestions
function M.propagate_clear()
  require("smartcomplete.propagate").clear()
end

--- Go to next propagation location
function M.propagate_next()
  require("smartcomplete.propagate").goto_next()
end

--- Go to previous propagation location
function M.propagate_prev()
  require("smartcomplete.propagate").goto_prev()
end

return M
