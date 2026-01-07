return {
    dir = "~/Personal/cvim", -- or your path
    config = function()
        require("smartcomplete").setup({
            provider = "anthropic", -- or "openrouter"
            -- API keys from env vars: ANTHROPIC_API_KEY, OPENROUTER_API_KEY
        })
    end,

}
