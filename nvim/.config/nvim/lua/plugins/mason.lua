return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"neovim/nvim-lspconfig",
	},
	build = ":MasonUpdate", -- Automatically update Mason when running Lazy sync
	opts = {
		ensure_installed = {
			"lua-ls", --[[ "pyright" ]]
			"tailwindcss",
			"basedpyright",
			"clangd",
			"ts_ls",
			"gopls",
			"postgres_lsp",
		}, -- Example tools
		ui = {
			border = "rounded", -- Optional: adds rounded borders to Mason's UI
		},
	},
	event = "VeryLazy", -- Load Mason lazily
	-- require("lspconfig").lua_ls.setup({}),
}
