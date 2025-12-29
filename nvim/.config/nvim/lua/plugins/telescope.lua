return {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local builtin = require("telescope.builtin")
        -- vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
        -- vim.keymap.set("n", "<leader>fw", builtin.live_grep, {})
        -- vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
        -- vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
        -- vim.keymap.set("n", "<leader>fl", builtin.lsp_document_symbols, {})
        -- vim.keymap.set("n", "<leader>fi", builtin.lsp_implementations, {})
        -- vim.keymap.set("n", "<leader>fr", builtin.lsp_references, {})

        local telescope = require("telescope")

        telescope.setup({
            pickers = {
                find_files = {
                    hidden = true,
                    no_ignore = true,
                },
                grep_string = {
                    additional_args = { "--hidden" },
                },
                live_grep = {
                    additional_args = { "--hidden" },
                },
            },
            defaults = {
                vimgrep_arguments = {
                    "rg",
                    "--color=never",
                    "--no-heading",
                    "--with-filename",
                    "--line-number",
                    "--column",
                    "--smart-case",
                    "--hidden",
                    "--follow",
                },
                mappings = {
                    n = {
                        ["bd"] = require("telescope.actions").delete_buffer,
                    },
                    i = {
                        ["bd"] = require("telescope.actions").delete_buffer,
                    },
                },
            },

            -- defaults = {
            -- 	mappings = {
            -- 		n = {
            -- 			["bd"] = require("telescope.actions").delete_buffer,
            -- 		},
            -- 		i = {
            -- 			["bd"] = require("telescope.actions").delete_buffer,
            -- 		},
            -- 	},
            -- 	-- vimgrep_arguments = {
            -- 	--     "rg",
            -- 	--     "--hidden",
            -- 	--     "--no_ignore",
            -- 	--
            -- 	-- },
            -- 	-- vimgrep_arguments = {
            -- 	--     "rg",
            -- 	--     "--color=never",
            -- 	--     "--no-heading",
            -- 	--     "--with-filename",
            -- 	--     "--line-number",
            -- 	--     "--column",
            -- 	--     "--smart-case",
            -- 	--     "--hidden", -- add this
            -- 	-- },
            -- },
        })
    end,
}
