-- Migrated from noctalia/autostart.conf

local version = "v4"
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state = io.open(state_home .. "/noctalia-shell-version", "r")

if state then
  version = state:read("*l") or version
  state:close()
end

hl.on("hyprland.start", function()
  if version == "v5" then
    hl.exec_cmd("noctalia -d")
  elseif version == "rashell" then
    local home = os.getenv("HOME")
    hl.exec_cmd(home .. "/.local/opt/rashell-runtime/quickshell -c rashell -d")
  else
    hl.exec_cmd("qs -c noctalia-shell -d")
  end
end)
