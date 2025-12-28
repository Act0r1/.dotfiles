return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            inlay_hints = {
                enabled = true,
            },
        },
        dependencies = {
            "saghen/blink.cmp",
            {
                "folke/lazydev.nvim",
                opts = {
                    library = {
                        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
                    },
                },
            },
        },

        config = function()
            local cap_lsp = vim.lsp.protocol.make_client_capabilities()
            local capabilities = require("blink.cmp").get_lsp_capabilities(cap_lsp)
            -- require("lspconfig").lua_ls.setup({ capabilites = capabilities })
            vim.lsp.enable("lua_ls")
            vim.lsp.config("lua_ls", {
                settings = {
                    ["lua_ls"] = {
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                diagnostics = {
                                    disable = { "missing-fields" },
                                },
                            },
                        },
                    },
                },
            })
            vim.lsp.enable("tailwindcss")
            vim.lsp.enable("dockerls")
            vim.lsp.enable("cssls")

            -- require("lspconfig").cssls.setup({
            --     cmd = { "vscode-css-language-server", "--stdio" },
            --     filetypes = { "css" },
            -- })

            vim.lsp.enable("basedpyright")
            vim.lsp.config("basedpyright", {
                capabilites = capabilities,
                settings = {
                    basedpyright = {
                        analysis = {
                            autoSearchPaths = true,
                            -- ignore = { "*" },
                            disableOrganizeImports = true,
                            useLibraryCodeForTypes = true,
                            typeCheckingMode = "standard",
                            autoImportCompletions = true,
                            diagnosticMode = "workspace",
                            inlayHints = {
                                enabled = true,
                            },
                            diagnosticSeverityOverrides = {
                                reportCallIssue = "none",
                                reportUnusedCoroutine = true,
                            },
                        },
                    },
                },
            })

            vim.lsp.enable("ts_ls")
            vim.lsp.enable("zls")
            vim.lsp.enable("rust_analyzer")
            vim.lsp.enable("gopls")
            vim.lsp.enable("zls")

            vim.lsp.config("gopls", {
                settings = {
                    ["gopls"] = {
                        capabilities = capabilities,
                        cmd = { "gopls" },
                        filetypes = { "go", "gomod", "gowork", "gotmpl" },
                        -- root_dir = util.root_pattern("go.work", "go.mod", ".git"),
                        settings = {
                            gopls = {
                                completeUnimported = true,
                                usePlaceholders = true,
                                analyses = {
                                    unusedparams = true,
                                },
                            },
                        },
                    },
                },
            })
            vim.lsp.enable("biome")
            vim.lsp.enable("docker_compose_language_service")
            vim.lsp.enable("clangd", true) --.setup({ capabilites = capabilities })
            -- vim.lsp.enable("ty", true)
            vim.lsp.enable("ruff", true)
            -- vim.lsp.enable("zls", true)
            vim.api.nvim_create_autocmd("lspattach", {
                group = vim.api.nvim_create_augroup("userlspconfig", {}),
                callback = function(ev)
                    vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
                    local opts = { buffer = ev.buf }
                    vim.keymap.set(
                        { "n", "x" },
                        "<leader>ca",
                        '<cmd>lua require("fastaction").code_action()<CR>',
                        { desc = "Display code actions", buffer = ev.buf }
                    )
                    vim.keymap.set("n", "gd", vim.lsp.buf.declaration, opts)
                    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                    vim.keymap.set("n", "<c-]>", vim.lsp.buf.hover, opts)
                    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
                    vim.keymap.set("n", "<c-k>", vim.lsp.buf.signature_help, opts)
                    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
                    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
                    vim.keymap.set("n", "<space>wl", vim.lsp.buf.list_workspace_folders, opts)
                    vim.keymap.set("n", "<space>td", vim.lsp.buf.type_definition, opts)
                    vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
                    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
                end,
            })

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local c = vim.lsp.get_client_by_id(args.data.client_id)
                    if not c then
                        return
                    end

                    if vim.bo.filetype == "lua" then
                        vim.api.nvim_create_autocmd("BufWritePre", {
                            buffer = args.buf,
                            callback = function()
                                vim.lsp.buf.format({ bufnr = args.buf, id = c.id })
                            end,
                        })
                    end
                end,
            })
        end,
    },
}
