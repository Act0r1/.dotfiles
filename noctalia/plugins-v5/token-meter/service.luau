--!nonstrict

local busy = false
local helper = `python3 "{noctalia.expandPath("~/.config/noctalia/token-meter/token-meter.py")}" snapshot`

local function publish(data)
  noctalia.state.set("usage", {
    updatedAt = data.updatedAt,
    periods = data.periods,
    discovered = data.discovered,
  })
end

function update()
  noctalia.setUpdateInterval(15000)
  if busy then return end

  busy = true
  local accepted = noctalia.runAsync(helper, function(result)
    busy = false
    if result.exitCode ~= 0 then return end

    local data = noctalia.json.decode(noctalia.string.trim(result.stdout))
    if data ~= nil then publish(data) end
  end)

  if not accepted then busy = false end
end
