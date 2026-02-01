local config = require("smartcomplete.config")
local context = require("smartcomplete.suggestion.context")
local display = require("smartcomplete.suggestion.display")
local api = require("smartcomplete.api")
local debounce = require("smartcomplete.util.debounce")

local M = {}

M._enabled = false
M._debounced_trigger = nil
M._setup_done = false

--- Setup the suggestion system
function M.setup()
  if M._setup_done then
    return
  end

  local cfg = config.get()

  if not cfg.suggestion.enabled then
    return
  end

  M._enabled = true

  -- Create debounced trigger function
  M._debounced_trigger = debounce.debounce(function()
    M.trigger()
  end, cfg.trigger.debounce_ms)

  -- Setup autocommands
  M._setup_autocommands()

  -- Setup keymaps
  M._setup_keymaps()

  M._setup_done = true
end

--- Setup autocommands for auto-triggering and cleanup
function M._setup_autocommands()
  local group = vim.api.nvim_create_augroup("SmartcompleteSuggestion", { clear = true })
  local cfg = config.get()

  if cfg.trigger.auto then
    -- Auto-trigger on text change in insert mode
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
      group = group,
      callback = function()
        if M._enabled and M._should_trigger() then
          M._debounced_trigger()
        end
      end,
    })

    -- Also trigger when entering insert mode
    vim.api.nvim_create_autocmd("InsertEnter", {
      group = group,
      callback = function()
        if M._enabled and M._should_trigger() then
          M._debounced_trigger()
        end
      end,
    })

    -- Also trigger on cursor move in insert mode (when moving to new position)
    vim.api.nvim_create_autocmd("CursorMovedI", {
      group = group,
      callback = function()
        -- Only trigger if no current suggestion (don't interrupt existing one)
        if M._enabled and not display.has_suggestion() and M._should_trigger() then
          M._debounced_trigger()
        end
      end,
    })
  end

  -- Clear on cursor move (if moved away from suggestion)
  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = group,
    callback = function()
      local current = display.get_current()
      if current then
        local cursor = vim.api.nvim_win_get_cursor(0)
        -- Clear if cursor moved to a different row or before the suggestion column
        if cursor[1] ~= current.row or cursor[2] < current.col then
          display.clear()
          api.cancel()
        end
      end
    end,
  })

  -- Clear on leaving insert mode
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      display.clear()
      api.cancel()
    end,
  })

  -- Clear on buffer change
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function()
      display.clear()
      api.cancel()
    end,
  })

  -- Note: We no longer clear ghost text when cmp opens
  -- Ghost text stays visible so user can see full multi-line suggestions

  -- Check on any completion-related key that might open blink menu
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = group,
    callback = function()
      display.clear()
      api.cancel()
    end,
  })
end

--- Setup keymaps for accepting/dismissing suggestions
function M._setup_keymaps()
  local cfg = config.get()
  local keymaps = cfg.suggestion.keymap


  -- Accept full suggestion (insert mode)
  vim.keymap.set("i", keymaps.accept, function()
    if display.has_suggestion() then
      display.accept()
      -- If propagation is active, notify it that we accepted
      local propagate_ok, propagate = pcall(require, "smartcomplete.propagate")
      if propagate_ok and propagate.is_active() then
        vim.schedule(function()
          propagate.accept_current()
        end)
      end
    end
  end, { silent = true, desc = "Accept smartcomplete suggestion" })

  -- Accept full suggestion (normal mode)
  vim.keymap.set("n", keymaps.accept, function()
    if display.has_suggestion() then
      display.accept()
      -- If propagation is active, notify it that we accepted
      local propagate_ok, propagate = pcall(require, "smartcomplete.propagate")
      if propagate_ok and propagate.is_active() then
        vim.schedule(function()
          propagate.accept_current()
        end)
      end
    end
  end, { silent = true, desc = "Accept smartcomplete suggestion" })

  -- Accept word
  if keymaps.accept_word then
    vim.keymap.set({ "i", "n" }, keymaps.accept_word, function()
      if display.has_suggestion() then
        display.accept_word()
      end
    end, { silent = true, desc = "Accept next word" })
  end

  -- Accept line
  if keymaps.accept_line then
    vim.keymap.set({ "i", "n" }, keymaps.accept_line, function()
      if display.has_suggestion() then
        display.accept_line()
      end
    end, { silent = true, desc = "Accept next line" })
  end

  -- Dismiss
  if keymaps.dismiss then
    vim.keymap.set({ "i", "n" }, keymaps.dismiss, function()
      display.dismiss()
      api.cancel()
    end, { silent = true, desc = "Dismiss suggestion" })
  end
end

--- Check if we should trigger a completion
---@return boolean
function M._should_trigger()
  -- Check filetype
  local filetype = vim.bo.filetype
  if not config.is_enabled_for_filetype(filetype) then
    return false
  end

  -- Check excluded file patterns (.env, .pub, ssh config, etc.)
  local filepath = vim.api.nvim_buf_get_name(0)
  if config.is_excluded_file(filepath) then
    return false
  end

  -- Note: We allow triggering even when cmp is visible
  -- Ghost text coexists with cmp popup

  -- Check cursor position (not at beginning of line)
  local col = vim.api.nvim_win_get_cursor(0)[2]
  if col == 0 then
    return false
  end

  return true
end

--- Log helper (respects config level)
local function log(msg, level)
  level = level or vim.log.levels.INFO
  local cfg = config.get()
  local log_levels = { debug = 1, info = 2, warn = 3, error = 4 }
  local cfg_level = log_levels[cfg.log.level] or 3

  if level >= cfg_level then
    vim.notify("[Smartcomplete] " .. msg, level)
  end
end

--- Trigger a completion request
---@param force_show boolean|nil If true, show even if not in insert mode
function M.trigger(force_show)
  if not M._enabled then
    return
  end

  -- Cancel any pending request
  api.cancel()
  display.clear()

  -- Get context
  local ctx = context.get_context()

  -- Check provider
  local provider_ok, provider = pcall(function()
    return api.get_provider()
  end)

  if not provider_ok or not provider or not provider:is_available() then
    return
  end

  -- Request completion
  api.complete(ctx, function(completion)
    -- For auto-trigger, verify we're still in insert mode
    if not force_show and vim.fn.mode() ~= "i" then
      return
    end

    -- Display the suggestion
    if completion and completion ~= "" then
      display.show(completion, ctx.row, ctx.col)
    end
  end, function(err)
    -- Silent error handling - only log to debug
  end)
end

--- Manually trigger a completion (for manual mode)
function M.manual_trigger()
  if not config.get().suggestion.enabled then
    return
  end

  -- Temporarily enable if disabled
  local was_enabled = M._enabled
  M._enabled = true

  -- Force show even if not in insert mode
  M.trigger(true)

  -- Restore state if it was disabled
  if not was_enabled then
    M._enabled = was_enabled
  end
end

--- Enable suggestions
function M.enable()
  M._enabled = true
end

--- Disable suggestions
function M.disable()
  M._enabled = false
  display.clear()
  api.cancel()
end

--- Toggle suggestions
function M.toggle()
  if M._enabled then
    M.disable()
  else
    M.enable()
  end
  return M._enabled
end

--- Check if suggestions are enabled
---@return boolean
function M.is_enabled()
  return M._enabled
end

-- Export display functions for public API
M.accept = display.accept
M.accept_word = display.accept_word
M.accept_line = display.accept_line
M.dismiss = display.dismiss
M.has_suggestion = display.has_suggestion

return M
