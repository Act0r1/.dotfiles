local opts = { noremap = true, silent = true }
local key = vim.keymap.set

-- ============================================================================
-- FORMATTING
-- ============================================================================

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

vim.keymap.set({ "n", "v" }, "<leader>f", function()
    require("conform").format({ async = false }, function(err)
        if not err then
            local mode = vim.api.nvim_get_mode().mode
            if vim.startswith(string.lower(mode), "v") then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
            end
        end
    end)
end, { desc = "Format code" })

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
key("n", "<Tab>", ":BufferLineCycleNext <CR>", opts)

-- ============================================================================
-- BASIC EDITOR KEYMAPS
-- ============================================================================


vim.opt.timeoutlen = 500
key("n", "df", "vafd", opts)
key("n", ";", ":")
key("n", "qq", ":q!<CR>")
key("n", "<Esc>", ":noh <CR>", opts)
key("n", "so", ":source ~/.config/nvim/init.lua<CR>", opts)
key("n", ",,", "`[v`]", opts)

-- ============================================================================
-- TEXT MANIPULATION
-- ============================================================================

key("n", "dl", ":g/^$/d<CR>")
key("n", "v'", 'vi"y')
key("n", "zq", 'ysiw"')
key("v", "p", '"_dP', opts)
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete without yanking" })

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

-- ============================================================================
-- PLUGIN KEYMAPS
-- ============================================================================

key("n", "<leader>j", ":NvimTreeToggle <CR>", opts)
key("n", "<leader>tu", ":UndotreeToggle<CR>", opts)
key("n", "<leader>gg", ":LazyGit<CR>", opts)
key("n", "<leader>ld", ":Telescope lsp_document_symbols<CR>", opts)
vim.keymap.set("n", "<space>e", vim.diagnostic.open_float)

-- ============================================================================
-- HARPOON
-- ============================================================================

key("n", "<A-a>", ':lua require("harpoon.mark").add_file()<CR>', opts)
key("n", "<A-w>", ':lua require("harpoon.ui").toggle_quick_menu()<CR>', opts)
key("n", "<A-]>", ':lua require("harpoon.ui").nav_next()<CR>', opts)
key("n", "<A-[>", ':lua require("harpoon.ui").nav_prev()<CR>', opts)

-- ============================================================================
-- UTILITIES
-- ============================================================================

vim.keymap.set("n", "<leader>pa", function()
    local path = vim.fn.expand("%:p")
    vim.fn.setreg("+", path)
    print("file:", path)
end)

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
    callback = function()
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
