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
		require("mason").setup({
			ui = { border = "rounded" },
		})
		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
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
			automatic_installation = true,
		})
		require("mason-tool-installer").setup({
			ensure_installed = {
				"stylua",
				"biome",
				"prettier",
			},
			run_on_start = true,
			start_delay = 0,
			debounce_hours = 0,
		})
	end,
}
