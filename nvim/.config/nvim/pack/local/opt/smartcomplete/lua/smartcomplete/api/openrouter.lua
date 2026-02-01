local http = require("smartcomplete.api.http")
local config = require("smartcomplete.config")

local M = {}

M.BASE_URL = "https://openrouter.ai/api/v1/chat/completions"
M.LOG_FILE = vim.fn.stdpath("cache") .. "/smartcomplete_api.log"

local function log(section, content)
  local f = io.open(M.LOG_FILE, "a")
  if f then
    f:write("\n" .. string.rep("=", 60) .. "\n")
    f:write(os.date("%Y-%m-%d %H:%M:%S") .. " [OPENROUTER] " .. section .. "\n")
    f:write(string.rep("-", 60) .. "\n")
    f:write(content .. "\n")
    f:close()
  end
end

function M.new()
  local self = {}

  function self:is_available()
    local cfg = config.get()
    return cfg.api_keys.openrouter ~= nil and cfg.api_keys.openrouter ~= ""
  end

  function self:complete(context, callback, on_error)
    local cfg = config.get()

    if not self:is_available() then
      if on_error then
        on_error("OpenRouter API key not configured")
      end
      return
    end

    local prompt = self:build_prompt(context)
    log("PROMPT SENT", prompt)

    local body = {
      model = cfg.models.openrouter,
      messages = {
        {
          role = "system",
          content = [[You are a code completion assistant. Output ONLY raw code to insert.

ABSOLUTE RULES:
- Output ONLY code that goes after <CURSOR>
- NEVER output Human:, Assistant:, markdown, or explanations
- Keep completions SHORT - one statement/line only

PATTERN MATCHING IS CRITICAL:
- Look at the EXACT code structure above the cursor
- Copy the EXACT same pattern, variable names, function calls
- Do NOT invent new approaches or change method calls
- If pattern uses string literals like "foo", use string literals
- If pattern uses .method(), use .method()
- When unsure what type/value to use, output NOTHING]],
        },
        {
          role = "user",
          content = prompt,
        },
      },
      max_tokens = cfg.request.max_tokens,
      temperature = cfg.request.temperature,
      -- stop sequences removed
    }

    http.post(M.BASE_URL, {
      headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. cfg.api_keys.openrouter,
        ["HTTP-Referer"] = "https://github.com/smartcomplete.nvim",
        ["X-Title"] = "smartcomplete.nvim",
      },
      body = body,
      timeout = cfg.request.timeout_ms,
      callback = function(response)
        if response.error then
          if on_error then
            on_error(response.error.message or "Unknown error")
          end
          return
        end

        local completion = ""
        if response.choices and response.choices[1] then
          completion = response.choices[1].message.content or ""
        end
        log("RAW RESPONSE", completion)

        -- Clean up the completion
        completion = self:clean_completion(completion)
        log("CLEANED (TO INSERT)", completion)

        callback(completion)
      end,
      on_error = on_error,
    })
  end

  function self:build_prompt(context)
    local suffix_preview = ""
    if context.suffix and context.suffix ~= "" then
      -- Include some suffix for context (first 20 lines max)
      local suffix_lines = vim.split(context.suffix, "\n", { plain = true })
      local preview_lines = {}
      for i = 1, math.min(20, #suffix_lines) do
        table.insert(preview_lines, suffix_lines[i])
      end
      suffix_preview = table.concat(preview_lines, "\n")
    end

    -- Get last few chars before cursor to help AI understand context
    local last_chars = ""
    if context.line_before_cursor and #context.line_before_cursor > 0 then
      last_chars = context.line_before_cursor:sub(-10) -- last 10 chars
    end

    return string.format(
      [[Complete this %s code. The cursor is IMMEDIATELY after: %s
Output ONLY what comes AFTER the cursor - do NOT repeat any characters that are already there.

%s<CURSOR>%s]],
      context.filetype,
      last_chars ~= "" and ('"' .. last_chars .. '"') or "(start of line)",
      context.prefix,
      suffix_preview
    )
  end

  function self:clean_completion(completion)
    -- Remove markdown code fences if present
    completion = completion:gsub("^```[%w]*\n?", "")
    completion = completion:gsub("\n?```$", "")

    -- Remove conversation format leaks (Human:, Assistant:, etc)
    -- Also catch training data artifacts
    local bad_patterns = {
      "Human:",
      "Assistant:",
      "<human>",
      "<assistant>",
      "End File",
      "# %w",  -- markdown headers
      "```",   -- code fences in middle
    }
    for _, pattern in ipairs(bad_patterns) do
      local pos = completion:find(pattern)
      if pos and pos > 1 then
        completion = completion:sub(1, pos - 1)
      elseif pos == 1 then
        -- If garbage at start, return empty
        return ""
      end
    end

    -- Truncate to single statement: stop at newline followed by non-whitespace
    -- This prevents suggesting multiple match arms, function bodies, etc.
    local lines = vim.split(completion, "\n", { plain = true })
    if #lines > 1 then
      -- Keep first line, check if second line starts a new statement
      local result = lines[1]
      for i = 2, #lines do
        local line = lines[i]
        -- If line starts with alphanumeric, quote, or is a new match arm => stop
        if line:match("^%s*[%w\"]") or line:match("^%s*_") then
          break
        end
        -- Otherwise keep it (closing braces, continuation, etc.)
        result = result .. "\n" .. line
      end
      completion = result
    end

    -- Remove trailing whitespace only (preserve leading newlines for comment completions)
    completion = completion:gsub("%s+$", "")

    return completion
  end

  function self:cancel()
    return http.cancel()
  end

  return self
end

return M
