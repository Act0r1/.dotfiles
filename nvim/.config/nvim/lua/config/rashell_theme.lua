local M = {}
local uv = vim.uv or vim.loop
local active, last_content, watcher, timer
local started, closing = false, false

local function enabled()
    local desktop = ((vim.env.XDG_CURRENT_DESKTOP or "") .. ":" .. (vim.env.XDG_SESSION_DESKTOP or "")):lower()
    local hyprland = false
    for name in desktop:gmatch("[^:;]+") do
        if name == "niri" then
            return false
        end
        hyprland = hyprland or name == "hyprland"
    end
    if vim.env.NIRI_SOCKET and vim.env.NIRI_SOCKET ~= "" then
        return false
    end
    return hyprland or vim.env.RASHELL_TERMINAL_SESSION == "rashell"
end

local function directory()
    local config = vim.env.XDG_CONFIG_HOME or ""
    if config:sub(1, 1) ~= "/" then
        config = vim.fn.expand("~/.config")
    end
    return config .. "/rashell"
end

local function hex(value)
    return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

local function decode(content)
    local ok, data = pcall(vim.json.decode, content)
    if not ok or type(data) ~= "table" or type(data.name) ~= "string"
        or (data.kind ~= "dark" and data.kind ~= "light")
        or type(data.palette) ~= "table" or type(data.base16) ~= "table"
        or type(data.ansi) ~= "table" or #data.ansi ~= 16 then
        return nil
    end
    for _, key in ipairs({ "background", "surface", "surfaceRaised", "accent", "accentMuted", "text",
        "textMuted", "textDisabled", "textOnAccent", "border", "borderInteractive", "danger", "textOnDanger" }) do
        if not hex(data.palette[key]) then
            return nil
        end
    end
    for index = 0, 15 do
        if not hex(data.base16[string.format("base%02X", index)]) or not hex(data.ansi[index + 1]) then
            return nil
        end
    end
    local p, b = data.palette, data.base16
    for key, fallback in pairs({ accentSecondary = p.accentMuted, dangerText = p.danger,
        borderControl = p.borderInteractive, success = b.base0B, warning = b.base0A, info = b.base0D }) do
        if p[key] == nil then p[key] = fallback end
        if not hex(p[key]) then return nil end
    end
    for group, defaults in pairs({
        syntax = { comment = b.base03, string = b.base0B, keyword = b.base0E, ["function"] = b.base0D,
            type = b.base0A, number = b.base09, constant = b.base09, variable = b.base05,
            operator = b.base05, punctuation = b.base05 },
        settings = { background = b.base00, foreground = b.base05, ["cursor-color"] = p.accent,
            ["cursor-text"] = p.textOnAccent, ["selection-background"] = b.base02,
            ["selection-foreground"] = b.base05, ["search-background"] = p.accent,
            ["search-foreground"] = p.textOnAccent, ["search-selected-background"] = p.accent,
            ["search-selected-foreground"] = p.textOnAccent },
    }) do
        if data[group] == nil then data[group] = {} end
        if type(data[group]) ~= "table" then return nil end
        for key, fallback in pairs(defaults) do
            if data[group][key] == nil then data[group][key] = fallback end
            if not hex(data[group][key]) then return nil end
        end
    end
    return data
end

function M.lualine_theme()
    if not active then return nil end
    local p = active.palette
    local result = {}
    for mode, color in pairs({ normal = p.accent, insert = p.success, visual = p.accentSecondary,
        replace = p.dangerText, command = p.warning, terminal = p.info }) do
        result[mode] = {
            a = { fg = p.background, bg = color, gui = "bold" },
            b = { fg = p.text, bg = p.surfaceRaised },
            c = { fg = p.textMuted, bg = p.surface },
        }
    end
    result.inactive = {
        a = { fg = p.textMuted, bg = p.surface },
        b = { fg = p.textMuted, bg = p.surface },
        c = { fg = p.textMuted, bg = p.surface },
    }
    return result
