local config = require("smartcomplete.config")

local M = {}

M.ns_id = vim.api.nvim_create_namespace("smartcomplete_ghost")
M._current_suggestion = nil
M._extmark_id = nil

-- Debug logging
local function debug_log(msg)
  local log_file = vim.fn.stdpath("cache") .. "/smartcomplete_debug.log"
  local f = io.open(log_file, "a")
  if f then
    f:write(os.date("%H:%M:%S") .. " | " .. msg .. "\n")
    f:close()
  end
end

--- Show a suggestion as ghost text
---@param suggestion string The suggestion text
---@param row number The 1-indexed row
---@param col number The 0-indexed column
function M.show(suggestion, row, col)
  if not suggestion or suggestion == "" then
    return
  end

  M.clear()

  local cfg = config.get()
  local bufnr = vim.api.nvim_get_current_buf()

  debug_log("=== NEW SUGGESTION ===")
  debug_log("Raw suggestion: [" .. suggestion:gsub("\n", "\\n") .. "]")
  debug_log("Row: " .. row .. ", Col: " .. col)

  -- Get base indentation - from current line, or previous line if current is empty
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local base_indent = current_line:match("^(%s*)") or ""

  debug_log("Current line: [" .. current_line .. "]")
  debug_log("Base indent from current: " .. #base_indent .. " chars")

  -- If current line is empty/whitespace-only, use previous line's indentation
  if current_line:match("^%s*$") and row > 1 then
    local prev_line = vim.api.nvim_buf_get_lines(bufnr, row - 2, row - 1, false)[1] or ""
    base_indent = prev_line:match("^(%s*)") or ""
    debug_log("Current line empty, using prev line: [" .. prev_line .. "]")
    debug_log("Base indent from prev: " .. #base_indent .. " chars")
  end

  -- Split suggestion into lines and normalize tabs to spaces
  local raw_lines = vim.split(suggestion, "\n", { plain = true })
  local lines = {}
  for i, line in ipairs(raw_lines) do
    -- Convert tabs to spaces (using 4-space tabs)
    lines[i] = line:gsub("\t", "    ")
  end
  debug_log("Total lines: " .. #lines)

  -- Store current suggestion
  M._current_suggestion = {
    text = suggestion,
    lines = lines,
    row = row,
    col = col,
    bufnr = bufnr,
  }

  -- Build virtual text
  local hl_group = cfg.suggestion.highlight

  -- First line is inline at cursor position
  local virt_text = {}
  if lines[1] and lines[1] ~= "" then
    virt_text = { { lines[1], hl_group } }
  end

  -- Remaining lines as virtual lines below
  -- Just display exactly what the AI returns - trust the AI's indentation
  local virt_lines = {}
  for i = 2, #lines do
    local line = lines[i]
    debug_log("Line " .. i .. ": [" .. line .. "]")
    table.insert(virt_lines, { { line, hl_group } })
  end
  debug_log("=== END ===\n")

  -- Set the extmark
  local opts = {
    id = 1, -- Fixed ID for easy updates
    virt_text = virt_text,
    virt_text_pos = "inline", -- inline continues from cursor without hiding existing text
    hl_mode = "combine",
  }

  if #virt_lines > 0 then
    opts.virt_lines = virt_lines
  end

  local ok, err = pcall(function()
    M._extmark_id = vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, row - 1, col, opts)
  end)

  if not ok then
    M._current_suggestion = nil
    M._extmark_id = nil
  end
end

--- Clear the current suggestion
function M.clear()
  if M._current_suggestion then
    pcall(function()
      vim.api.nvim_buf_clear_namespace(M._current_suggestion.bufnr, M.ns_id, 0, -1)
    end)
  end
  M._current_suggestion = nil
  M._extmark_id = nil
end

--- Accept the full suggestion
---@return boolean Whether a suggestion was accepted
function M.accept()
  if not M._current_suggestion then
    return false
  end

  local suggestion = M._current_suggestion
  local text = suggestion.text

  -- Clear the ghost text first
  M.clear()

  -- Insert the text using feedkeys (works from expr mappings)
  -- Escape special characters for feedkeys
  local escaped = vim.api.nvim_replace_termcodes(text, true, false, true)
  vim.api.nvim_feedkeys(escaped, "n", true)

  return true
end

--- Accept the next word from the suggestion
---@return boolean Whether a word was accepted
function M.accept_word()
  if not M._current_suggestion then
    return false
  end

  local text = M._current_suggestion.text

  -- Extract first word (including leading whitespace if any)
  local word = text:match("^(%s*%S+)")

  if not word then
    return false
  end

  -- Calculate remaining text
  local remaining = text:sub(#word + 1)

  -- Clear current suggestion
  M.clear()

  -- Insert the word using feedkeys
  local escaped = vim.api.nvim_replace_termcodes(word, true, false, true)
  vim.api.nvim_feedkeys(escaped, "n", true)

  -- Show remaining if any (deferred)
  if remaining and remaining ~= "" then
    vim.schedule(function()
      local new_cursor = vim.api.nvim_win_get_cursor(0)
      M.show(remaining, new_cursor[1], new_cursor[2])
    end)
  end

  return true
end

--- Accept the current line from the suggestion
---@return boolean Whether a line was accepted
function M.accept_line()
  if not M._current_suggestion then
    return false
  end

  local lines = M._current_suggestion.lines
  local first_line = lines[1]

  if not first_line or first_line == "" then
    return false
  end

  -- Clear current suggestion
  M.clear()

  -- Insert first line using feedkeys
  local escaped = vim.api.nvim_replace_termcodes(first_line, true, false, true)
  vim.api.nvim_feedkeys(escaped, "n", true)

  -- Show remaining lines if any
  if #lines > 1 then
    local remaining_lines = {}
    for i = 2, #lines do
      table.insert(remaining_lines, lines[i])
    end
    local remaining = table.concat(remaining_lines, "\n")

    if remaining ~= "" then
      local new_cursor = vim.api.nvim_win_get_cursor(0)
      vim.schedule(function()
        M.show(remaining, new_cursor[1], new_cursor[2])
      end)
    end
  end

  return true
end

--- Dismiss the current suggestion
---@return boolean Whether a suggestion was dismissed
function M.dismiss()
  if M._current_suggestion then
    M.clear()
    return true
  end
  return false
end

--- Check if there's a visible suggestion
---@return boolean
function M.has_suggestion()
  return M._current_suggestion ~= nil
end

--- Get the current suggestion data
---@return table|nil
function M.get_current()
  return M._current_suggestion
end

return M
