return {
	"Vonr/align.nvim",
	branch = "v2",
	lazy = true,
	keys = {
		{
			"gaa",
			function()
				require("align").align_to_char({ length = 1 })
			end,
			mode = "x",
			desc = "Align to one character",
		},
		{
			"gad",
			function()
				require("align").align_to_char({ preview = true, length = 2 })
			end,
			mode = "x",
			desc = "Align to two characters",
		},
		{
			"gaw",
			function()
				require("align").align_to_string({ preview = true, regex = false })
			end,
			mode = "x",
			desc = "Align to string",
		},
		{
			"gar",
			function()
				require("align").align_to_string({ preview = true, regex = true })
			end,
			mode = "x",
			desc = "Align to Vim regex",
		},
		{
			"gaw",
			function()
				local align = require("align")
				align.operator(align.align_to_string, { regex = false, preview = true })
			end,
			desc = "Align operator to string",
		},
		{
			"gaa",
			function()
				local align = require("align")
				align.operator(align.align_to_char)
			end,
			desc = "Align operator to character",
		},
	},
}