end

local function apply(data, from_colorscheme)
    local p, s, t = data.palette, data.syntax, data.settings
    if not from_colorscheme then
        vim.api.nvim_exec_autocmds("ColorSchemePre", { pattern = "rashell", modeline = false })
    end
    vim.g.colors_name = nil
    if vim.o.background ~= data.kind then vim.o.background = data.kind end
    vim.o.termguicolors = true
    vim.cmd("highlight clear")
    vim.g.colors_name = "rashell"
    vim.g.rashell_theme = data.name
    local groups = {
        Normal = { fg = t.foreground, bg = t.background },
        NormalNC = { fg = t.foreground, bg = t.background },
        NormalFloat = { fg = p.text, bg = p.surface },
        FloatBorder = { fg = p.borderControl, bg = p.surface },
        FloatTitle = { fg = p.accent, bg = p.surface, bold = true },
        Cursor = { fg = t["cursor-text"], bg = t["cursor-color"] },
        CursorLine = { bg = p.surface },
        CursorColumn = { bg = p.surface },
        ColorColumn = { bg = p.surfaceRaised },
        LineNr = { fg = s.comment },
        CursorLineNr = { fg = p.accent, bold = true },
        SignColumn = { bg = t.background },
        EndOfBuffer = { fg = p.border },
        NonText = { fg = s.comment },
        Whitespace = { fg = p.borderControl },
        WinSeparator = { fg = p.borderControl },
        Folded = { fg = p.textMuted, bg = p.surface },
        FoldColumn = { fg = p.textMuted, bg = t.background },
        Visual = { fg = t["selection-foreground"], bg = t["selection-background"] },
        Search = { fg = t["search-foreground"], bg = t["search-background"] },
        IncSearch = { fg = t["search-selected-foreground"], bg = t["search-selected-background"] },
        MatchParen = { fg = p.accent, bg = p.surfaceRaised, bold = true },
        Pmenu = { fg = p.text, bg = p.surface },
        PmenuSel = { fg = p.textOnAccent, bg = p.accent },
        PmenuSbar = { bg = p.surfaceRaised },
        PmenuThumb = { bg = p.borderControl },
        StatusLine = { fg = p.text, bg = p.surfaceRaised },
        StatusLineNC = { fg = p.textMuted, bg = p.surface },
        TabLine = { fg = p.textMuted, bg = p.surface },
        TabLineFill = { bg = p.surface },
        TabLineSel = { fg = p.textOnAccent, bg = p.accent },
        Title = { fg = p.accent, bold = true },
        Directory = { fg = p.info },
        MoreMsg = { fg = p.success },
        Question = { fg = p.accent },
        WarningMsg = { fg = p.warning },
        ErrorMsg = { fg = p.dangerText },
        Error = { fg = p.dangerText },
        Comment = { fg = s.comment, italic = true },
        String = { fg = s.string },
        Character = { fg = s.string },
        Constant = { fg = s.constant },
        Number = { fg = s.number },
        Boolean = { fg = s.constant },
        Identifier = { fg = s.variable },
        Function = { fg = s["function"] },
        Statement = { fg = s.keyword },
        Operator = { fg = s.operator },
        PreProc = { fg = s.keyword },
        Type = { fg = s.type },
        Special = { fg = s.constant },
        Delimiter = { fg = s.punctuation },
        Underlined = { fg = p.info, underline = true },
        Todo = { fg = p.warning, bold = true },
        DiffAdd = { fg = p.success, bg = p.surface },
        DiffChange = { fg = p.info, bg = p.surface },
        DiffDelete = { fg = p.dangerText, bg = p.surface },
        DiffText = { fg = p.warning, bg = p.surfaceRaised, bold = true },
    }
    for kind, color in pairs({ Error = p.dangerText, Warn = p.warning, Info = p.info, Hint = p.success, Ok = p.success }) do
        groups["Diagnostic" .. kind] = { fg = color }
        groups["DiagnosticUnderline" .. kind] = { sp = color, undercurl = true }
    end
    for name, color in pairs({ Add = p.success, Change = p.info, Delete = p.dangerText }) do
        groups["GitSigns" .. name] = { fg = color }
    end
    for name, values in pairs(groups) do vim.api.nvim_set_hl(0, name, values) end
    for name, target in pairs({
        Float = "Number", Keyword = "Statement", Conditional = "Statement", Repeat = "Statement",
        Exception = "Statement", Include = "PreProc", Define = "PreProc", Macro = "PreProc",
        Structure = "Type", StorageClass = "Type", Typedef = "Type", SpecialChar = "Special",
        CurSearch = "IncSearch", QuickFixLine = "Visual", WinBar = "StatusLine", WinBarNC = "StatusLineNC",
        ["@comment"] = "Comment", ["@string"] = "String", ["@string.escape"] = "SpecialChar",
        ["@character"] = "Character", ["@number"] = "Number", ["@boolean"] = "Boolean",
        ["@constant"] = "Constant", ["@variable"] = "Identifier", ["@variable.builtin"] = "Special",
        ["@function"] = "Function", ["@function.builtin"] = "Function", ["@constructor"] = "Type",
        ["@keyword"] = "Keyword", ["@operator"] = "Operator", ["@type"] = "Type",
        ["@property"] = "Identifier", ["@punctuation"] = "Delimiter", ["@tag"] = "Type",
        ["@markup.heading"] = "Title", ["@markup.link"] = "Underlined", ["@markup.raw"] = "String",
        ["@diff.plus"] = "DiffAdd", ["@diff.minus"] = "DiffDelete", ["@diff.delta"] = "DiffChange",
    }) do vim.api.nvim_set_hl(0, name, { link = target }) end
    for index, color in ipairs(data.ansi) do vim.g["terminal_color_" .. (index - 1)] = color end
    active = data
    if not from_colorscheme then
        vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "rashell", modeline = false })
    end
