-- Migrated from autostart.conf
-- General autostart, independent of the interactive shell.

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm-app -- polkit-kde-authentication-agent-1")
    hl.exec_cmd("wl-clip-persist --clipboard both")
    hl.exec_cmd("solaar --window=hide")
    hl.exec_cmd("brave", { workspace = "1 silent", fullscreen = true })
    hl.exec_cmd(
        "env QT_QPA_PLATFORMTHEME=xdgdesktopportal telegram-desktop",
        { workspace = "2 silent" }
    )
    hl.exec_cmd(
        [[sh -c 'app="$HOME/.local/share/chatgpt-frameless/ChatGPT"; [ -x "$app" ] && exec "$app" --ozone-platform=wayland']],
        { workspace = "3 silent", tile = true }
    )
    hl.exec_cmd("ghostty --gtk-single-instance=false", { workspace = "3 silent", tile = true })
    hl.exec_cmd("uwsm-app -- steam", { workspace = "4 silent" })
end)
