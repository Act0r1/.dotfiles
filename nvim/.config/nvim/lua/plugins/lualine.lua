return {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- For icons
    opts = function()
        -- Define colors
        -- local colors = {
        --   blue   = '#80a0ff',
        --   cyan   = '#79dac8',
        --   black  = '#080808',
        --   white  = '#c6c6c6',
        --   red    = '#ff5189',
        --   violet = '#d183e8',
        --   grey   = '#303030',
        -- }
        --
        -- -- Define the Bubbles theme
        -- local bubbles_theme = {
        --   normal = {
        --     a = { fg = colors.black, bg = colors.violet },
        --     b = { fg = colors.white, bg = colors.grey },
        --     c = { fg = colors.black, bg = colors.black },
        --   },
        --   insert = { a = { fg = colors.black, bg = colors.blue } },
        --   visual = { a = { fg = colors.black, bg = colors.cyan } },
        --   replace = { a = { fg = colors.black, bg = colors.red } },
        --   inactive = {
        --     a = { fg = colors.white, bg = colors.black },
        --     b = { fg = colors.white, bg = colors.black },
        --     c = { fg = colors.black, bg = colors.black },
        --   },
        -- }

        -- Return lualine configuration
        return {
            options = {
                -- theme = "auto",
                component_separators = "|",
                section_separators = { left = "", right = "" },
            },
            sections = {
                lualine_a = {
                    { "mode", separator = { left = "" }, right_padding = 2 },
                    {

                        "filetype",
                        colored = false,            -- Displays filetype icon in color if set to true
                        icon_only = true,           -- Display only an icon for filetype
                        icon = { align = "right" }, -- Display filetype icon on the right hand side
                        right_padding = 2,
                    },
                },
                lualine_b = {
                    {
                        "filename",
                        path = 1,
                        symbols = {
                            modified = "●",
                            readonly = "",
                            unnamed = "",
                        },
                    },
                    "branch",
                },
                lualine_c = {
                    {
                        "fileformat",
                        symbols = {
                            unix = "", -- e712
                            dos = "", -- e70f
                            mac = "", -- e711
                        },
                    },
                },
                lualine_x = {
                    { "diagnostics", sources = { "nvim_lsp" } }, -- Display LSP diagnostics
                },
                lualine_y = { "filetype", "progress" },
                lualine_z = {
                    { "location", separator = { right = "" }, left_padding = 2 },
                },
            },
            inactive_sections = {
                lualine_a = { "filename" },
                lualine_b = {},
                lualine_c = {},
                lualine_x = {},
                lualine_y = {},
                lualine_z = { "location" },
            },
            tabline = {},
            extensions = {},
        }
    end,
    event = "VeryLazy", -- Load lualine lazily
}
