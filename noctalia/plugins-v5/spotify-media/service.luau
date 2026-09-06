--!nonstrict

local busy = false
local artUrl = ""
local artPath = ""
local artSlot = 0
local helper = `"{noctalia.pluginDir()}/media-status"`

local function publish(media)
  media.artPath = artPath
  noctalia.state.set("media", media)
end

local function updateArtwork(media)
  if media.artUrl == nil or media.artUrl == "" then
    artUrl = ""
    artPath = ""
    publish(media)
    return
  end

  if media.artUrl == artUrl then
    publish(media)
    return
  end

  artUrl = media.artUrl
  artSlot = 1 - artSlot
  local requestedUrl = artUrl
  local target = `{noctalia.pluginDataDir()}/artwork-{artSlot}.jpg`

  noctalia.download(requestedUrl, target, function(ok)
    if ok and artUrl == requestedUrl then
      artPath = target
      media.artPath = target
      publish(media)
    end
  end)

  publish(media)
end

function update()
  noctalia.setUpdateInterval(1000)
  if busy then return end

  busy = true
  local accepted = noctalia.runAsync(helper, function(result)
    busy = false
    if result.exitCode ~= 0 then
      publish({
        available = false,
        title = "Nothing playing",
        artist = "Media",
        album = "",
        artUrl = "",
        status = "Stopped",
        position = 0,
        length = 0,
        player = "",
        source = "Media",
        isSpotify = false,
      })
      return
    end

    local media = noctalia.json.decode(noctalia.string.trim(result.stdout))
    if media == nil then return end
    updateArtwork(media)
  end)

  if not accepted then busy = false end
end
