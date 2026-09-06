return {
	"Vonr/align.nvim",
	branch = "v2",
	lazy = true,
	keys = {
		{
			"aa",
			function()
				require("align").align_to_char({ length = 1 })
			end,
			mode = "v",
			desc = "Align to one character",
		},
		{
			"ad",
			function()
				require("align").align_to_char({ preview = true, length = 2 })
			end,
			mode = "x",
			desc = "Align to two characters",
		},
		{
			"aw",
			function()
				require("align").align_to_string({ preview = true, regex = false })
			end,
			mode = "x",
			desc = "Align to string",
		},
		{
			"ar",
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
