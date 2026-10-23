return {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    version = "*",
    dependencies = { "nvim-mini/mini.icons" },
    keys = {
        { "<leader>j", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file tree" },
    },
    config = function()
        -- Like Emacs dired `!`: run a Como compile in the node's directory.
        -- A standalone `*` is replaced by the file name, otherwise it is appended.
        local function compile_on_node()
            local node = require("nvim-tree.api").tree.get_node_under_cursor()
            if not node or not node.absolute_path then
                return
            end
            local como = require("como")
            local name = vim.fn.shellescape(vim.fs.basename(node.absolute_path))
            vim.cmd.cd(vim.fs.dirname(node.absolute_path))
            vim.ui.input({
                prompt = "Compile command on " .. name .. ": ",
                completion = "customlist,v:lua.como_shellcmdline_complete",
            }, function(cmd)
                if not cmd or cmd == "" then
                    return
                end
                local padded = " " .. cmd .. " "
                if padded:find(" %* ") then
                    cmd = vim.trim((padded:gsub(" %*%f[ ]", " " .. name)))
                else
                    cmd = cmd .. " " .. name
                end
                como.compile(cmd)
            end)
        end

        require("nvim-tree").setup({
            on_attach = function(bufnr)
                local api = require("nvim-tree.api")
                api.map.on_attach.default(bufnr)
                vim.keymap.set("n", "!", compile_on_node, { buffer = bufnr, desc = "Compile on file" })
            end,
            git = {
                enable = true,
                ignore = false,
                -- timeout = 500,
            },
            view = {
                side = "right",
                width = 50,
            },
            filters = {
                dotfiles = false,
            },
        })
    end
}
