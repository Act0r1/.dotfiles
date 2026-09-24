return {
    "fnune/recall.nvim",
    version = "*",
    enabled = false,
    keys = {
        {
            "<leader>mm",
            function()
                require("recall").toggle()
            end,
            desc = "Toggle recall mark",
        },
        {
            "<leader>mn",
            function()
                require("recall").goto_next()
            end,
            desc = "Next recall mark",
        },
        {
            "<leader>mp",
            function()
                require("recall").goto_prev()
            end,
            desc = "Previous recall mark",
        },
        {
            "<leader>mc",
            function()
                require("recall").clear()
            end,
            desc = "Clear recall marks",
        },
        { "<leader>ml", "<cmd>Telescope recall<cr>", desc = "List recall marks" },
    },
    config = function()
        require("recall").setup({})
    end,
}
