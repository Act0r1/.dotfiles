-- return {
--     "mfussenegger/nvim-lint",
--     config = function()
--         require("lint").linters_by_ft = {
--             python = { "mypy" },
--             lua = { "luacheck" },
--         }
--     end,
-- }


return {
    "mfussenegger/nvim-lint",
    event = {
        "BufReadPre",
        "BufNewFile",
    },
    keys = {
        {
            "<leader>ls",
            function()
                require("lint").try_lint()
            end,
            desc = "Trigger linting for current file",
        },
    },
    config = function()
        local lint = require("lint")

        lint.linters_by_ft = {
            python = { "ruff" },
        }

        local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

        vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
            group = lint_augroup,
            callback = function()
                lint.try_lint()
            end,
        })
    end,
}
