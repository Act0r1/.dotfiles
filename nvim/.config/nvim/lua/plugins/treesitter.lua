return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local parsers = {
            "python",
            "go",
            "zig",
            "rust",
            "c",
            "json",
            "javascript",
            "typescript",
            "tsx",
            "yaml",
            "html",
            "css",
            "prisma",
            "markdown",
            "markdown_inline",
            "svelte",
            "graphql",
            "bash",
            "lua",
            "vim",
            "dockerfile",
            "gitignore",
            "query",
            "vimdoc",
        }

        require("nvim-treesitter").install(parsers)

        vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
                local ft = vim.bo[args.buf].filetype
                local lang = vim.treesitter.language.get_lang(ft)
                if lang and vim.treesitter.language.add(lang) then
                    pcall(vim.treesitter.start, args.buf, lang)
                end
            end,
        })
    end,
}
