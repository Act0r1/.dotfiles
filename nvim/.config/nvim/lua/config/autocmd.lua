--- theme
vim.cmd([[colorscheme kanagawa-wave]])


-- For docker-compose LSP
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "docker-compose.yml", "docker-compose.yaml", "docker-compose.*.yml", "docker-compose.*.yaml" },
    callback = function()
        vim.bo.filetype = "yaml.docker-compose"
    end,
})


-- highlight yank
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
    pattern = "*",
    desc = "highlight selection on yank",
    callback = function()
        vim.highlight.on_yank({ timeout = 200, visual = true })
    end,
})

-- restore cursor to file position in previous editing session
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(args)
        local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
        local line_count = vim.api.nvim_buf_line_count(args.buf)
        if mark[1] > 0 and mark[1] <= line_count then
            vim.api.nvim_win_set_cursor(0, mark)
            -- defer centering slightly so it's applied after render
            vim.schedule(function()
                vim.cmd("normal! zz")
            end)
        end
    end,
})

-- open help in vertical split
vim.api.nvim_create_autocmd("FileType", {
    pattern = "help",
    command = "wincmd L",
})

-- auto resize splits when the terminal's window is resized
vim.api.nvim_create_autocmd("VimResized", {
    command = "wincmd =",
})

-- no auto continue comments on new line
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("no_auto_comment", {}),
    callback = function()
        vim.opt_local.formatoptions:remove({ "c", "r", "o" })
    end,
})

-- syntax highlighting for dotenv files
vim.api.nvim_create_autocmd("BufRead", {
    group = vim.api.nvim_create_augroup("dotenv_ft", { clear = true }),
    pattern = { ".env", ".env.*" },
    callback = function()
        vim.bo.filetype = "dosini"
    end,
})

-- show cursorline only in active window enable
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = vim.api.nvim_create_augroup("active_cursorline", { clear = true }),
    callback = function()
        vim.opt_local.cursorline = true
    end,
})

-- show cursorline only in active window disable
vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
    group = "active_cursorline",
    callback = function()
        vim.opt_local.cursorline = false
    end,
})

vim.api.nvim_create_user_command("PyInit", function()
    local line = vim.api.nvim_get_current_line()
    local params = line:match("__init__%(self,%s*(.-)%)")

    if not params or params == "" then
        vim.notify("No __init__ parameters found", vim.log.levels.WARN)
        return
    end

    local assignments = {}
    for param in params:gmatch("[^,]+") do
        param = param:match("^%s*(.-)%s*$")     -- trim
        param = param:match("^([^:=]+)")        -- удаляем type hints
        if param and param ~= "" then
            param = param:match("^%s*(.-)%s*$") -- trim again
            table.insert(assignments, "        self." .. param .. " = " .. param)
        end
    end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, assignments)
end, { desc = "Generate self.x = x from __init__ params" })

-- Горячая клавиша (опционально)
vim.keymap.set("n", "<leader>pi", ":PyInit<CR>", { desc = "Python: Init assignments" })
-- Zig config
vim.g.zig_fmt_parse_errors = 0
