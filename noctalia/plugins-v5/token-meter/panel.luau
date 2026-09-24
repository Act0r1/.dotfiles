--!nonstrict

local data = noctalia.state.get("usage") or { periods = { today = {} } }
local opened = false
local refreshing = false

local function compact(value)
  local number = tonumber(value) or 0
  if number >= 1000000000 then return string.format("%.2fB", number / 1000000000) end
  if number >= 1000000 then return string.format("%.2fM", number / 1000000) end
  if number >= 1000 then return string.format("%.1fK", number / 1000) end
  return string.format("%d", math.floor(number + 0.5))
end

local function money(value)
  local number = tonumber(value) or 0
  if number > 0 and number < 0.01 then return string.format("$%.4f", number) end
  return string.format("$%.2f", number)
end

local function metric(label, value, glyph, color)
  return ui.column({ gap = 5, padding = 13, radius = 15, fill = "surface_variant/0.62", flexGrow = 1 }, {
    ui.row({ align = "center", justify = "space_between" }, {
      ui.label({ text = label, fontSize = 10, fontWeight = "semibold", color = "on_surface_variant" }),
      ui.glyph({ name = glyph, size = 16, color = color }),
    }),
    ui.label({ text = value, fontSize = 22, fontWeight = "bold", color = "on_surface" }),
  })
end

local function render()
  local today = (data.periods and data.periods.today) or {}
  local models = today.models or {}
  local modelRows = {}

  for index = 1, math.min(5, #models) do
    local model = models[index]
    local rowKey = `{model.name or "unknown"}:{model.source or "unknown"}:{model.provider or "unknown"}`
    local iconPath = noctalia.expandPath(`~/.config/noctalia/token-meter/icons/{model.icon or "ai"}.svg`)
    table.insert(modelRows, ui.row({ key = rowKey, gap = 10, align = "center", paddingV = 6 }, {
      ui.box({ width = 31, height = 31, radius = 10, fill = "surface", border = "outline", borderWidth = 1 }, {
        ui.image({ path = iconPath, width = 19, height = 19, fit = "contain" }),
      }),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = `{model.name or "Unknown"} · {model.source or "Unknown source"}`, fontWeight = "semibold", color = "on_surface", maxLines = 1 }),
        ui.label({ text = model.provider or "Unknown provider", fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
      }),
      ui.label({ text = compact(model.totalTokens), fontWeight = "bold", color = "on_surface", width = 76, textAlign = "right" }),
      ui.label({ text = string.format("%d%% reused", math.floor((tonumber(model.cacheRate) or 0) * 100 + 0.5)), fontWeight = "semibold", color = "secondary", width = 62, textAlign = "right" }),
      ui.label({ text = money(model.cost), fontWeight = "semibold", color = "primary", width = 70, textAlign = "right" }),
    }))
  end

  if #modelRows == 0 then
    table.insert(modelRows, ui.column({ align = "center", justify = "center", flexGrow = 1, gap = 7 }, {
      ui.glyph({ name = "chart-dots", size = 24, color = "on_surface_variant" }),
      ui.label({ text = "No token activity in the last 24 hours", color = "on_surface_variant", textAlign = "center", maxWidth = 360 }),
    }))
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.box({ width = 42, height = 42, radius = 13, fill = "primary" }, {
        ui.glyph({ name = "brain", size = 22, color = "on_primary" }),
      }),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = "Token Meter", fontSize = 21, fontWeight = "bold", color = "on_surface" }),
        ui.label({ text = "Pi + Codex + Claude Code · live local analytics", fontSize = 11, color = "on_surface_variant" }),
      }),
      ui.button({ glyph = refreshing and "loader-2" or "refresh", text = refreshing and "Updating…" or "Refresh", variant = "outline", controlSize = "sm", enabled = not refreshing, onClick = "refreshStats" }),
      ui.button({ glyph = "external-link", text = "Open dashboard", variant = "primary", controlSize = "sm", onClick = "openDashboard" }),
      ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", tooltip = "Close", onClick = "closePanel" }),
    }),

    ui.row({ gap = 10 }, {
      metric("PROCESSED 24H", compact(today.totalTokens), "sparkles", "primary"),
      metric("CACHE REUSE", string.format("%d%%", math.floor((tonumber(today.cacheRate) or 0) * 100 + 0.5)), "database", "secondary"),
      metric("REQUESTS", compact(today.requests), "activity", "tertiary"),
      metric("API COST", string.format("$%.2f", tonumber(today.cost) or 0), "currency-dollar", "primary"),
    }),

    ui.column({ gap = 8, padding = 13, radius = 15, fill = "surface_variant/0.62" }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.label({ text = "Token composition", fontWeight = "semibold", color = "on_surface" }),
        ui.label({ text = `Input {compact(today.input)}  ·  Cache {compact(today.cacheRead)}  ·  Write {compact(today.cacheWrite)}  ·  Output {compact(today.output)}`, fontSize = 10, color = "on_surface_variant" }),
      }),
      ui.row({ gap = 3, height = 10 }, {
        ui.box({ fill = "primary", radius = 5, flexGrow = math.max(0, tonumber(today.input) or 0), height = 10 }),
        ui.box({ fill = "secondary", radius = 5, flexGrow = math.max(0, tonumber(today.cacheRead) or 0), height = 10 }),
        ui.box({ fill = "tertiary", radius = 5, flexGrow = math.max(0, tonumber(today.cacheWrite) or 0), height = 10 }),
        ui.box({ fill = "on_surface_variant", radius = 5, flexGrow = math.max(0, tonumber(today.output) or 0), height = 10 }),
      }),
    }),

    ui.column({ gap = 7, padding = 13, radius = 15, fill = "surface_variant/0.62", flexGrow = 1 }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.label({ text = "Models · last 24 hours", fontSize = 16, fontWeight = "bold", color = "on_surface" }),
        ui.label({ text = "MODEL  ·  TOKENS  ·  CACHE REUSE  ·  API COST", fontSize = 10, color = "on_surface_variant" }),
      }),
      ui.separator({ color = "outline", spacing = 2 }),
      ui.column({ gap = 2, flexGrow = 1 }, modelRows),
    }),
  }))
end

noctalia.state.watch("usage", function(value)
  data = value
  if opened then render() end
end)

function onOpen(_context)
  opened = true
  render()
end

function onClose()
  opened = false
end

function closePanel()
  panel.close()
end

function refreshStats()
  if refreshing then return end
  refreshing = true
  render()
  local accepted = noctalia.runAsync(`python3 "{noctalia.expandPath("~/.config/noctalia/token-meter/token-meter.py")}" snapshot`, function(result)
    refreshing = false
    if result.exitCode == 0 then
      local refreshed = noctalia.json.decode(noctalia.string.trim(result.stdout))
      if refreshed ~= nil then
        data = refreshed
        noctalia.state.set("usage", refreshed)
      end
    end
    render()
  end)
  if not accepted then
    refreshing = false
    render()
  end
end

function openDashboard()
  noctalia.runAsync(`python3 "{noctalia.expandPath("~/.config/noctalia/token-meter/token-meter.py")}" open`)
end
