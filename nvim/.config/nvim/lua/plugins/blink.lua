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
                -- list = {
                -- 	preselect = true,
                -- 	-- auto_insert = true,
                -- },
                ghost_text = {
                    enabled = false,
                },
                documentation = { auto_show = true, auto_show_delay_ms = 50 },
                -- documentation = { window = { border = "single" } },
                menu = {
                    auto_show = true,
                    border = "rounded",

                    draw = {
                        components = {
                            kind_icon = {
                                text = function(ctx)
                                    if vim.tbl_contains({ "Path" }, ctx.source_name) then
                                        local mini_icon, _ = require("mini.icons").get_icon(ctx.item.data.type, ctx
                                            .label)
                                        if mini_icon then return mini_icon .. ctx.icon_gap end
                                    end

                                    local icon = require("lspkind").symbolic(ctx.kind, { mode = "symbol" })
                                    return icon .. ctx.icon_gap
                                end,

                                -- Optionally, use the highlight groups from mini.icons
                                -- You can also add the same function for `kind.highlight` if you want to
                                -- keep the highlight groups in sync with the icons.
                                highlight = function(ctx)
                                    if vim.tbl_contains({ "Path" }, ctx.source_name) then
                                        local mini_icon, mini_hl = require("mini.icons").get_icon(ctx.item.data.type,
                                            ctx.label)
                                        if mini_icon then return mini_hl end
                                    end
                                    return ctx.kind_hl
                                end,
                            },
                            kind = {
                                -- Optional, use highlights from mini.icons
                                highlight = function(ctx)
                                    if vim.tbl_contains({ "Path" }, ctx.source_name) then
                                        local mini_icon, mini_hl = require("mini.icons").get_icon(ctx.item.data.type,
                                            ctx.label)
                                        if mini_icon then return mini_hl end
                                    end
                                    return ctx.kind_hl
                                end,
                            }
                        }
                    }
                },
            },
        },
        opts_extend = { "sources.default" },
    },
}
