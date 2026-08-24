local version = "v4"
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state = io.open(state_home .. "/noctalia-shell-version", "r")

if state then
    version = state:read("*l") or version
    state:close()
end

if version == "v5" then
    require("noctalia.binds_v5")
elseif version == "rashell" then
    require("noctalia.binds_rashell")
else
    require("noctalia.binds_v4")
end
