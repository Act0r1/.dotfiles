return {
	"kylechui/nvim-surround",
	version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
	event = "VeryLazy",
	config = function()
		require("nvim-surround").setup({
			-- Configuration here, or leave empty to use defaults
		})
	end,
}

-- yss"    "This whole line is now wrapped in quotes"
-- yss(    (This whole line is now wrapped in parentheses)
-- yss`    `And now in backticks`
