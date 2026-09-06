return {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
        { "<leader>j", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file tree" },
    },
    config = function()
        require("nvim-tree").setup({
            git = {
                enable = true,
                ignore = false,
                -- timeout = 500,
            },
            view = {
                side = "right",
                width = 50,
            },
            filters = {
                dotfiles = false,
            },
        })
    end
}
