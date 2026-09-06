return {
    -- lazy.nvim

    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
        image = {
            -- your image configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
        },
        input = {
            enabled = true,
            win = {
                keys = {
                    i_ctrl_a = { "<c-a>", "<Home>", mode = "i" },
                    i_ctrl_e = { "<c-e>", "<End>", mode = "i" },
                    i_ctrl_f = { "<c-f>", "<Right>", mode = "i" },
                    i_ctrl_b = { "<c-b>", "<Left>", mode = "i" },
                },
            },
        },
        animate = { enabled = true },
    },
}
