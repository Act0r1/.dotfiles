local M = {}

--- Create a debounced function that delays execution until after delay_ms
--- has elapsed since the last invocation
---@param fn function The function to debounce
---@param delay_ms number Delay in milliseconds
---@return function debounced The debounced function
function M.debounce(fn, delay_ms)
  local timer = nil

  return function(...)
    local args = { ... }

    -- Cancel existing timer
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end

    -- Create new timer
    timer = vim.uv.new_timer()
    timer:start(
      delay_ms,
      0,
      vim.schedule_wrap(function()
        timer:stop()
        timer:close()
        timer = nil
        fn(unpack(args))
      end)
    )
  end
end

--- Create a throttled function that executes at most once per delay_ms
---@param fn function The function to throttle
---@param delay_ms number Minimum time between executions in milliseconds
---@return function throttled The throttled function
function M.throttle(fn, delay_ms)
  local last_time = 0
  local timer = nil
  local pending_args = nil

  return function(...)
    local now = vim.uv.now()
    pending_args = { ... }

    if now - last_time >= delay_ms then
      last_time = now
      fn(unpack(pending_args))
      pending_args = nil
    elseif not timer then
      timer = vim.uv.new_timer()
      timer:start(
        delay_ms - (now - last_time),
        0,
        vim.schedule_wrap(function()
          timer:stop()
          timer:close()
          timer = nil
          last_time = vim.uv.now()
          if pending_args then
            fn(unpack(pending_args))
            pending_args = nil
          end
        end)
      )
    end
  end
end

return M
