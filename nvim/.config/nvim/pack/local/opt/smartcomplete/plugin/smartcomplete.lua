-- smartcomplete.nvim - AI-powered code completion for Neovim
-- Entry point for the plugin

if vim.g.loaded_smartcomplete then
  return
end
vim.g.loaded_smartcomplete = true

-- Check Neovim version
if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("smartcomplete.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end

-- Create user command
vim.api.nvim_create_user_command("Smartcomplete", function(opts)
  -- Ensure setup is done
  local sc = require("smartcomplete")
  if not sc._setup_done then
    sc.setup()
  end
  require("smartcomplete.commands").execute(opts.args)
end, {
  nargs = "*",
  complete = function(_, line)
    return require("smartcomplete.commands").complete(line)
  end,
  desc = "Smartcomplete commands",
})

-- Lazy setup on first InsertEnter if auto_setup is not disabled
vim.api.nvim_create_autocmd("InsertEnter", {
  once = true,
  callback = function()
    if vim.g.smartcomplete_disable_auto_setup ~= true then
      local ok, sc = pcall(require, "smartcomplete")
      if ok and not sc._setup_done then
        sc.setup()
      end
    end
  end,
})