end

local function refresh(force, from_colorscheme)
    if closing or not enabled() then return false end
    local file = io.open(directory() .. "/terminal-palette.json", "r")
    local content
    if file then
        content = file:read("*a")
        file:close()
    end
    if not force and content == last_content then return active ~= nil end
    local data = content and decode(content)
    if not data then
        if force and active then apply(active, from_colorscheme) end
        return active ~= nil
    end
    apply(data, from_colorscheme)
    last_content = content
    return true
end

function M.reload(from_colorscheme)
    return refresh(true, from_colorscheme)
end

local function close_watcher()
    if watcher then
        watcher:stop()
        watcher:close()
        watcher = nil
    end
end

local function watch()
    if watcher or closing then return end
    local handle = uv.new_fs_event()
    if not handle then return end
    local ok, result = pcall(handle.start, handle, directory(), {}, function(err, filename)
        if err or closing then return end
        if filename and filename ~= "terminal-palette.json" then return end
        timer:start(120, 0, vim.schedule_wrap(function()
            if not closing then refresh(false) end
        end))
    end)
    if ok and result then
        watcher = handle
    else
        handle:close()
    end
end

function M.setup()
    if not enabled() then return false end
    if not started then
        started = true
        timer = uv.new_timer()
        local group = vim.api.nvim_create_augroup("RashellTheme", { clear = true })
        vim.api.nvim_create_autocmd("FocusGained", {
            group = group,
            callback = function()
                close_watcher()
                watch()
                refresh(false)
            end,
        })
        vim.api.nvim_create_autocmd("VimLeavePre", {
            group = group,
            callback = function()
                closing = true
                close_watcher()
                timer:stop()
                timer:close()
            end,
        })
        watch()
    end
    return refresh(false)
end

return M
