return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        opts = {
            custom_highlights = function(c)
                return { WinSeparator = { fg = c.surface2 } }
            end,
        },
    },
}
