return {
	"stevearc/oil.nvim",
	enabled = false,
	---@module "oil"
	---@type oil.SetupOpts
	opts = {
		keymaps = {
			["<Tab>"] = "actions.select",
			["<C-h>"] = false,
			["<C-l>"] = false,
		},
		view_options = {
			show_hidden = true,
		},
	},
	dependencies = { "nvim-mini/mini.icons" },
	keys = {
		{ "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
		{ "<leader>j", "<cmd>Oil<cr>", desc = "Open Oil file explorer" },
	},
	lazy = false,
}
