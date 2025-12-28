-- return {
--     "ibhagwan/fzf-lua",
--     -- optional for icon support
--     dependencies = { "nvim-tree/nvim-web-devicons" },
--     -- or if using mini.icons/mini.nvim
--     -- dependencies = { "echasnovski/mini.icons" },
--     opts = {
--         files = {
--             hidden = true,
--             no_ignore = true
--         },
--         vim.keymap.set("n", "<leader>ff", function()
--             require("fzf-lua").files()
--         end, { desc = "Fuzzy find files" }),
--         vim.keymap.set("n", "<leader>fw", function()
--             require("fzf-lua").live_grep()
--         end, { desc = "Live grep" }),
--         vim.keymap.set("n", "<leader>fb", function()
--             require("fzf-lua").buffers()
--         end, { desc = "Live grep" }),
--         vim.keymap.set("n", "<leader>fi", function()
--             require("fzf-lua").lsp_implementations()
--         end, { desc = "Live grep" }),
--         vim.keymap.set("n", "<leader>fr", function()
--             require("fzf-lua").lsp_references()
--         end, { desc = "Live grep" }),
--         vim.keymap.set("n", "<leader>gd", function()
--             require("fzf-lua").git_diff()
--         end, { desc = "Live grep" }),
--     },
-- }
return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		files = {
			hidden = true,
			no_ignore = true,
			fd_opts = [[--color=never --type f --hidden --follow --exclude .git --exclude .venv --exclude venv]],
		},
	},
	config = function(_, opts)
		require("fzf-lua").setup(opts)

		-- keymaps
		vim.keymap.set("n", "<leader>ff", function()
			require("fzf-lua").files()
		end, { desc = "Fuzzy find files" })

		vim.keymap.set("n", "<leader>fw", function()
			require("fzf-lua").live_grep()
		end, { desc = "Live grep" })

		vim.keymap.set("n", "<leader>fb", function()
			require("fzf-lua").buffers()
		end, { desc = "List buffers" })

		vim.keymap.set("n", "<leader>fi", function()
			require("fzf-lua").lsp_implementations()
		end, { desc = "LSP implementations" })

		vim.keymap.set("n", "<leader>fr", function()
			require("fzf-lua").lsp_references()
		end, { desc = "LSP references" })

		vim.keymap.set("n", "<leader>gd", function()
			require("fzf-lua").git_diff()
		end, { desc = "Git diff" })
	end,
}
