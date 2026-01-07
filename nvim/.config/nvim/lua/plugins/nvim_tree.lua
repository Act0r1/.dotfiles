return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- Optional for file icons
    enable = false,
    config = function()
        require("nvim-tree").setup({
            git = {
                -- enable = true,
                ignore = false,
                -- timeout = 500,
            },
            filters = {
                dotfiles = false,
            },
        })
    end
}
