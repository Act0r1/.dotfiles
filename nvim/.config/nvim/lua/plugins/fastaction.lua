return {
	"Chaitanyabsprip/fastaction.nvim",
	---@type FastActionConfig
	opts = {},
	enabled = false,
	keys = {
		{
			"<leader>ca",
			function()
				require("fastaction").code_action()
			end,
			mode = { "n", "x" },
			desc = "Code actions",
		},
	},
}
