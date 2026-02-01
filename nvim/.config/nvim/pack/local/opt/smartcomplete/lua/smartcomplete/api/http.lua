local M = {}

-- State for tracking in-flight requests
M._current_job = nil

--- Make an async POST request
---@param url string The URL to POST to
---@param opts table Options: headers, body, callback, on_error, timeout
function M.post(url, opts)
  local headers = opts.headers or {}
  local body = opts.body
  local callback = opts.callback
  local on_error = opts.on_error
  local timeout = opts.timeout or 10000

  -- Cancel any existing request
  M.cancel()

  -- Build curl arguments
  local args = {
    "curl",
    "-s",
    "-X",
    "POST",
    "-m",
    tostring(math.floor(timeout / 1000)),
  }

  -- Add headers
  for key, value in pairs(headers) do
    table.insert(args, "-H")
    table.insert(args, string.format("%s: %s", key, value))
  end

  -- Add body
  if body then
    table.insert(args, "-d")
    table.insert(args, vim.fn.json_encode(body))
  end

  table.insert(args, url)

  -- Execute async request
  M._current_job = vim.system(args, {
    text = true,
  }, function(result)
    vim.schedule(function()
      M._current_job = nil

      if result.code ~= 0 then
        local err_msg = "Request failed with code: " .. result.code
        if result.stderr and result.stderr ~= "" then
          err_msg = err_msg .. " stderr: " .. result.stderr
        end
        if on_error then
          on_error(err_msg)
        end
        return
      end

      if not result.stdout or result.stdout == "" then
        if on_error then
          on_error("Empty response from server")
        end
        return
      end

      local ok, decoded = pcall(vim.fn.json_decode, result.stdout)
      if not ok then
        if on_error then
          on_error("Failed to parse response: " .. result.stdout:sub(1, 200))
        end
        return
      end

      -- Check for API error in response
      if decoded.error then
        local api_err = decoded.error.message or vim.fn.json_encode(decoded.error)
        if on_error then
          on_error(api_err)
        end
        return
      end

      if callback then
        callback(decoded)
      end
    end)
  end)

  return M._current_job
end

--- Cancel any in-flight request
---@return boolean Whether a request was cancelled
function M.cancel()
  if M._current_job then
    pcall(function()
      M._current_job:kill(9) -- SIGKILL
    end)
    M._current_job = nil
    return true
  end
  return false
end

--- Check if a request is pending
---@return boolean
function M.is_pending()
  return M._current_job ~= nil
end

return M
