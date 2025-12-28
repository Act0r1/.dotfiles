return {
	"xiyaowong/transparent.nvim",
	config = function()
		-- Setup transparent.nvim
		require("transparent").setup({
			groups = {
				"Normal",
				"NormalNC",
				"Comment",
				"Constant",
				"Special",
				"Identifier",
				"Statement",
				"PreProc",
				"Type",
				"Underlined",
				"Todo",
				"String",
				"Function",
				"Conditional",
				"Repeat",
				"Operator",
				"Structure",
				"LineNr",
				"NonText",
				"SignColumn",
				"CursorLine",
				"CursorLineNr",
				"StatusLine",
				"StatusLineNC",
				"EndOfBuffer",
			},
			extra_groups = {}, -- Add any additional groups here
			exclude_groups = {}, -- Specify any groups you don't want to clear
			on_clear = function() end, -- Code to execute after clearing
		})

		-- Clear prefix for NvimTree
		require("transparent").clear_prefix("NvimTree")
	end,
}
