--!nonstrict

local media = noctalia.state.get("media") or {
  available = false,
  title = "Nothing playing",
  artist = "Media",
  album = "",
  artPath = "",
  status = "Stopped",
  position = 0,
  length = 0,
  player = "",
  source = "Media",
  isSpotify = false,
}
local opened = false

local function formatTime(seconds)
  local value = math.max(0, math.floor(tonumber(seconds) or 0))
  return string.format("%d:%02d", math.floor(value / 60), value % 60)
end

local function render()
  local artwork
  if media.artPath ~= nil and media.artPath ~= "" then
    artwork = ui.image({
      path = media.artPath,
      width = 190,
      height = 190,
      radius = 16,
      fit = "cover",
    })
  else
    artwork = ui.box({
      width = 190,
      height = 190,
      radius = 16,
      fill = "surface_variant",
    }, {
      ui.glyph({ name = "music", size = 64, color = "primary" }),
    })
  end

  local length = tonumber(media.length) or 0
  local position = tonumber(media.position) or 0
  local playing = media.status == "Playing"

  panel.render(ui.column({ flexGrow = 1, gap = 14 }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.row({ align = "center", gap = 8, flexGrow = 1 }, {
        ui.glyph({ name = "headphones", size = 18, color = "primary" }),
        ui.label({ text = "Now Playing", fontSize = 16, fontWeight = "bold", color = "on_surface" }),
      }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = "Close", onClick = "closePanel" }),
    }),

    ui.row({ gap = 16, align = "stretch", flexGrow = 1 }, {
      artwork,
      ui.column({
        gap = 9,
        padding = 14,
        radius = 16,
        fill = "surface_variant/0.55",
        flexGrow = 1,
        justify = "center",
      }, {
        ui.label({
          text = media.title or "Nothing playing",
          fontSize = 20,
          fontWeight = "bold",
          color = "primary",
          maxLines = 2,
        }),
        ui.label({ text = media.artist or "Media", fontSize = 14, color = "on_surface", maxLines = 1 }),
        ui.label({ text = media.album or "", fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
        ui.spacer({ flexGrow = 1 }),
        ui.row({ align = "center", gap = 7 }, {
          ui.glyph({ name = media.isSpotify == true and "brand-spotify" or "broadcast", size = 15, color = "secondary" }),
          ui.label({ text = media.source or "Media", color = "secondary", fontWeight = "medium" }),
        }),
      }),
    }),

    ui.slider({
      min = 0,
      max = math.max(1, length),
      step = 1,
      value = math.min(position, math.max(1, length)),
      controlSize = "sm",
      enabled = media.available == true and length > 0,
      onDragEnd = "seekTrack",
    }),
    ui.row({ justify = "space_between", align = "center" }, {
      ui.label({ text = formatTime(position), color = "on_surface_variant", fontSize = 11 }),
      ui.label({ text = formatTime(length), color = "on_surface_variant", fontSize = 11 }),
    }),

    ui.row({ gap = 10, align = "center", justify = "center" }, {
      ui.button({ glyph = "player-track-prev", variant = "ghost", controlSize = "lg", tooltip = "Previous", enabled = media.available == true, onClick = "previousTrack" }),
      ui.button({ glyph = playing and "player-pause-filled" or "player-play-filled", variant = "primary", controlSize = "lg", tooltip = playing and "Pause" or "Play", enabled = media.available == true, onClick = "togglePlayback" }),
      ui.button({ glyph = "player-track-next", variant = "ghost", controlSize = "lg", tooltip = "Next", enabled = media.available == true, onClick = "nextTrack" }),
      ui.button({ glyph = "heart", text = "Like", variant = "secondary", controlSize = "lg", tooltip = "Like or unlike current Spotify track", enabled = media.available == true, visible = media.isSpotify == true, onClick = "likeTrack" }),
      ui.button({ glyph = "trash", text = "Trash", variant = "destructive", controlSize = "lg", tooltip = "Trash current Spotify track", enabled = media.available == true, visible = media.isSpotify == true, onClick = "trashTrack" }),
    }),
  }))
end

noctalia.state.watch("media", function(value)
  media = value
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

function previousTrack()
  runPlayerCommand("previous")
end

function togglePlayback()
  runPlayerCommand("play-pause")
end

function nextTrack()
  runPlayerCommand("next")
end

function seekTrack(value)
  local seconds = math.max(0, tonumber(value) or 0)
  local player = media.player or ""
  if string.match(player, "^[%w%._%-:]+$") == nil then return end
  noctalia.runAsync(`playerctl -p {player} position {seconds}`)
end

function trashTrack()
  if media.isSpotify ~= true then return end
  noctalia.runAsync([[hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "BackSpace", window = "class:Spotify" })']])
end

function likeTrack()
  if media.isSpotify ~= true then return end
  noctalia.runAsync([[hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "ALT SHIFT", key = "B", window = "class:Spotify" })']])
end

function runPlayerCommand(action)
  local player = media.player or ""
  if string.match(player, "^[%w%._%-:]+$") == nil then return end
  if string.match(action, "^[%a%-]+$") == nil then return end
  noctalia.runAsync(`playerctl -p {player} {action}`)
end
