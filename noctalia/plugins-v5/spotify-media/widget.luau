--!nonstrict

local media = noctalia.state.get("media") or {
  available = false,
  title = "Nothing playing",
  artist = "Media",
  artPath = "",
  status = "Stopped",
}

local function render()
  local leading
  if media.artPath ~= nil and media.artPath ~= "" then
    leading = ui.image({ path = media.artPath, width = 18, height = 18, radius = 9, fit = "cover" })
  else
    leading = ui.glyph({ name = "music", size = 16, color = "primary" })
  end

  barWidget.render(ui.row({ gap = 7, align = "center" }, {
    leading,
    ui.label({
      text = media.title or "Nothing playing",
      maxWidth = 150,
      maxLines = 1,
      fontWeight = "medium",
    }),
  }))
  barWidget.setTooltip(`{media.title or "Nothing playing"} — {media.artist or "Media"}`)
  barWidget.setVisible(media.available == true)
end

noctalia.state.watch("media", function(value)
  media = value
  render()
end)

function update()
  noctalia.setUpdateInterval(1000)
  render()
end

function onClick()
  noctalia.togglePanel("yeager/spotify-media:player")
end
