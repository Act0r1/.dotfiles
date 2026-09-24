return {
    "ibhagwan/fzf-lua",
    dependencies = { "echasnovski/mini.icons" },
    keys = {
        {
            "<leader>ff",
            function()
                require("fzf-lua").files()
            end,
            desc = "Fuzzy find files",
        },
        {
            "<leader>fw",
            function()
                require("fzf-lua").live_grep({ cwd = vim.fn.getcwd() })
            end,
            desc = "Live grep",
        },
        {
            "<leader>fb",
            function()
                require("fzf-lua").buffers()
            end,
            desc = "List buffers",
        },
        {
            "<leader>fi",
            function()
                require("fzf-lua").lsp_implementations()
            end,
            desc = "LSP implementations",
        },
        {
            "<leader>fr",
            function()
                require("fzf-lua").lsp_references()
            end,
            desc = "LSP references",
        },
        {
            "<leader>gd",
            function()
                require("fzf-lua").git_diff()
            end,
            desc = "Git diff",
        },
    },
    opts = {
        files = {
            hidden = true,
            no_ignore = true,
            fd_opts = [[--color=never --type f --hidden --exclude .git --exclude .venv --exclude venv]],
        },
        grep = {
            hidden = true,
            no_ignore = true,
            rg_opts = [[--column --line-number --no-heading --color=always --smart-case --hidden -g "!.git"]],
        },
    },
    config = function(_, opts)
        require("fzf-lua").setup(opts)
    end,
}
