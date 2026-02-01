return {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    config = function()
        local mc = require("multicursor-nvim")
        mc.setup()

        local set = vim.keymap.set

        -- Add or skip cursor above/below the main cursor.
        set({ "n", "x" }, "<A-k>", function()
            mc.lineAddCursor(-1)
        end)
        set({ "n", "x" }, "<A-j>", function()
            mc.lineAddCursor(1)
        end)
        set("n", "<c-leftmouse>", mc.handleMouse)
        set("n", "<c-leftdrag>", mc.handleMouseDrag)
        set("n", "<c-leftrelease>", mc.handleMouseRelease)

        -- Как Ctrl+D в VS Code: выделяет слово под курсором и добавляет следующие совпадения
        set({ "n", "x" }, "<leader>n", function()
            local mode = vim.fn.mode()
            if mode == "n" then
                -- В normal mode: сначала выделить слово под курсором
                vim.cmd("normal! viw")
            end
            mc.matchAddCursor(1)
        end)
        set({ "n", "x" }, "<leader>sk", function() mc.matchSkipCursor(1) end)

        set({ "n", "x" }, "<leader>NK", function() mc.matchAddCursor(-1) end)
        set({ "n", "x" }, "<leader>SK", function() mc.matchSkipCursor(-1) end)

        -- Skip cursor (пропустить строку): Alt+Shift+k/j
        set({ "n", "x" }, "<A-S-k>", function()
            mc.lineSkipCursor(-1, { skimEmpty = true })
        end)
        set({ "n", "x" }, "<A-S-j>", function()
            mc.lineSkipCursor(1, { skimEmpty = true })
        end)

        -- Mappings defined in a keymap layer only apply when there are
        -- multiple cursors. This lets you have overlapping mappings.
        mc.addKeymapLayer(function(layerSet)
            -- Select a different cursor as the main one.
            layerSet({ "n", "x" }, "<left>", mc.prevCursor)
            layerSet({ "n", "x" }, "<right>", mc.nextCursor)

            -- Delete the main cursor.
            layerSet({ "n", "x" }, "<leader>x", mc.deleteCursor)

            -- Enable and clear cursors using escape.
            layerSet("n", "<esc>", function()
                if not mc.cursorsEnabled() then
                    mc.enableCursors()
                else
                    mc.clearCursors()
                end
            end)
        end)

        -- Customize how cursors look.
        local hl = vim.api.nvim_set_hl
        hl(0, "MultiCursorCursor", { reverse = true })
        hl(0, "MultiCursorVisual", { link = "Visual" })
        hl(0, "MultiCursorSign", { link = "SignColumn" })
        hl(0, "MultiCursorMatchPreview", { link = "Search" })
        hl(0, "MultiCursorDisabledCursor", { reverse = true })
        hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
        hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
    end,
}
