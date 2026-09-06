return {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    keys = {
        {
            "<A-k>",
            function()
                require("multicursor-nvim").lineAddCursor(-1)
            end,
            mode = "n",
            desc = "Add cursor above",
        },
        {
            "<A-j>",
            function()
                require("multicursor-nvim").lineAddCursor(1)
            end,
            mode = "n",
            desc = "Add cursor below",
        },
        {
            "<c-leftmouse>",
            function()
                require("multicursor-nvim").handleMouse()
            end,
            desc = "Add cursor with mouse",
        },
        {
            "<c-leftdrag>",
            function()
                require("multicursor-nvim").handleMouseDrag()
            end,
            desc = "Drag multicursor selection",
        },
        {
            "<c-leftrelease>",
            function()
                require("multicursor-nvim").handleMouseRelease()
            end,
            desc = "Finish multicursor selection",
        },
        {
            "<leader>n",
            function()
                require("multicursor-nvim").matchAddCursor(1)
            end,
            mode = { "n", "x" },
            desc = "Add cursor at next match",
        },
        {
            "<leader>sk",
            function()
                require("multicursor-nvim").matchSkipCursor(1)
            end,
            mode = { "n", "x" },
            desc = "Skip next multicursor match",
        },
        {
            "<leader>NK",
            function()
                require("multicursor-nvim").matchAddCursor(-1)
            end,
            mode = { "n", "x" },
            desc = "Add cursor at previous match",
        },
        {
            "<leader>SK",
            function()
                require("multicursor-nvim").matchSkipCursor(-1)
            end,
            mode = { "n", "x" },
            desc = "Skip previous multicursor match",
        },
        {
            "<A-S-k>",
            function()
                require("multicursor-nvim").lineSkipCursor(-1, { skimEmpty = true })
            end,
            mode = { "n", "x" },
            desc = "Skip multicursor line above",
        },
        {
            "<A-S-j>",
            function()
                require("multicursor-nvim").lineSkipCursor(1, { skimEmpty = true })
            end,
            mode = { "n", "x" },
            desc = "Skip multicursor line below",
        },
    },
    config = function()
        local mc = require("multicursor-nvim")
        mc.setup()

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
