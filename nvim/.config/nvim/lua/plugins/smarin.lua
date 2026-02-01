return {
    dir = vim.fn.stdpath("config") .. "/pack/local/opt/smartcomplete",
    enabled = false,
    config = function()
        require("smartcomplete").setup({
            provider = "anthropic", -- or "openrouter"
            -- API keys from env vars: ANTHROPIC_API_KEY, OPENROUTER_API_KEY
        })
    end,
}
