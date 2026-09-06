local M = {}

local bf = require('como.buffer')
local mh = require('como.matcher')
local hl = require('como.highlight')


M.default_config = {
    show_last_cmd = true,
    auto_scroll = true,
    preferred_win_pos = "bottom",
    prompt_on_error = true,
    history_limit = 50,
    custom_matchers = {}
}

M.config = {}

M.last_command = ""

M.history_path = vim.fn.stdpath("data") .. "/como/history.json"

M.history = nil

M.pid = nil

M.commands = {
    "compile",
    "recompile",
    "open",
    "toggle"
}

local function current_dir()
    return vim.uv.cwd() or vim.fn.getcwd()
end

local function load_history()
    if M.history then
        return M.history
    end

    M.history = {}
    local ok, lines = pcall(vim.fn.readfile, M.history_path)
    if not ok or #lines == 0 then
        return M.history
    end

    local ok_decode, data = pcall(vim.json.decode, table.concat(lines, "\n"))
    if ok_decode and type(data) == "table" then
        M.history = data
    end

    return M.history
end

local function save_history()
    vim.fn.mkdir(vim.fn.fnamemodify(M.history_path, ":h"), "p")
    pcall(vim.fn.writefile, { vim.json.encode(load_history()) }, M.history_path)
end

local function history_for_dir(cwd)
    local history = load_history()
    if type(history[cwd]) ~= "table" then
        history[cwd] = {}
    end
    return history[cwd]
end

local function last_command(cwd)
    local history = history_for_dir(cwd or current_dir())
    return history[1] or ""
end

local function record_command(cmd, cwd)
    local history = history_for_dir(cwd or current_dir())
    for i = #history, 1, -1 do
        if history[i] == cmd then
            table.remove(history, i)
        end
    end

    table.insert(history, 1, cmd)
    while #history > (M.config.history_limit or M.default_config.history_limit) do
        table.remove(history)
    end

    M.last_command = cmd
    save_history()
end

