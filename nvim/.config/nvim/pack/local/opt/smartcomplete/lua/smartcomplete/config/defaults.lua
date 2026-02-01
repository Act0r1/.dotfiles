local M = {}

M.defaults = {
    -- Provider configuration
    provider = "openrouter", -- "openrouter" | "anthropic"

    -- API Keys (prefer environment variables)
    api_keys = {
        openrouter = nil, -- Falls back to $OPENROUTER_API_KEY
        anthropic = nil,  -- Falls back to $ANTHROPIC_API_KEY
    },

    -- Model configuration
    models = {
        openrouter = "anthropic/claude-opus-4",
        anthropic = "claude-opus-4-5-20251101",
    },

    -- Trigger configuration
    trigger = {
        auto = true,               -- Enable auto-trigger on text change
        debounce_ms = 300,         -- Debounce delay in milliseconds
        min_chars = 1,             -- Minimum characters before triggering
        trigger_on_delete = false, -- Trigger on backspace/delete
    },

    -- Suggestion display configuration
    suggestion = {
        enabled = true,                -- Enable ghost text display
        keymap = {
            accept = "<C-y>",          -- Accept full suggestion (C-y to avoid Tab conflict with cmp)
            accept_word = nil,         -- Accept next word (disabled)
            accept_line = nil,         -- Accept next line (disabled)
            dismiss = nil,             -- Dismiss current suggestion (disabled)
        },
        highlight = "Comment",         -- Highlight group for ghost text
    },

    -- nvim-cmp integration
    cmp = {
        enabled = true,     -- Enable nvim-cmp source
        priority = 100,     -- Source priority
        keyword_length = 3, -- Minimum keyword length
    },

    -- Request configuration
    request = {
        timeout_ms = 30000, -- Request timeout (30s for large files)
        max_tokens = 96,    -- Maximum tokens to generate (keep completions short)
        temperature = 0.0,  -- Temperature for generation
        context_lines = 50, -- Lines of context to include
    },

    -- Filetype configuration
    filetypes = {
        ["*"] = true, -- Enable for all filetypes by default
        markdown = false,
        help = false,
        gitcommit = false,
        TelescopePrompt = false,
        json = false,
        jsonc = false,
        sshconfig = false,
        conf = false,
        config = false,
    },

    -- Filename patterns to exclude (checked against full path)
    excluded_patterns = {
        "%.env$",
        "%.env%.",        -- .env.example, .env.local, etc.
        "%.pem$",
        "%.pub$",
        "%.key$",
        "%.crt$",
        "%.cer$",
        "id_rsa",
        "id_ed25519",
        "id_dsa",
        "known_hosts",
        "authorized_keys",
        "%.ssh/config",
        "credentials",
        "secrets",
    },

    -- Logging
    log = {
        level = "warn", -- "debug" | "info" | "warn" | "error"
    },

    -- Propagation feature - find related places needing updates
    propagate = {
        enabled = true,
        auto_trigger = false,         -- Manual only for now (use :Smartcomplete propagate)
        show_window = true,           -- Show floating window with location list
        show_signs = true,            -- Show gutter signs at locations
        sign_text = "▼",
        sign_hl = "DiagnosticInfo",
        auto_jump_after_accept = true, -- Jump to next location after accepting
        keymap = {
            next = "]s",              -- Jump to next propagation location
            prev = "[s",              -- Jump to prev propagation location
            dismiss = "<C-x>",        -- Dismiss current and jump to next
            clear_all = "<leader>sc", -- Clear all propagation suggestions
        },
    },
}

return M
