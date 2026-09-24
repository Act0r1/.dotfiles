-- Migrated from noctalia/noctalia-colors.conf

local primary = "rgb(7aa2f7)"
local surface = "rgb(1a1b26)"
local secondary = "rgb(bb9af7)"
local err = "rgb(f7768e)"
-- local tertiary = "rgb(9ece6a)"
-- local surface_lowest = "rgb(1c1d2a)"

hl.config({
  general = {
    col = {
      active_border = primary,
      inactive_border = surface,
    },
  },
  group = {
    col = {
      border_active = secondary,
      border_inactive = surface,
      border_locked_active = err,
      border_locked_inactive = surface,
    },
    groupbar = {
      col = {
        active = secondary,
        inactive = surface,
        locked_active = err,
        locked_inactive = surface,
      },
    },
  },
})
