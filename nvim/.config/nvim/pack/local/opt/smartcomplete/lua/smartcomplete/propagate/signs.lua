local config = require("smartcomplete.config")

local M = {}

M.SIGN_NAME = "SmartcompletePropagation"
M._sign_ids = {}
M._defined = false

--- Define the sign (call once)
function M.define()
  if M._defined then
    return
  end

  local cfg = config.get()
  vim.fn.sign_define(M.SIGN_NAME, {
    text = cfg.propagate.sign_text,
    texthl = cfg.propagate.sign_hl,
  })
  M._defined = true
end

--- Place signs at given line numbers
---@param bufnr number Buffer number
---@param lines table List of {line = number, suggestion = string}
function M.place(bufnr, lines)
  M.define()
  M.clear(bufnr)

  for _, item in ipairs(lines) do
    local id = vim.fn.sign_place(0, "smartcomplete_propagate", M.SIGN_NAME, bufnr, {
      lnum = item.line,
      priority = 10,
    })
    table.insert(M._sign_ids, { bufnr = bufnr, id = id })
  end
end

--- Clear all propagation signs in buffer
---@param bufnr number|nil Buffer number (nil for all buffers)
function M.clear(bufnr)
  if bufnr then
    vim.fn.sign_unplace("smartcomplete_propagate", { buffer = bufnr })
    M._sign_ids = vim.tbl_filter(function(s)
      return s.bufnr ~= bufnr
    end, M._sign_ids)
  else
    vim.fn.sign_unplace("smartcomplete_propagate")
    M._sign_ids = {}
  end
end

--- Check if there are any signs in buffer
---@param bufnr number Buffer number
---@return boolean
function M.has_signs(bufnr)
  local signs = vim.fn.sign_getplaced(bufnr, { group = "smartcomplete_propagate" })
  return signs[1] and #signs[1].signs > 0
end

--- Get all sign locations in buffer
---@param bufnr number Buffer number
---@return table List of line numbers with signs
function M.get_lines(bufnr)
  local signs = vim.fn.sign_getplaced(bufnr, { group = "smartcomplete_propagate" })
  if not signs[1] or not signs[1].signs then
    return {}
  end

  local lines = {}
  for _, sign in ipairs(signs[1].signs) do
    table.insert(lines, sign.lnum)
  end
  table.sort(lines)
  return lines
end

--- Remove sign at specific line
---@param bufnr number Buffer number
---@param line number Line number
function M.remove_at_line(bufnr, line)
  local signs = vim.fn.sign_getplaced(bufnr, { group = "smartcomplete_propagate", lnum = line })
  if signs[1] and signs[1].signs then
    for _, sign in ipairs(signs[1].signs) do
      vim.fn.sign_unplace("smartcomplete_propagate", { buffer = bufnr, id = sign.id })
    end
  end
end

return M
