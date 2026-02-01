return {
    "christoomey/vim-tmux-navigator",
    cmd = {
        "TmuxNavigateLeft",
        "TmuxNavigateDown",
        "TmuxNavigateUp",
        "TmuxNavigateRight",
        "TmuxNavigatePrevious",
    },
    keys = {
        { "<C-h>",  "<cmd><C-U>TmuxNavigateLeft<cr>" },
        { "<C-j>",  "<cmd><C-U>TmuxNavigateDown<cr>" },
        { "<C-k>",  "<cmd><C-U>TmuxNavigateUp<cr>" },
        { "<C-l>",  "<cmd><C-U>TmuxNavigateRight<cr>" },
        { "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
}

-- return {
--     "christoomey/vim-tmux-navigator",
--     lazy = true,
--     keys = {
--         { "<c-Left>",  "<cmd>TmuxNavigateLeft<cr>" },
--         { "<c-Down>",  "<cmd>TmuxNavigateDown<cr>" },
--         { "<c-Up>",    "<cmd>TmuxNavigateUp<cr>" },
--         { "<c-Right>", "<cmd>TmuxNavigateRight<cr>" },
--         { "<c-h>" },
--         { "<c-j>" },
--         { "<c-k>" },
--         { "<c-l>" },
--     },
-- }

-- Official config from GitHub docs (ctrl+hjkl):
-- Если Ctrl-L не работает сразу после открытия nvim, используй lazy = false
-- Если хочешь вернуть ленивую загрузку, закомментируй lazy = false
-- return {
-- 	"christoomey/vim-tmux-navigator",
-- 	lazy = false,
-- 	cmd = {
-- 		"TmuxNavigateLeft",
-- 		"TmuxNavigateDown",
-- 		"TmuxNavigateUp",
-- 		"TmuxNavigateRight",
-- 		"TmuxNavigatePrevious",
-- 	},
-- 	keys = {
-- 		{ "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
-- 		{ "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
-- 		{ "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
-- 		{ "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
-- 		{ "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
-- 	},
-- }
