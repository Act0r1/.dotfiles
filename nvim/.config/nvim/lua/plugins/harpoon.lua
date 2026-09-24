return {
	"ThePrimeagen/harpoon",
	dependencies = { "nvim-lua/plenary.nvim" },
	keys = {
		{
			"<A-a>",
			function()
				require("harpoon.mark").add_file()
			end,
			desc = "Harpoon add file",
		},
		{
			"<A-w>",
			function()
				require("harpoon.ui").toggle_quick_menu()
			end,
			desc = "Harpoon quick menu",
		},
		{
			"<A-]>",
			function()
				require("harpoon.ui").nav_next()
			end,
			desc = "Harpoon next file",
		},
		{
			"<A-[>",
			function()
				require("harpoon.ui").nav_prev()
			end,
			desc = "Harpoon previous file",
		},
	},
	opts = {
		menu = {
			width = 100,
		},
	},
}
