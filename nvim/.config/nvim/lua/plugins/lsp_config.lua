return {
    {
        "neovim/nvim-lspconfig",
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
            local rust_threads = 2
            if vim.uv and vim.uv.available_parallelism then
                local ok, parallelism = pcall(vim.uv.available_parallelism)
                if ok and type(parallelism) == "number" then
                    rust_threads = math.min(4, math.max(2, math.floor(parallelism / 4)))
                end
            end

            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        diagnostics = {
                            disable = { "missing-fields" },
                        },
                    },
                },
            })

            vim.lsp.config("basedpyright", {
                settings = {
                    basedpyright = {
                        analysis = {
                            autoSearchPaths = true,
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
                                reportExplicitAny = "none",
                                reportUnusedCoroutine = false,
                            },
                        },
                    },
                },
            })

            vim.lsp.config("rust_analyzer", {
                settings = {
                    ["rust-analyzer"] = {
                        cargo = {
                            allTargets = false,
                        },
                        procMacro = {
                            enable = false,
                        },
                        check = {
                            command = "check",
                            allTargets = false,
                            extraArgs = { "-j", tostring(rust_threads) },
                        },
                        cachePriming = {
                            numThreads = rust_threads,
                        },
                        index = {
                            depsOnlyPublicItems = true,
                        },
                        lru = {
                            capacity = 128,
                        },
                    },
                },
            })

            vim.lsp.config("gopls", {
                settings = {
                    gopls = {
                        completeUnimported = true,
                        usePlaceholders = true,
                        analyses = {
                            unusedparams = true,
                        },
                    },
                },
            })

            vim.lsp.enable("lua_ls")
            vim.lsp.enable("basedpyright")
            vim.lsp.enable("rust_analyzer")
            vim.lsp.enable("gopls")
            vim.lsp.enable("ts_ls")
            vim.lsp.enable("zls")
            vim.lsp.enable("tailwindcss")
            vim.lsp.enable("cssls")
            vim.lsp.enable("astro")
            vim.lsp.enable("clangd")
            vim.lsp.enable("ruff")
            vim.lsp.enable("docker_compose_language_service")

            vim.api.nvim_create_user_command("LspRestart", function(args)
                vim.cmd("lsp restart " .. (args.args or ""))
            end, { nargs = "?", desc = "Restart LSP (0.12 shim for :lsp restart)" })

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("userlspconfig", { clear = true }),
                callback = function(ev)
                    local opts = { buffer = ev.buf }
                    vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

                    vim.keymap.set({ "n", "x" }, "<leader>ca",
                        '<cmd>lua require("fastaction").code_action()<CR>',
                        { desc = "Code actions", buffer = ev.buf })
                    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
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

                    if vim.bo[ev.buf].filetype == "lua" then
                        vim.api.nvim_create_autocmd("BufWritePre", {
                            buffer = ev.buf,
                            callback = function()
                                vim.lsp.buf.format({ bufnr = ev.buf, id = ev.data.client_id })
                            end,
                        })
                    end
                end,
            })
        end,
    },
}
