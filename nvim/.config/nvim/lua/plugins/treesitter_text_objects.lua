return {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("nvim-treesitter-textobjects").setup({
            select = {
                lookahead = true,
                include_surrounding_whitespace = false,
            },
        })

        local select = function(query)
            return function()
                require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
            end
        end

        local maps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["aC"] = "@call.outer",
            ["iC"] = "@call.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
            ["ai"] = "@conditional.outer",
            ["ii"] = "@conditional.inner",
            ["al"] = "@loop.outer",
            ["il"] = "@loop.inner",
            ["a="] = "@assignment.outer",
            ["i="] = "@assignment.inner",
            ["l="] = "@assignment.lhs",
            ["r="] = "@assignment.rhs",
            ["ar"] = "@return.outer",
            ["ir"] = "@return.inner",
        }

        for lhs, query in pairs(maps) do
            vim.keymap.set({ "x", "o" }, lhs, select(query), { silent = true })
        end
    end,
}
