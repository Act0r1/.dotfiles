return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    ---@module "ibl"
    ---@type ibl.config
    opts = {
        indent = { char = "│" },
        scope = {
            enabled = true,
            show_start = false,
            show_end = false,
            include = {
                node_type = {
                    ["*"] = { "*" },
                },
            },
        },
    },
    config = function(_, opts)
        local hooks = require("ibl.hooks")
        hooks.register(hooks.type.SKIP_LINE, function(_, _, _, line)
            return line:match("^%s*$") ~= nil
        end)
        require("ibl").setup(opts)
    end,
    enabled = true,
}
