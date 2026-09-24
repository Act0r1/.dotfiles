local function select(query)
    return function()
        require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
    end
end

return {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPre", "BufNewFile" },
    keys = {
        { "af", select("@function.outer"), mode = { "x", "o" }, desc = "Outer function" },
        { "if", select("@function.inner"), mode = { "x", "o" }, desc = "Inner function" },
        { "ac", select("@class.outer"), mode = { "x", "o" }, desc = "Outer class" },
        { "ic", select("@class.inner"), mode = { "x", "o" }, desc = "Inner class" },
        { "aC", select("@call.outer"), mode = { "x", "o" }, desc = "Outer call" },
        { "iC", select("@call.inner"), mode = { "x", "o" }, desc = "Inner call" },
        { "aa", select("@parameter.outer"), mode = { "x", "o" }, desc = "Outer parameter" },
        { "ia", select("@parameter.inner"), mode = { "x", "o" }, desc = "Inner parameter" },
        { "ai", select("@conditional.outer"), mode = { "x", "o" }, desc = "Outer conditional" },
        { "ii", select("@conditional.inner"), mode = { "x", "o" }, desc = "Inner conditional" },
        { "al", select("@loop.outer"), mode = { "x", "o" }, desc = "Outer loop" },
        { "il", select("@loop.inner"), mode = { "x", "o" }, desc = "Inner loop" },
        { "a=", select("@assignment.outer"), mode = { "x", "o" }, desc = "Outer assignment" },
        { "i=", select("@assignment.inner"), mode = { "x", "o" }, desc = "Inner assignment" },
        { "l=", select("@assignment.lhs"), mode = { "x", "o" }, desc = "Assignment left-hand side" },
        { "r=", select("@assignment.rhs"), mode = { "x", "o" }, desc = "Assignment right-hand side" },
        { "ar", select("@return.outer"), mode = { "x", "o" }, desc = "Outer return" },
        { "ir", select("@return.inner"), mode = { "x", "o" }, desc = "Inner return" },
    },
    config = function()
        require("nvim-treesitter-textobjects").setup({
            select = {
                lookahead = true,
                include_surrounding_whitespace = false,
            },
        })
    end,
}
