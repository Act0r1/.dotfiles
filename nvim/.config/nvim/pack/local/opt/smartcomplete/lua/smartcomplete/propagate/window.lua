local config = require("smartcomplete.config")

local M = {}

M._win_id = nil
M._buf_id = nil
M._locations = {}
M._on_select = nil

--- Create or update the floating window
---@param locations table List of {line = number, preview = string}
---@param on_select function|nil Callback when location is selected
function M.show(locations, on_select)
  M._locations = locations
  M._on_select = on_select

  if #locations == 0 then
    M.close()
    return
  end

  -- Build content
  local lines = {
    " " .. #locations .. " updates needed ",
    string.rep("─", 24),
  }
  for i, loc in ipairs(locations) do
    local preview = loc.preview or ""
    if #preview > 20 then
      preview = preview:sub(1, 20) .. "..."
    end
    table.insert(lines, string.format(" %d. Line %d: %s", i, loc.line, preview))
  end
  table.insert(lines, "")
  table.insert(lines, " ]s next  [s prev  <C-y> accept")

  -- Calculate dimensions
  local width = 30
  for _, line in ipairs(lines) do
    width = math.max(width, #line + 2)
  end
  local height = #lines

  -- Get editor dimensions
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  -- Position: top-right corner
  local row = 1
  local col = editor_width - width - 2

  -- Create buffer if needed
  if not M._buf_id or not vim.api.nvim_buf_is_valid(M._buf_id) then
    M._buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M._buf_id, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(M._buf_id, "filetype", "smartcomplete_propagate")
  end

  -- Set content
  vim.api.nvim_buf_set_lines(M._buf_id, 0, -1, false, lines)

  -- Create or update window
  local win_opts = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Propagate ",
    title_pos = "center",
  }

  if M._win_id and vim.api.nvim_win_is_valid(M._win_id) then
    vim.api.nvim_win_set_config(M._win_id, win_opts)
  else
    M._win_id = vim.api.nvim_open_win(M._buf_id, false, win_opts)
    vim.api.nvim_win_set_option(M._win_id, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder")
    vim.api.nvim_win_set_option(M._win_id, "cursorline", false)
  end

  -- Add highlights
  local ns = vim.api.nvim_create_namespace("smartcomplete_propagate_win")
  vim.api.nvim_buf_clear_namespace(M._buf_id, ns, 0, -1)

  -- Highlight header
  if #lines > 0 then
    vim.api.nvim_buf_add_highlight(M._buf_id, ns, "Title", 0, 0, -1)
  end
  -- Highlight help line
  if #lines > 1 then
    vim.api.nvim_buf_add_highlight(M._buf_id, ns, "Comment", #lines - 1, 0, -1)
  end
end

--- Update the location count (after accepting one)
---@param remaining number Number of remaining locations
function M.update_count(remaining)
  if remaining == 0 then
    M.close()
    return
  end

  -- Just update the first line
  if M._buf_id and vim.api.nvim_buf_is_valid(M._buf_id) then
    local new_header = " " .. remaining .. " updates needed "
    vim.api.nvim_buf_set_lines(M._buf_id, 0, 1, false, { new_header })
  end
end

--- Close the floating window
function M.close()
  if M._win_id and vim.api.nvim_win_is_valid(M._win_id) then
    vim.api.nvim_win_close(M._win_id, true)
  end
  M._win_id = nil
  M._buf_id = nil
  M._locations = {}
  M._on_select = nil
end

--- Check if window is visible
---@return boolean
function M.is_visible()
  return M._win_id ~= nil and vim.api.nvim_win_is_valid(M._win_id)
end

--- Get current locations
---@return table
function M.get_locations()
  return M._locations
end

--- Remove a location from the list
---@param line number Line number to remove
function M.remove_location(line)
  M._locations = vim.tbl_filter(function(loc)
    return loc.line ~= line
  end, M._locations)

  if #M._locations == 0 then
    M.close()
  else
    M.show(M._locations, M._on_select)
  end
end

return M
