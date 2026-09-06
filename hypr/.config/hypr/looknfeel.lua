-- Migrated from looknfeel.conf

hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,
  },
  misc = {
    focus_on_activate = false,
  },
  decoration = {
    -- rounding = 8,
  },
  dwindle = {
    -- single_window_aspect_ratio = "1 1",
  },
})

-- Keep Ghostty borderless like the rest of the applications.
hl.window_rule({
  match = { class = "com.mitchellh.ghostty" },
  border_size = 0,
})

hl.window_rule({
  match = { class = "com.mitchellh.ghostty" },
  border_color = { colors = { "rgba(d6aaffee)", "rgba(9ab6ffee)" }, angle = 45 },
})

hl.window_rule({
  name = "borderless-x-pwa",
  match = { class = "^brave-lodlkdfmihgonocnmddehnfgiljnadcf-Default$" },
  fullscreen_state = "0 2",
})

-- Hide Chromium "is sharing your screen" notification.
hl.window_rule({
  match = { title = [[^(.*is sharing (your screen|a window|a tab)\.)$]] },
  workspace = "special:hidden silent",
})
