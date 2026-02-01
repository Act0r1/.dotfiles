-- Blink.cmp source for smartcomplete
local config = require("smartcomplete.config")
local context_mod = require("smartcomplete.suggestion.context")
local api_module = require("smartcomplete.api")

---@class smartcomplete.BlinkSource : blink.cmp.Source
local source = {}

function source.new()
  local self = setmetatable({}, { __index = source })
  self._pending_request = nil
  return self
end

function source:get_trigger_characters()
  return { ".", ":", "(", "[", "{", " ", "\t", ",", "=" }
end

function source:enabled()
  local cfg = config.get()
  if not cfg.cmp.enabled then
    return false
  end

  local filetype = vim.bo.filetype
  if not config.is_enabled_for_filetype(filetype) then
    return false
  end

  local ok, provider = pcall(function()
    return api_module.get_provider()
  end)

  return ok and provider and provider:is_available()
end

function source:get_completions(ctx, callback)
  -- Cancel any pending request
  if self._pending_request then
    api_module.cancel()
    self._pending_request = nil
  end

  -- Get context
  local context = context_mod.get_context()

  -- Mark request as pending
  self._pending_request = true

  -- Request completion from API
  api_module.complete(context, function(completion)
    self._pending_request = nil

    if not completion or completion == "" then
      callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
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
        kind = vim.lsp.protocol.CompletionItemKind.Text,
        insertText = completion,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        documentation = {
          kind = "markdown",
          value = "```" .. context.filetype .. "\n" .. completion .. "\n```",
        },
        data = {
          source = "smartcomplete",
          provider = config.get().provider,
        },
      },
    }

    callback({ is_incomplete_forward = true, is_incomplete_backward = true, items = items })
  end, function(err)
    self._pending_request = nil
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end)
end

function source:resolve(item, callback)
  callback(item)
end

return source