local function history_input_win(cwd)
    local history = vim.deepcopy(history_for_dir(cwd))
    local cursor = 0
    local edited = ""

    local function set_text(win, text)
        text = text or ""
        vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { text })
        vim.api.nvim_win_set_cursor(win.win, { 1, #text })
    end

    local function prev_history(win)
        if #history == 0 then
            return
        end
        if cursor == 0 then
            edited = win:text()
        end
        cursor = math.min(cursor + 1, #history)
        set_text(win, history[cursor])
    end

    local function next_history(win)
        if cursor == 0 then
            return
        end
        cursor = cursor - 1
        set_text(win, cursor == 0 and edited or history[cursor])
    end

    return {
        keys = {
            i_up = { "<up>", prev_history, mode = { "i", "n" } },
            i_ctrl_p = { "<c-p>", prev_history, mode = { "i", "n" } },
            i_down = { "<down>", next_history, mode = { "i", "n" } },
            i_ctrl_n = { "<c-n>", next_history, mode = { "i", "n" } },
        },
    }
end

M.compile = function(cmd)
    if M.pid then
        vim.notify("Last command still running!", vim.log.levels.ERROR)
        return
    end

    if not cmd then
        print("Empty input, abort")
        return
    end

    local cwd = current_dir()
    record_command(cmd, cwd)

    local buf = bf.buf_open(M.config.preferred_win_pos)

    -- Clear the buffer content
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    -- Write beginning message
    local begin_msg = string.format("-*- mode: compilation; default-directory: \"%s\" -*-", cwd)
    local start_time_msg = "Compilation started at " .. os.date("%a %b %d %X")
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {begin_msg, start_time_msg, '', cmd})
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    -- line indexing is zero-based, so 3 means it's line number 4
    local line_nr = 3
    if M.config.auto_scroll then
        vim.api.nvim_win_set_cursor(bf.win, {line_nr+1, 0})
    end

    -- Define the callback for the job
    local function on_output(data)
        if data then
            local win_valid = bf.if_buf_present(bf.buf)
            local s = vim.split(data, '\n', {plain=true, trimempty = false})
            for _, line in ipairs(s) do
                line_nr = line_nr + 1
                -- print(string.format("%d: %s", line_nr, line))

                -- Write lines to buffer
                vim.api.nvim_buf_set_option(buf, 'modifiable', true)
                vim.api.nvim_buf_set_lines(buf, -1, -1, false, {line})
                vim.api.nvim_buf_set_option(buf, 'modifiable', false)

                local result = mh.parse_line(line)
                -- print(vim.inspect(result))

                -- Adding highlight to the text
                hl.highlight_logic(result, buf, line_nr)

                if M.config.auto_scroll and win_valid then
                    -- Check cursor position, and auto scroll the window
                    bf.check_and_auto_scroll()
                end
            end
        end
    end

    local function on_exit(exit_code, signal)
        -- Auto-scroll feature:
        -- Get the current row
        -- to check if it needs to scroll to the bottom when compilation finished
        local win_valid = vim.api.nvim_win_is_valid(bf.win)
        local row
        if win_valid then
            row = vim.api.nvim_win_get_cursor(bf.win)[1]
        else
            vim.notify("Compilation ended, result is in the compilation buffer / ", vim.log.levels.WARN)
        end

        -- Write end message to buffer
        local end_msg
        local hl_group, hl_start, hl_end
        local ok_to_clear = false
        if signal == 9 then
            end_msg = "Compilation interrupted"
            hl_group = 'Como_hl_error'
            hl_start, hl_end = 12, 23
        elseif exit_code ~= 0 then
            end_msg = string.format("Compilation exited abnormally with code %d", exit_code)
            hl_group = 'Como_hl_error'
            hl_start, hl_end = 19, 29
        else
            end_msg = "Compilation finished"
            hl_group = 'Como_hl_ok'
            hl_start, hl_end = 12, 20
            ok_to_clear = true
        end
        -- Write end_msg to buffer
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, -2, -1, false, {'', end_msg .. " at " .. os.date("%a %b %d %X")})
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        hl.apply_highlight(buf, hl_group, vim.api.nvim_buf_line_count(buf)-1, hl_start, hl_end)

        -- Print the msg out and clear it after 2.75 seconds
        vim.cmd('echon "' .. end_msg ..'"')
        if ok_to_clear and win_valid then vim.fn.timer_start(2750, function() vim.cmd([[echon ' ']]) end) end

        -- To scroll to end of the buffer
        if M.config.auto_scroll and win_valid then
            local line_count = vim.api.nvim_buf_line_count(buf)
            if row and row == (line_count - 2) then
                vim.api.nvim_win_set_cursor(bf.win, {line_count, 0})
            end
        end

        -- Clear pid
        M.pid = nil

        -- On failure, offer to edit the command and run it again
        if M.config.prompt_on_error and not ok_to_clear and signal ~= 9 then
            vim.schedule(function()
                vim.ui.input(
                    { prompt = "Retry (edit command): ", default = cmd, completion = "customlist,v:lua.como_shellcmdline_complete", win = history_input_win(cwd) },
                    function(new_cmd)
                        if new_cmd == nil or new_cmd == '' then
                            return
                        end
                        M.compile(new_cmd)
                    end
                )
            end)
        end
    end

    -- Start the job (execute the user command)
    local handle
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    handle, M.pid = vim.uv.spawn(
        'sh',
        {
            args = { '-c', cmd },
            stdio = { nil, stdout, stderr }
        },
        function(exit_code, signal)
            stdout:read_stop()
            stderr:read_stop()
            stdout:close()
            stderr:close()
            handle:close()
            vim.schedule(function()
                on_exit(exit_code, signal)
            end)
        end
    )

    stdout:read_start(function(err, data)
        assert(not err, err)
        vim.schedule(function()
            on_output(data)
        end)
    end)

    stderr:read_start(function(err, data)
        assert(not err, err)
        vim.schedule(function()
            on_output(data)
        end)
    end)
end

M.recompile = function(cmd)
    M.compile(cmd)
end

M.open_como_buffer = function()
    bf.buf_open(M.config.preferred_win_pos)
end

M.toggle_como_buffer = function()
    local buf_present = bf.if_buf_present(bf.buf)
    if buf_present then
        vim.api.nvim_win_hide(bf.win)
    else
        bf.buf_open(M.config.preferred_win_pos)
    end
end


M.interrupt_program = function()
    -- Ctrl+c to quit program
    -- see como/buffer.lua
    if M.pid then
        -- Kill child process first
        local child_process = vim.api.nvim_get_proc_children(M.pid)
        for i, v in ipairs(child_process) do
            vim.uv.kill(v, 9)
        end
        -- Kill process
        vim.uv.kill(M.pid, 9)
        M.pid = nil
    end
end

M.add_new_matchers = function(new_matchers)
    for matcher_name, data in pairs(new_matchers) do
        mh.matcher_set[matcher_name] = data
    end
    -- print(vim.inspect(mh.matcher_set))
end

M.shellcmdline_complete = function(arg_lead, cmd_line, cursor_pos)
    local line = cmd_line
    local col = cursor_pos
    local using_input_buffer = false

    if line == nil or line == arg_lead then
        local is_input_buffer = vim.bo.buftype == "prompt" or vim.bo.filetype == "snacks_input"
        if is_input_buffer then
            local ok_line, current_line = pcall(vim.api.nvim_get_current_line)
            if ok_line then
                line = current_line
                using_input_buffer = true
                local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
                col = ok_cursor and cursor[2] or #line
            end
        end
    end

    if line == nil then
        line = arg_lead or ''
    end

    if col == nil or col < 0 or (col == 0 and not using_input_buffer and line ~= '') then
        col = #line
    end

    local ok, results = pcall(vim.fn.getcompletion, line:sub(1, col), "shellcmdline")
    if ok then
        return results
    end

    return vim.fn.getcompletion(arg_lead or '', "shellcmdline")
end

_G.como_shellcmdline_complete = M.shellcmdline_complete


M.determine_mode = function(opts)
    local cwd = current_dir()

    -- Compile
    if opts.args == M.commands[1] then
        local default
        if not M.config.show_last_cmd then
            default = ''
        else
            default = last_command(cwd)
        end

        vim.ui.input(
            { prompt = "Compile command: ", default = default, completion = "customlist,v:lua.como_shellcmdline_complete", win = history_input_win(cwd) },
            function(cmd)
                if cmd == nil or cmd == '' then
                    print("Empty input, abort")
                    return
                end
                M.compile(cmd)
            end
        )
        -- Recompile
    elseif opts.args == M.commands[2] then
        local cmd = last_command(cwd)
        if cmd == '' then
            print("No last command, compile first")
            return
        end
        M.recompile(cmd)
        -- Open como buffer
    elseif opts.args == M.commands[3] then
        M.open_como_buffer()
    elseif opts.args == M.commands[4] then
        M.toggle_como_buffer()
    end
end

M.setup = function(user_opts)
    if user_opts then
        M.config = vim.tbl_deep_extend("force", M.default_config, user_opts)
    else
        M.config = M.default_config
    end

    -- Add custom matchers to the matcher set
    if M.config.custom_matchers ~= {} then
        M.add_new_matchers(M.config.custom_matchers)
    end

    hl.init_hl_group()

    vim.api.nvim_create_user_command(
        'Como',
        function(opts)
            M.determine_mode(opts)
        end,
        {
            nargs = 1,
            complete = function()
                -- return completion candidates as a list-like table
                return M.commands
            end,
        }
    )
end

return M
