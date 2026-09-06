return {
    "karb94/neoscroll.nvim",
    enabled = true,
    keys = {
        {
            "<C-u>",
            function()
                require("neoscroll").ctrl_u({ duration = 150 })
            end,
            mode = { "n", "v", "x" },
            desc = "Smooth scroll half-page up",
        },
        {
            "<C-d>",
            function()
                require("neoscroll").ctrl_d({ duration = 150 })
            end,
            mode = { "n", "v", "x" },
            desc = "Smooth scroll half-page down",
        },
        {
            "<C-b>",
            function()
                require("neoscroll").ctrl_b({ duration = 200 })
            end,
            mode = { "n", "v", "x" },
            desc = "Smooth scroll page up",
        },
        {
            "<C-f>",
            function()
                require("neoscroll").ctrl_f({ duration = 200 })
            end,
            mode = { "n", "v", "x" },
            desc = "Smooth scroll page down",
        },
        {
            "zt",
            function()
                require("neoscroll").zt({ half_win_duration = 100 })
            end,
            mode = { "n", "v", "x" },
            desc = "Smooth scroll cursor to top",
        },
        {
            "zz",
            function()
                require("neoscroll").zz({ half_win_duration = 100 })
            end,
            mode = { "n", "v", "x" },
            desc = "Smooth scroll cursor to center",
        },
        {
            "zb",
            function()
                require("neoscroll").zb({ half_win_duration = 100 })
            end,
            mode = { "n", "v", "x" },
            desc = "Smooth scroll cursor to bottom",
        },
    },
    config = function()
        require("neoscroll").setup({
            easing = "quadratic",
        })
    end,
}
