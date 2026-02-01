local M = {}

M.config = {
  enabled = true,
  modes = { "n", "v", "o", "x" }, -- Normal, Visual, Operator-pending, Visual block
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.enabled then
    M.apply_mappings()
  end
end

function M.apply_mappings()
  local mappings = require("mappings")

  for rus, eng in pairs(mappings.chars) do
    for _, mode in ipairs(M.config.modes) do
      vim.keymap.set(mode, rus, eng, { remap = true, silent = true })
    end
  end

  -- Текстовые объекты (работают в operator-pending и visual)
  for rus, eng in pairs(mappings.text_objects) do
    vim.keymap.set({ "o", "x" }, rus, eng, { remap = true, silent = true })
  end

  -- Ctrl комбинации
  for rus, eng in pairs(mappings.ctrl) do
    for _, mode in ipairs(M.config.modes) do
      vim.keymap.set(mode, rus, eng, { remap = true, silent = true })
    end
  end

  -- Команды (русские алиасы через аббревиатуры)
  vim.cmd([[
    cabbrev ц w
    cabbrev й q
    cabbrev цй wq
    cabbrev йф qa
    cabbrev й! q!
    cabbrev йф! qa!
  ]])
end

return M
