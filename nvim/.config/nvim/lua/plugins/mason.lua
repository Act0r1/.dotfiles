return {
    "williamboman/mason.nvim",
    dependencies = {
        "williamboman/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        "neovim/nvim-lspconfig",
    },
    build = ":MasonUpdate",
    event = "VeryLazy",
    config = function()
        local nix_managed = vim.env.NVIM_NIX_MANAGED == "1"
        require("mason").setup({
            PATH = nix_managed and "skip" or "prepend",
            ui = { border = "rounded" },
        })
        require("mason-lspconfig").setup({
            ensure_installed = nix_managed and {} or {
                "basedpyright",
                "ruff",
                "gopls",
                "clangd",
                "postgres_lsp",
                "taplo",
                "marksman",
                "terraformls",
                "ts_ls",
                "tailwindcss",
            },
            automatic_installation = not nix_managed,
        })
        require("mason-tool-installer").setup({
            ensure_installed = nix_managed and {} or {
                "biome",
                "prettier",
            },
            run_on_start = not nix_managed,
            start_delay = 0,
            debounce_hours = 0,
        })
    end,
}
