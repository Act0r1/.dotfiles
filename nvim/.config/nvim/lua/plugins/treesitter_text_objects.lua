return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	branch = "main",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local select = require("nvim-treesitter-textobjects.select")

		require("nvim-treesitter-textobjects").setup({
			select = {
				lookahead = true,
				include_surrounding_whitespace = false,
			},
		})

		-- Function textobjects
		vim.keymap.set({ "x", "o" }, "af", function()
			select.select_textobject("@function.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "if", function()
			select.select_textobject("@function.inner", "textobjects")
		end)

		-- Class textobjects
		vim.keymap.set({ "x", "o" }, "ac", function()
			select.select_textobject("@class.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "ic", function()
			select.select_textobject("@class.inner", "textobjects")
		end)

		-- Call textobjects
		vim.keymap.set({ "x", "o" }, "aC", function()
			select.select_textobject("@call.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "iC", function()
			select.select_textobject("@call.inner", "textobjects")
		end)

		-- Parameter textobjects
		vim.keymap.set({ "x", "o" }, "aa", function()
			select.select_textobject("@parameter.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "ia", function()
			select.select_textobject("@parameter.inner", "textobjects")
		end)

		-- Conditional textobjects
		vim.keymap.set({ "x", "o" }, "ai", function()
			select.select_textobject("@conditional.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "ii", function()
			select.select_textobject("@conditional.inner", "textobjects")
		end)

		-- Loop textobjects
		vim.keymap.set({ "x", "o" }, "al", function()
			select.select_textobject("@loop.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "il", function()
			select.select_textobject("@loop.inner", "textobjects")
		end)

		-- Assignment textobjects
		vim.keymap.set({ "x", "o" }, "a=", function()
			select.select_textobject("@assignment.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "i=", function()
			select.select_textobject("@assignment.inner", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "l=", function()
			select.select_textobject("@assignment.lhs", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "r=", function()
			select.select_textobject("@assignment.rhs", "textobjects")
		end)

		-- Return textobjects
		vim.keymap.set({ "x", "o" }, "ar", function()
			select.select_textobject("@return.outer", "textobjects")
		end)
		vim.keymap.set({ "x", "o" }, "ir", function()
			select.select_textobject("@return.inner", "textobjects")
		end)
	end,
}
