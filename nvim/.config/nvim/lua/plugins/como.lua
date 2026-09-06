return {
	dir = vim.fn.stdpath("config") .. "/pack/local/opt/como.nvim",
	cmd = "Como",
	config = function()
		require("como").setup({
			show_last_cmd = true,
			auto_scroll = true,
			preferred_win_pos = "bottom",
			prompt_on_error = false,
		})
	end,
	keys = {
		{ "<leader>mc", "<cmd>Como compile<cr>", desc = "Compile" },
		{ "<leader>mr", "<cmd>Como recompile<cr>", desc = "Recompile" },
		{ "<leader>mo", "<cmd>Como open<cr>", desc = "Open compile buffer" },
	},
}
