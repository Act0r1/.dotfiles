local M = {}

M.commands = {
  enable = function()
    require("smartcomplete").enable()
    vim.notify("Smartcomplete enabled", vim.log.levels.INFO)
  end,

  disable = function()
    require("smartcomplete").disable()
    vim.notify("Smartcomplete disabled", vim.log.levels.INFO)
  end,

  toggle = function()
    local enabled = require("smartcomplete").toggle()
    vim.notify("Smartcomplete " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO)
  end,

  trigger = function()
    require("smartcomplete").trigger()
  end,

  accept = function()
    local accepted = require("smartcomplete").accept()
    if not accepted then
      vim.notify("No suggestion to accept", vim.log.levels.WARN)
    end
  end,

  status = function()
    local cfg = require("smartcomplete.config").get()
    local api = require("smartcomplete.api")
    local suggestion = require("smartcomplete.suggestion")

    local ok, provider = pcall(function()
      return api.get_provider()
    end)

    local available = ok and provider and provider:is_available()

    local lines = {
      "Smartcomplete Status:",
      "  Enabled: " .. tostring(suggestion.is_enabled()),
      "  Provider: " .. cfg.provider,
      "  Available: " .. tostring(available),
      "  Model: " .. (cfg.models[cfg.provider] or "unknown"),
      "  Auto-trigger: " .. tostring(cfg.trigger.auto),
      "  Debounce: " .. cfg.trigger.debounce_ms .. "ms",
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end,

  provider = function(args)
    local provider_name = args[1]
    if not provider_name then
      vim.notify("Usage: Smartcomplete provider <openrouter|anthropic>", vim.log.levels.WARN)
      return
    end

    if provider_name ~= "openrouter" and provider_name ~= "anthropic" then
      vim.notify("Unknown provider: " .. provider_name .. ". Use 'openrouter' or 'anthropic'.", vim.log.levels.ERROR)
      return
    end

    require("smartcomplete").switch_provider(provider_name)
    vim.notify("Switched to " .. provider_name, vim.log.levels.INFO)
  end,

  propagate = function(args)
    local subcmd = args[1] or "trigger"

    if subcmd == "trigger" then
      require("smartcomplete").propagate()
    elseif subcmd == "clear" then
      require("smartcomplete").propagate_clear()
      vim.notify("Propagation suggestions cleared", vim.log.levels.INFO)
    elseif subcmd == "next" then
      require("smartcomplete").propagate_next()
    elseif subcmd == "prev" then
      require("smartcomplete").propagate_prev()
    else
      vim.notify("Usage: Smartcomplete propagate [trigger|clear|next|prev]", vim.log.levels.WARN)
    end
  end,
}

--- Setup commands (called from init)
function M.setup()
  -- Commands are set up in plugin/smartcomplete.lua
end

--- Execute a command
---@param args_str string The command arguments as a string
function M.execute(args_str)
  local args = vim.split(args_str, "%s+", { trimempty = true })
  local cmd = args[1] or "status"
  local cmd_args = {}
  for i = 2, #args do
    table.insert(cmd_args, args[i])
  end

  local handler = M.commands[cmd]
  if handler then
    handler(cmd_args)
  else
    vim.notify("Unknown command: " .. cmd .. ". Available: enable, disable, toggle, trigger, status, provider, propagate", vim.log.levels.WARN)
  end
end

--- Command completion
---@param line string The current command line
---@return table completions
function M.complete(line)
  local args = vim.split(line, "%s+", { trimempty = true })

  if #args <= 2 then
    -- Complete command names
    local commands = vim.tbl_keys(M.commands)
    if #args == 2 then
      return vim.tbl_filter(function(c)
        return vim.startswith(c, args[2])
      end, commands)
    end
    return commands
  end

  -- Complete command arguments
  if args[2] == "provider" then
    local providers = { "openrouter", "anthropic" }
    if args[3] then
      return vim.tbl_filter(function(p)
        return vim.startswith(p, args[3])
      end, providers)
    end
    return providers
  end

  if args[2] == "propagate" then
    local subcmds = { "trigger", "clear", "next", "prev" }
    if args[3] then
      return vim.tbl_filter(function(s)
        return vim.startswith(s, args[3])
      end, subcmds)
    end
    return subcmds
  end

  return {}
end

return M
