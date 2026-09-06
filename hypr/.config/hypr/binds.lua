-- Migrated from binds.conf
-- Universal Hyprland binds, independent of the interactive shell.

local function dispatch_shell(raw)
    return hl.dsp.exec_cmd("hyprctl dispatch " .. raw)
end

local function resizeactive(arg)
    return dispatch_shell("resizeactive " .. string.format("%q", arg))
end

----------------
---- Terminal ----
----------------
-- hyprland.lua
hl.bind("SUPER + g", function()
    hl.plugin.scrolloverview.overview("toggle")
end)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty"))

-------------------------
---- Window Management ----
-------------------------

hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + W", hl.dsp.group.toggle())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())

------------------------
---- Focus Navigation ----
------------------------

hl.bind("ALT + Tab", hl.dsp.focus({ workspace = "previous" }))
hl.bind("SUPER + left", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "d" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))

-----------------------
---- Window Movement ----
-----------------------

hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "d" }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

------------------------
---- Monitor Navigation ----
------------------------

hl.bind("SUPER + CTRL + left", hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + CTRL + right", hl.dsp.focus({ monitor = "r" }))
hl.bind("SUPER + CTRL + H", hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + CTRL + J", hl.dsp.focus({ monitor = "d" }))
hl.bind("SUPER + CTRL + K", hl.dsp.focus({ monitor = "u" }))
hl.bind("SUPER + CTRL + L", hl.dsp.focus({ monitor = "r" }))

-----------------------
---- Move to Monitor ----
-----------------------

hl.bind("SUPER + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "d" }))
hl.bind("SUPER + SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "u" }))
hl.bind("SUPER + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "r" }))
hl.bind("SUPER + SHIFT + CTRL + H", hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + SHIFT + CTRL + J", hl.dsp.window.move({ monitor = "d" }))
hl.bind("SUPER + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "u" }))
hl.bind("SUPER + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "r" }))

--------------------------
---- Workspace Navigation ----
--------------------------

hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + U", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + I", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + I", hl.dsp.window.move({ workspace = "e-1" }))

-----------------------
---- Move Workspaces ----
-----------------------

hl.bind("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("SUPER + SHIFT + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + SHIFT + I", hl.dsp.window.move({ workspace = "e-1" }))

-----------------------------
---- Mouse Wheel Navigation ----
-----------------------------

hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + mouse_down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + mouse_up", hl.dsp.window.move({ workspace = "e-1" }))

---------------------------
---- Numbered Workspaces ----
---------------------------

for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-----------------------
---- Column Management ----
-----------------------

hl.bind("SUPER + bracketleft", hl.dsp.layout("preselect l"))
hl.bind("SUPER + bracketright", hl.dsp.layout("preselect r"))

-----------------------
---- Sizing & Layout ----
-----------------------

hl.bind("SUPER + R", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + CTRL + F", resizeactive("exact 100%"))

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.pin({ action = "toggle" }), { description = "Pin / unpin floating window" })
hl.bind("SUPER + SHIFT + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

hl.bind(
    "SUPER + code:20",
    hl.dsp.window.resize({ x = -100, y = 0, relative = true }),
    { description = "Expand window left" }
)
hl.bind(
    "SUPER + code:21",
    hl.dsp.window.resize({ x = 100, y = 0, relative = true }),
    { description = "Shrink window left" }
)

hl.bind("SUPER + minus", resizeactive("-10% 0"), { repeating = true })
hl.bind("SUPER + equal", resizeactive("10% 0"), { repeating = true })
hl.bind("SUPER + SHIFT + minus", resizeactive("0 -10%"), { repeating = true })
hl.bind("SUPER + SHIFT + equal", resizeactive("0 10%"), { repeating = true })

------------
---- Audio ----
------------

hl.bind("F10", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Mute" })
hl.bind(
    "F11",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"),
    { locked = true, repeating = true, description = "Volume down" }
)
hl.bind(
    "F12",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%+ -l 1.0"),
    { locked = true, repeating = true, description = "Volume up" }
)
hl.bind("F5", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

------------
---- Media ----
------------

hl.bind("F7", hl.dsp.exec_cmd("playerctl -p playerctld previous"), { locked = true, description = "Previous track" })
hl.bind("F8", hl.dsp.exec_cmd("playerctl -p playerctld play-pause"), { locked = true, description = "Play/Pause" })
hl.bind("F9", hl.dsp.exec_cmd("playerctl -p playerctld next"), { locked = true, description = "Next track" })

-------------------
---- Screenshots ----
-------------------

hl.bind(
    "F3",
    hl.dsp.exec_cmd("$HOME/.local/bin/screenshot smart clipboard"),
    { description = "Screenshot to clipboard" }
)
hl.bind("SHIFT + F3", hl.dsp.exec_cmd("$HOME/.local/bin/screenshot"), { description = "Screenshot with editor" })

----------------------
---- Screen Recording ----
----------------------

hl.bind("F4", hl.dsp.exec_cmd("$HOME/.local/bin/screenrecord"), { description = "Screen recording toggle" })
hl.bind("SUPER + O", hl.dsp.exec_cmd("handy --toggle-transcription"))

----------------------
---- Noctalia Version ----
----------------------

hl.bind(
    "CTRL + SHIFT + bracketright",
    hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/toggle-noctalia-version"),
    { description = "Toggle Noctalia v4/v5" }
)

----------------------
---- Rashell ----
----------------------

hl.bind(
    "SUPER + SHIFT + W",
    hl.dsp.exec_cmd("$HOME/.local/opt/rashell-runtime/quickshell -c rashell ipc call rashell wallpaperPickerToggle"),
    { description = "Toggle wallpaper picker" }
)

hl.bind(
    "SUPER + SHIFT + A",
    hl.dsp.exec_cmd("$HOME/.local/opt/rashell-runtime/quickshell -c rashell ipc call rashell appearanceToggle"),
    { description = "Toggle appearance picker" }
)
