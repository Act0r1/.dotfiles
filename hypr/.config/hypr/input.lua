-- Migrated from input.conf

hl.config({
  input = {
    kb_layout = "us,ru",
    kb_options = "grp:caps_toggle",
    repeat_rate = 70,
    repeat_delay = 250,
    numlock_by_default = true,
    touchpad = {
      natural_scroll = true,
      scroll_factor = 0.4,
    },
  },
})

-- Scroll nicely in ghostty.
hl.window_rule({
  match = { class = "com.mitchellh.ghostty" },
  scroll_touchpad = 0.2,
})

hl.window_rule({
  match = { class = "com.mitchellh.ghostty" },
  scroll_mouse = 0.1,
})

-- Touchpad gestures remain defined in hyprland.lua.
