local config = require("smartcomplete.config")
local context_mod = require("smartcomplete.suggestion.context")
local api_module = require("smartcomplete.api")

local source = {}

source.new = function()
  local self = setmetatable({}, { __index = source })
  self._pending_request = nil
  return self
end

function source:get_debug_name()
  return "smartcomplete"
end

function source:is_available()
  local cfg = config.get()
  if not cfg.cmp.enabled then
    return false
  end

  -- Check filetype
  local filetype = vim.bo.filetype
  if not config.is_enabled_for_filetype(filetype) then
    return false
  end

  -- Check provider availability
  local ok, provider = pcall(function()
    return api_module.get_provider()
  end)

  if not ok or not provider then
    return false
  end

  return provider:is_available()
end

function source:get_keyword_length()
  local cfg = config.get()
  return cfg.cmp.keyword_length
end

function source:get_trigger_characters()
  return { ".", ":", "(", "[", "{", " ", "\t", ",", "=" }
end

function source:complete(params, callback)
  -- Cancel any pending request
  if self._pending_request then
    api_module.cancel()
    self._pending_request = nil
  end

  -- Get context
  local ctx = context_mod.get_context()

  -- Mark request as pending
  self._pending_request = true

  -- Request completion from API
  api_module.complete(ctx, function(completion)
    self._pending_request = nil

    if not completion or completion == "" then
      callback({ items = {}, isIncomplete = false })
      return
    end

    -- Split into lines for display
    local lines = vim.split(completion, "\n", { plain = true })
    local label = lines[1] or completion

    -- Truncate label if too long
    if #label > 50 then
      label = label:sub(1, 47) .. "..."
    end

    local items = {
      {
        label = label,
        kind = 15, -- Snippet kind
        insertText = completion,
        insertTextFormat = 1, -- PlainText
        documentation = {
          kind = "markdown",
          value = "```" .. ctx.filetype .. "\n" .. completion .. "\n```",
        },
        data = {
          source = "smartcomplete",
          provider = config.get().provider,
        },
      },
    }

    callback({ items = items, isIncomplete = true })
  end, function(err)
    self._pending_request = nil
    -- Return empty on error
    callback({ items = {}, isIncomplete = false })
  end)
end

function source:resolve(completion_item, callback)
  -- Item is already resolved
  callback(completion_item)
end

function source:execute(completion_item, callback)
  -- No additional action needed
  callback(completion_item)
end

return source
