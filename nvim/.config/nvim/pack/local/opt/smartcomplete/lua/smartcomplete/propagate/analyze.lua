local http = require("smartcomplete.api.http")
local config = require("smartcomplete.config")

local M = {}

M.LOG_FILE = vim.fn.stdpath("cache") .. "/smartcomplete_propagate.log"

local function log(section, content)
  local f = io.open(M.LOG_FILE, "a")
  if f then
    f:write("\n" .. string.rep("=", 60) .. "\n")
    f:write(os.date("%Y-%m-%d %H:%M:%S") .. " [PROPAGATE] " .. section .. "\n")
    f:write(string.rep("-", 60) .. "\n")
    f:write(content .. "\n")
    f:close()
  end
end

--- Analyze the file to find related locations needing updates
---@param file_content string Full file content
---@param added_text string The text that was added
---@param added_line number The line where text was added
---@param filetype string The file type
---@param callback function Called with list of {line = number, suggestion = string, preview = string}
---@param on_error function|nil Called on error
function M.find_related_locations(file_content, added_text, added_line, filetype, callback, on_error)
  local cfg = config.get()

  local prompt = string.format([[You are analyzing code to find related locations that need similar updates.

The user just added this code at line %d:
```
%s
```

Here is the full file:
```%s
%s
```

TASK: Find other locations in this file that likely need similar additions based on the pattern.
For example:
- If user added a new enum variant, find all match statements, From implementations, etc. that need the same variant
- If user added a new field to a struct, find constructors, builders, etc. that need it
- If user added a new function, find trait implementations that might need it

RESPOND WITH ONLY A JSON ARRAY. Each item must have:
- "line": the line number (1-indexed) where the suggestion should be inserted
- "suggestion": the exact code to insert at that location (just the new code, not existing code)
- "preview": a short 1-5 word description

If no related locations found, return empty array: []

IMPORTANT:
- Only include locations that NEED updates (don't include the line where user already added code)
- The suggestion should follow the exact pattern/style of surrounding code
- Line numbers must be accurate based on the file content

JSON response:]], added_line, added_text, filetype, file_content)

  log("PROMPT", prompt)

  -- Use the configured provider
  local provider_name = cfg.provider
  local api_key, base_url, headers, body

  if provider_name == "anthropic" then
    api_key = cfg.api_keys.anthropic or os.getenv("ANTHROPIC_API_KEY")
    base_url = "https://api.anthropic.com/v1/messages"
    headers = {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = api_key,
      ["anthropic-version"] = "2023-06-01",
    }
    body = {
      model = cfg.models.anthropic,
      max_tokens = 2048,
      messages = {
        { role = "user", content = prompt },
      },
    }
  else
    api_key = cfg.api_keys.openrouter or os.getenv("OPENROUTER_API_KEY")
    base_url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. (api_key or ""),
      ["HTTP-Referer"] = "https://github.com/smartcomplete.nvim",
      ["X-Title"] = "smartcomplete.nvim",
    }
    body = {
      model = cfg.models.openrouter,
      messages = {
        { role = "user", content = prompt },
      },
      max_tokens = 2048,
      temperature = 0.0,
    }
  end

  http.post(base_url, {
    headers = headers,
    body = body,
    timeout = 30000, -- 30 seconds for analysis
    callback = function(response)
      if response.error then
        log("ERROR", vim.inspect(response.error))
        if on_error then
          on_error(response.error.message or "Unknown error")
        end
        return
      end

      -- Extract response text
      local text = ""
      if provider_name == "anthropic" then
        if response.content and response.content[1] then
          text = response.content[1].text or ""
        end
      else
        if response.choices and response.choices[1] then
          text = response.choices[1].message.content or ""
        end
      end

      log("RAW RESPONSE", text)

      -- Parse JSON from response
      local locations = M.parse_response(text)
      log("PARSED LOCATIONS", vim.inspect(locations))

      callback(locations)
    end,
    on_error = function(err)
      log("HTTP ERROR", tostring(err))
      if on_error then
        on_error(err)
      end
    end,
  })
end

--- Parse the AI response to extract locations
---@param text string The response text
---@return table List of {line, suggestion, preview}
function M.parse_response(text)
  -- Try to find JSON array in the response
  local json_start = text:find("%[")
  local json_end = text:reverse():find("%]")

  if not json_start or not json_end then
    return {}
  end

  json_end = #text - json_end + 1
  local json_str = text:sub(json_start, json_end)

  -- Parse JSON
  local ok, parsed = pcall(vim.json.decode, json_str)
  if not ok or type(parsed) ~= "table" then
    return {}
  end

  -- Validate and clean up
  local locations = {}
  for _, item in ipairs(parsed) do
    if type(item) == "table" and type(item.line) == "number" and type(item.suggestion) == "string" then
      table.insert(locations, {
        line = item.line,
        suggestion = item.suggestion,
        preview = item.preview or "update needed",
      })
    end
  end

  -- Sort by line number
  table.sort(locations, function(a, b)
    return a.line < b.line
  end)

  return locations
end

return M
