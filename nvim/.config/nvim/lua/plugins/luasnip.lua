-- return {
-- 	"L3MON4D3/LuaSnip",
-- 	-- follow latest release.
-- 	version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
-- 	-- install jsregexp (optional!).
-- 	build = "make install_jsregexp",
-- 	config = function()
-- 		require("luasnip.loaders.from_vscode").lazy_load()
-- 		require("luasnip.loaders.from_vscode").lazy_load({ paths = "~/.config/nvim/snippets" })
return {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build = "make install_jsregexp",
    config = function()
        local ls = require("luasnip")
        local s = ls.snippet
        local f = ls.function_node

        -- Загружаем VSCode сниппеты
        require("luasnip.loaders.from_vscode").lazy_load()
        require("luasnip.loaders.from_vscode").lazy_load({ paths = "~/.config/nvim/snippets" })

        -- Динамический pyinit сниппет
        ls.add_snippets("python", {
            s("pyinit", {
                f(function()
                    local line = vim.api.nvim_get_current_line()
                    local params = line:match("__init__%(self,%s*(.-)%)")
                    if not params then return "" end

                    local result = {}
                    for param in params:gmatch("[^,]+") do
                        param = param:match("^%s*(.-)%s*$")
                        param = param:match("^([^:=]+)")
                        if param then
                            param = param:match("^%s*(.-)%s*$")
                            table.insert(result, "        self." .. param .. " = " .. param)
                        end
                    end

                    return result
                end, {})
            }),
        })

        -- Настройка расширения
        ls.config.set_config({
            history = true,
            updateevents = "TextChanged,TextChangedI",
        })
    end,
} -- 	end,
