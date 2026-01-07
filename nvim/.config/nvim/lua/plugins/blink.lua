return {
    {
        "saghen/blink.compat",
        version = "*",
        lazy = true, -- Automatically loads when required by blink.cmp
        opts = {},
    },

    {
        "saghen/blink.cmp",
        -- dependencies = { "rafamadriz/friendly-snippets", "Kaiser-Yang/blink-cmp-avante" },
        dependencies = { "rafamadriz/friendly-snippets" },

        -- version = "0.13.1",
        version = "1.*",
        -- version = "*",
        cmdline = {},
        opts = {
            enabled = function()
                local disabled_filetypes = { "NvimTree", "DressingInput" } -- Add extra fileypes you do not want blink enabled.
                return not vim.tbl_contains(disabled_filetypes, vim.bo.filetype)
            end,
            cmdline = {
                enabled = false,
            },
            keymap = {
                ["<CR>"] = { "accept", "fallback" },
                ["<Tab>"] = {
                    function(cmp)
                        if cmp.snippet_active() then
                            return cmp.select_next()
                        else
                            return cmp.select_next()
                        end
                    end,
                    "snippet_forward",
                    "fallback",
                },
                ["<S-Tab>"] = { "snippet_backward", "fallback" },
            },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
            },

            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = "mono",
            },
            signature = { enabled = true },
            fuzzy = { implementation = "prefer_rust_with_warning" },
            completion = {
                ghost_text = { enabled = false },
                documentation = { auto_show = true, auto_show_delay_ms = 50 },
                menu = {
                    auto_show = true,
                    border = "rounded",
                    draw = {
                        columns = {
                            { "label", "label_description", gap = 2 },
                            { "kind_icon", "kind", gap = 2 },
                        },
                    },
                },
            },
        },
        opts_extend = { "sources.default" },
    },
}
