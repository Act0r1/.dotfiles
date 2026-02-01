local config = require("smartcomplete.config")
local signs = require("smartcomplete.propagate.signs")
local window = require("smartcomplete.propagate.window")
local analyze = require("smartcomplete.propagate.analyze")
local display = require("smartcomplete.suggestion.display")

local M = {}

M._setup_done = false
M._buffer_content_before = nil
M._buffer_before_line_count = 0
M._locations = {}  -- {line = number, suggestion = string, preview = string}
M._current_index = 0

--- Setup the propagation system
function M.setup()
  if M._setup_done then
    return
  end

  local cfg = config.get()
  if not cfg.propagate.enabled then
    return
  end

  M._setup_autocommands()
  M._setup_keymaps()
  M._setup_done = true
end

--- Setup autocommands
function M._setup_autocommands()
  local group = vim.api.nvim_create_augroup("SmartcompletePropagation", { clear = true })
  local cfg = config.get()

  -- Capture buffer content before editing
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      M._buffer_content_before = table.concat(lines, "\n")
      M._buffer_before_line_count = #lines
    end,
  })

  -- Check for changes on InsertLeave
  if cfg.propagate.auto_trigger then
    vim.api.nvim_create_autocmd("InsertLeave", {
      group = group,
      callback = function()
        M._check_for_propagation()
      end,
    })
  end

  -- Clear on buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function()
      M.clear()
    end,
  })
end

--- Setup keymaps
function M._setup_keymaps()
  local cfg = config.get()
  local keymaps = cfg.propagate.keymap

  -- Next location
  vim.keymap.set("n", keymaps.next, function()
    M.goto_next()
  end, { silent = true, desc = "Go to next propagation location" })

  -- Previous location
  vim.keymap.set("n", keymaps.prev, function()
    M.goto_prev()
  end, { silent = true, desc = "Go to previous propagation location" })

  -- Dismiss current
  vim.keymap.set("n", keymaps.dismiss, function()
    M.dismiss_current()
  end, { silent = true, desc = "Dismiss current propagation suggestion" })

  -- Clear all
  vim.keymap.set("n", keymaps.clear_all, function()
    M.clear()
  end, { silent = true, desc = "Clear all propagation suggestions" })
end

--- Check if we should trigger propagation analysis
function M._check_for_propagation()
  if not M._buffer_content_before then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines_after = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content_after = table.concat(lines_after, "\n")

  -- Check if content changed
  if content_after == M._buffer_content_before then
    return
  end

  -- Check if lines were added (not just modified)
  local lines_added = #lines_after - M._buffer_before_line_count
  if lines_added <= 0 then
    -- No new lines added, probably just editing existing line
    -- Could still trigger on significant edits, but for now skip
    return
  end

  -- Find what was added
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  -- Get the added text (rough approximation - lines around cursor)
  local start_line = math.max(1, current_line - lines_added)
  local end_line = current_line
  local added_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local added_text = table.concat(added_lines, "\n")

  -- Skip if added text is too small (just whitespace or tiny edit)
  local trimmed = added_text:gsub("%s+", "")
  if #trimmed < 5 then
    return
  end

  -- Trigger analysis
  M.trigger(content_after, added_text, current_line)
end

--- Trigger propagation analysis
---@param file_content string Full file content
---@param added_text string The text that was added
---@param added_line number The line where text was added
function M.trigger(file_content, added_text, added_line)
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  -- Show loading indicator
  vim.notify("Analyzing for related updates...", vim.log.levels.INFO)

  analyze.find_related_locations(file_content, added_text, added_line, filetype, function(locations)
    vim.schedule(function()
      if #locations == 0 then
        vim.notify("No related locations found", vim.log.levels.INFO)
        return
      end

      M._locations = locations
      M._current_index = 0

      -- Show signs
      local cfg = config.get()
      if cfg.propagate.show_signs then
        signs.place(bufnr, locations)
      end

      -- Show window
      if cfg.propagate.show_window then
        window.show(locations)
      end

      vim.notify(string.format("Found %d related locations. Press ]s to jump.", #locations), vim.log.levels.INFO)

      -- Don't auto-jump - user presses ]s to navigate
    end)
  end, function(err)
    vim.schedule(function()
      vim.notify("Propagation analysis failed: " .. tostring(err), vim.log.levels.ERROR)
    end)
  end)
end

--- Go to next propagation location
function M.goto_next()
  if #M._locations == 0 then
    return
  end

  M._current_index = M._current_index + 1
  if M._current_index > #M._locations then
    M._current_index = 1
  end

  M._goto_location(M._current_index)
end

--- Go to previous propagation location
function M.goto_prev()
  if #M._locations == 0 then
    return
  end

  M._current_index = M._current_index - 1
  if M._current_index < 1 then
    M._current_index = #M._locations
  end

  M._goto_location(M._current_index)
end

--- Go to specific location by index
---@param index number 1-indexed location
function M._goto_location(index)
  local loc = M._locations[index]
  if not loc then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Move cursor to the line
  vim.api.nvim_win_set_cursor(0, { loc.line, 0 })

  -- Center the line
  vim.cmd("normal! zz")

  -- Show ghost text suggestion
  -- Get the current line content to determine column
  local line_content = vim.api.nvim_buf_get_lines(bufnr, loc.line - 1, loc.line, false)[1] or ""
  local col = #line_content

  display.show(loc.suggestion, loc.line, col)
end

--- Accept current suggestion and move to next
function M.accept_current()
  if M._current_index == 0 or M._current_index > #M._locations then
    return false
  end

  local loc = M._locations[M._current_index]
  if not loc then
    return false
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = config.get()

  -- Clear ghost text (will be inserted via accept)
  display.clear()

  -- Remove the sign at this line
  signs.remove_at_line(bufnr, loc.line)

  -- Remove from locations list
  table.remove(M._locations, M._current_index)

  -- Update window
  window.remove_location(loc.line)

  -- Adjust index
  if M._current_index > #M._locations then
    M._current_index = #M._locations
  end

  -- Auto-jump to next if enabled and there are more
  if cfg.propagate.auto_jump_after_accept and #M._locations > 0 then
    -- Index already adjusted, just go to current (which is next)
    M._goto_location(M._current_index)
  elseif #M._locations == 0 then
    vim.notify("All updates complete!", vim.log.levels.INFO)
    M.clear()
  end

  return true
end

--- Dismiss current and move to next
function M.dismiss_current()
  if M._current_index == 0 or M._current_index > #M._locations then
    return
  end

  local loc = M._locations[M._current_index]
  if not loc then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Clear ghost text
  display.clear()

  -- Remove the sign
  signs.remove_at_line(bufnr, loc.line)

  -- Remove from locations list
  table.remove(M._locations, M._current_index)

  -- Update window
  window.remove_location(loc.line)

  -- Adjust index and go to next
  if M._current_index > #M._locations then
    M._current_index = #M._locations
  end

  if #M._locations > 0 then
    M._goto_location(M._current_index)
  else
    M.clear()
  end
end

--- Clear all propagation state
function M.clear()
  local bufnr = vim.api.nvim_get_current_buf()

  signs.clear(bufnr)
  window.close()
  display.clear()

  M._locations = {}
  M._current_index = 0
  M._buffer_content_before = nil
end

--- Manual trigger (for command)
function M.manual_trigger()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Get current line as "added" text
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]
  local added_text = lines[current_line] or ""

  M.trigger(content, added_text, current_line)
end

--- Check if propagation is active
---@return boolean
function M.is_active()
  return #M._locations > 0
end

--- Get current location count
---@return number
function M.get_count()
  return #M._locations
end

return M
