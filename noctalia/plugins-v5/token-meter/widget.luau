--!nonstrict

local data = noctalia.state.get("usage") or { periods = { today = {} } }

local function compact(value)
  local number = tonumber(value) or 0
  if number >= 1000000000 then return string.format("%.1fB", number / 1000000000) end
  if number >= 1000000 then return string.format("%.1fM", number / 1000000) end
  if number >= 1000 then return string.format("%.1fK", number / 1000) end
  return string.format("%d", math.floor(number + 0.5))
end

local function render()
  local today = (data.periods and data.periods.today) or {}
  local container = barWidget.isVertical() and ui.column or ui.row

  barWidget.render(container({ gap = 7, align = "center" }, {
    ui.glyph({ name = "brain", size = 17, color = "primary" }),
    ui.label({ text = compact(today.totalTokens), fontWeight = "bold" }),
    ui.label({ text = string.format("C %d%%", math.floor((tonumber(today.cacheRate) or 0) * 100 + 0.5)), fontSize = 10, fontWeight = "semibold", color = "secondary" }),
  }))
  barWidget.setTooltip(`Last 24h: {compact(today.totalTokens)} processed tokens · {math.floor((tonumber(today.cacheRate) or 0) * 100 + 0.5)}% context reused`)
  barWidget.setVisible(true)
end

noctalia.state.watch("usage", function(value)
  data = value
  render()
end)

function update()
  noctalia.setUpdateInterval(15000)
  render()
end

function onClick()
  noctalia.togglePanel("yeager/token-meter:dashboard")
end

function onRightClick()
  noctalia.runAsync(`python3 "{noctalia.expandPath("~/.config/noctalia/token-meter/token-meter.py")}" open`)
end
