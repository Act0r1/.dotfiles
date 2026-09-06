return {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    enabled = false,

    keys = {
        {
            "<leader>gg",
            "<cmd>Neogit<cr>",
            desc = "Git status (Neogit)",
        },
    },

    dependencies = {
        "ibhagwan/fzf-lua",
        "esmuellert/codediff.nvim",
    },

    opts = {
        integrations = {
            telescope = false,
            fzf_lua = true,
            mini_pick = false,
            snacks = false,

            diffview = false,
            codediff = true,
        },

        diff_viewer = "codediff",
    },
}
