return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("nvim-treesitter.configs").setup({
			indent = {
				enable = true,
			},
			highlight = {
				enable = true,
			},
			textobjects = {
				select = {
					enable = true,

					-- Automatically jump forward to textobj, similar to targets.vim
					lookahead = true,

					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",

						["ca"] = "@call.outer",
						["ci"] = "@call.inner",

						["ac"] = "@class.outer",
						["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
						["as"] = { query = "@local.scope", query_group = "locals", desc = "Select language scope" },

						["l="] = "@assignment.lhs",
						["a="] = "@assignment.outer",
						["i="] = "@assignment.inner",
						["r="] = "@assignment.rhs",

						["aa"] = "@parameter.outer",
						["ai"] = "@parameter.outer",

						["id"] = "@conditional.inner",
						["ia"] = "@conditional.outer",

						["al"] = "@loop.outer",
						["il"] = "@loop.inner",

						["ar"] = "@return.outer",
						["ir"] = "@return.inner",
					},
					-- You can choose the select mode (default is charwise 'v')
					--
					-- Can also be a function which gets passed a table with the keys
					-- * query_string: eg '@function.inner'
					-- * method: eg 'v' or 'o'
					-- and should return the mode ('v', 'V', or '<c-v>') or a table
					-- mapping query_strings to modes.
					-- selection_modes = {
					--     ["@parameter.outer"] = "v", -- charwise
					--     ["@function.outer"] = "V",  -- linewise
					--     ["@class.outer"] = "<c-v>", -- blockwise
					-- },
					-- If you set this to `true` (default is `false`) then any textobject is
					-- extended to include preceding or succeeding whitespace. Succeeding
					-- whitespace has priority in order to act similarly to eg the built-in
					-- `ap`.
					--
					-- Can also be a function which gets passed a table with the keys
					-- * query_string: eg '@function.inner'
					-- * selection_mode: eg 'v'
					-- and should return true or false
					include_surrounding_whitespace = false,
				},
			},
		})
	end,
}
