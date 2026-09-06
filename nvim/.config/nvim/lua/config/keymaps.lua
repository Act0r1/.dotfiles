local opts = { noremap = true, silent = true }
local key = vim.keymap.set
vim.opt.statusline = " "
-- ============================================================================
-- FORMATTING
-- ============================================================================

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- ============================================================================
-- BUFFER MANAGEMENT
-- ============================================================================

vim.keymap.set("n", "<Leader>bd", function()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if bufnr ~= vim.api.nvim_get_current_buf() and vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end
end, { noremap = true, silent = true })

key("n", "<leader>,", ":bprev<CR>")
key("n", "<leader>.", ":bnext<CR>")
-- key("n", "<Tab>", ":BufferLineCycleNext <CR>", opts)

-- ============================================================================
-- BASIC EDITOR KEYMAPS
-- ============================================================================

vim.opt.timeoutlen = 500
key("n", "df", 'vaf"_d', opts)
key("n", ";", ":")
key("n", "qq", ":q!<CR>")
key("n", "<Esc>", ":noh <CR>", opts)

-- Move by display lines through wrapped text; counts still jump real lines.
key({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down (display line)" })
key({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up (display line)" })
key("n", "so", ":source ~/.config/nvim/init.lua<CR>", opts)
key("n", ",,", "`[v`]", opts)

-- ============================================================================
-- TEXT MANIPULATION
-- ============================================================================

key("n", "dl", ":g/^$/d _<CR>")
key("n", "v'", 'vi"y')
key("n", "zq", 'ysiw"')

key({ "n", "x" }, "<leader>d", '"_d', { desc = "Delete (black hole)" })
key({ "n", "x" }, "<leader>D", '"_D', { desc = "Delete to EOL (black hole)" })

local function paste_over_selection()
	local content = vim.fn.getreg(vim.v.register)
	local vmode = vim.fn.mode()
	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	local sr, sc = start_pos[2], start_pos[3]
	local er, ec = end_pos[2], end_pos[3]

	if sr > er or (sr == er and sc > ec) then
		sr, er = er, sr
		sc, ec = ec, sc
	end

	if vmode == "\22" then
		vim.api.nvim_feedkeys('"_dP', "nx", false)
		return
	end

	content = content:gsub("\r?\n$", "")
	local lines = vim.split(content, "\n", { plain = true })
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

	if vmode == "V" then
		vim.api.nvim_buf_set_lines(0, sr - 1, er, false, lines)
		vim.api.nvim_win_set_cursor(0, { sr, 0 })
		return
	end

	local end_line = vim.api.nvim_buf_get_lines(0, er - 1, er, false)[1] or ""
	local end_col = math.min(ec - 1, #end_line)
	if end_col < #end_line then
		end_col = vim.fn.matchend(end_line, ".", end_col)
	end

	vim.api.nvim_buf_set_text(0, sr - 1, sc - 1, er - 1, end_col, lines)
	vim.api.nvim_win_set_cursor(0, { sr, sc - 1 })
end

key("x", "p", paste_over_selection, { desc = "Paste over selection without yanking it" })
key("x", "P", paste_over_selection, { desc = "Paste over selection without yanking it" })

-- Normal-mode p/P: charwise clipboard text ending in a newline (typical for
-- text copied from a browser) pastes linewise instead of splitting the line.
local function smart_put(after)
	return function()
		local content = vim.fn.getreg('"')
		if vim.fn.getregtype('"') == "v" and content:sub(-1) == "\n" then
			local lines = vim.split(content:gsub("\n$", ""), "\n", { plain = true })
			vim.api.nvim_put(lines, "l", after, true)
		else
			vim.api.nvim_feedkeys(after and "p" or "P", "n", false)
		end
	end
end
key("n", "p", smart_put(true), { desc = "Paste after" })
key("n", "P", smart_put(false), { desc = "Paste before" })

key(
	"n",
	"gy",
	':lua local pos = vim.api.nvim_win_get_cursor(0); vim.cmd("normal! ggVGy"); vim.api.nvim_win_set_cursor(0, pos)<CR>',
	opts
)

-- ============================================================================
-- VISUAL MODE MOVEMENT
-- ============================================================================

key("v", "<A-j>", ":m .+1<CR>==", opts)
key("v", "<A-k>", ":m .-2<CR>==", opts)
key("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
key("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)
key("x", "J", ":move '>+1<CR>gv-gv", opts)
key("x", "K", ":move '<-2<CR>gv-gv", opts)

vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- ============================================================================
-- WINDOW MANAGEMENT
-- ============================================================================

key("n", "<leader>v", "<C-w>v")
key("n", "<leader>h", "<C-w>s")
key("n", "<leader>c", "<C-w>c")

-- ============================================================================
-- SEARCH
-- ============================================================================

vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result (centered)" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })
vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, { desc = "Open diagnostic float" })

-- ============================================================================
-- UTILITIES
-- ============================================================================

vim.keymap.set("n", "<leader>pa", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	print("file:", path)
end)

vim.keymap.set("n", "yp", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	print("Copied: " .. path)
end, { desc = "Yank full file path" })

vim.keymap.set("n", "gp", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	print("Copied: " .. path)
end, { desc = "Copy absolute path of current file" })

-- ============================================================================
-- AUTOCMDS
-- ============================================================================

local augroup = vim.api.nvim_create_augroup("UserConfig", {})

vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup,
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	group = augroup,
	callback = function(args)
		if vim.bo[args.buf].buftype ~= "" then
			return
		end

		local dir = vim.fn.expand("<afile>:p:h")
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p")
		end
	end,
})

-- ============================================================================
-- PERFORMANCE & DIFF OPTIONS
-- ============================================================================

vim.opt.diffopt:append("linematch:60")
vim.opt.redrawtime = 10000
vim.opt.maxmempattern = 20000

local undodir = vim.fn.expand("~/.vim/undodir")
if vim.fn.isdirectory(undodir) == 0 then
	vim.fn.mkdir(undodir, "p")
end

-- ============================================================================
-- FLOATING TERMINAL
-- ============================================================================

local terminal_state = {
	buf = nil,
	win = nil,
	is_open = false,
}

local function FloatingTerminal()
	if terminal_state.is_open and vim.api.nvim_win_is_valid(terminal_state.win) then
		vim.api.nvim_win_close(terminal_state.win, false)
		terminal_state.is_open = false
		return
	end

	if not terminal_state.buf or not vim.api.nvim_buf_is_valid(terminal_state.buf) then
		terminal_state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[terminal_state.buf].bufhidden = "hide"
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	terminal_state.win = vim.api.nvim_open_win(terminal_state.buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_win_set_option(terminal_state.win, "winblend", 0)
	vim.api.nvim_win_set_option(
		terminal_state.win,
		"winhighlight",
		"Normal:FloatingTermNormal,FloatBorder:FloatingTermBorder"
	)

	vim.api.nvim_set_hl(0, "FloatingTermNormal", { bg = "none" })
	vim.api.nvim_set_hl(0, "FloatingTermBorder", { bg = "none" })

	local has_terminal = false
	local lines = vim.api.nvim_buf_get_lines(terminal_state.buf, 0, -1, false)
	for _, line in ipairs(lines) do
		if line ~= "" then
			has_terminal = true
			break
		end
	end

	if not has_terminal then
		vim.fn.termopen(os.getenv("SHELL"))
	end

	terminal_state.is_open = true
	vim.cmd("startinsert")

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = terminal_state.buf,
		callback = function()
			if terminal_state.is_open and vim.api.nvim_win_is_valid(terminal_state.win) then
				vim.api.nvim_win_close(terminal_state.win, false)
				terminal_state.is_open = false
			end
		end,
		once = true,
	})
end

vim.keymap.set("n", "<leader>t", FloatingTerminal, { noremap = true, silent = true, desc = "Toggle floating terminal" })
vim.keymap.set("t", "<Esc>", function()
	if terminal_state.is_open then
		vim.api.nvim_win_close(terminal_state.win, false)
		terminal_state.is_open = false
	end
end, { noremap = true, silent = true, desc = "Close floating terminal from terminal mode" })
