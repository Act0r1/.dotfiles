local config = require("smartcomplete.config")

local M = {}

--- Get the current buffer context around the cursor
---@return table context The context object
function M.get_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local row = cursor[1] -- 1-indexed
  local col = cursor[2] -- 0-indexed

  local line_count = vim.api.nvim_buf_line_count(bufnr)

  -- Get ALL lines from start to cursor line (full context)
  local prefix_lines = vim.api.nvim_buf_get_lines(bufnr, 0, row, false)

  -- Get current line and adjust to cursor position
  local current_line = prefix_lines[#prefix_lines] or ""
  prefix_lines[#prefix_lines] = string.sub(current_line, 1, col)

  -- Get ALL lines from cursor to end (full context)
  local suffix_lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, line_count, false)

  -- Adjust current line in suffix (text after cursor)
  local suffix_current = suffix_lines[1] or ""
  suffix_lines[1] = string.sub(suffix_current, col + 1)

  return {
    bufnr = bufnr,
    row = row,
    col = col,
    prefix = table.concat(prefix_lines, "\n"),
    suffix = table.concat(suffix_lines, "\n"),
    current_line = current_line,
    line_before_cursor = string.sub(current_line, 1, col),
    line_after_cursor = string.sub(current_line, col + 1),
    filename = vim.fn.expand("%:t"),
    filepath = vim.fn.expand("%:p"),
    filetype = vim.bo[bufnr].filetype,
  }
end

--- Get the word under/before the cursor
---@return string word The word before cursor
function M.get_cursor_word()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-indexed

  if col == 0 then
    return ""
  end

  -- Find word boundaries (going backwards from cursor)
  -- col is 0-indexed, but Lua strings are 1-indexed
  local start_col = col -- This is the char index (1-indexed in lua would be col+1)
  while start_col > 0 and line:sub(start_col, start_col):match("[%w_]") do
    start_col = start_col - 1
  end

  -- Return the word from start_col+1 to col (inclusive)
  return line:sub(start_col + 1, col)
end

--- Check if cursor is at a position where completion makes sense
---@return boolean
function M.should_complete()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  -- Don't complete at the very beginning of a line
  if col == 0 then
    return false
  end

  -- Always allow completion - let the AI decide what makes sense
  return true
end

return M
