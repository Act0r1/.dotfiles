-- ============================================================================
-- BOOTSTRAP LAZY.NVIM
-- ============================================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- LEADER KEY
-- ============================================================================

vim.g.mapleader = " "

-- ============================================================================
-- UI & DISPLAY OPTIONS
-- ============================================================================

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 8
vim.opt.termguicolors = true
vim.opt.laststatus = 3
vim.opt.showcmd = true
vim.opt.cmdheight = 1
vim.opt.spell = false
vim.cmd(":hi statusline guibg=NONE")

vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

-- ============================================================================
-- INDENTATION & TABS
-- ============================================================================

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- ============================================================================
-- FILE HANDLING
-- ============================================================================

vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand("~/.vim/undodir")
vim.opt.autoread = true
vim.opt.autowrite = false

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- ============================================================================
-- FOLDING
-- ============================================================================

vim.opt.foldlevel = 40
vim.opt.foldlevelstart = 1
vim.opt.foldnestmax = 100

-- ============================================================================
-- SHELL & SYSTEM
-- ============================================================================

vim.opt.shellcmdflag = "-ic"
vim.opt.clipboard = "unnamedplus"

-- ============================================================================
-- TIMING
-- ============================================================================

vim.opt.updatetime = 300
vim.opt.timeoutlen = 500
vim.opt.ttimeoutlen = 0

-- ============================================================================
-- BEHAVIOR SETTINGS
-- ============================================================================

vim.opt.hidden = true
vim.opt.errorbells = false
vim.opt.backspace = "indent,eol,start"
vim.opt.autochdir = false
vim.opt.iskeyword:append("-")
vim.opt.path:append("**")
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- ============================================================================
-- SPLIT BEHAVIOR
-- ============================================================================

vim.opt.splitright = true
vim.opt.splitbelow = true

-- ============================================================================
-- DIAGNOSTICS
-- ============================================================================

vim.diagnostic.config({
	float = {
		border = "rounded",
	},
	virtual_text = true,
	signs = true,
})

-- ============================================================================
-- PLUGIN SPECIFIC SETTINGS
-- ============================================================================

vim.g.lazygit_floating_window_winblend = 0

vim.g.VM_maps = {
	["I BS"] = "",
}

-- ============================================================================
-- SETUP LAZY.NVIM
-- ============================================================================

require("lazy").setup({
	spec = {
		{
			import = "plugins",
		},
	},
	checker = { enabled = false },
	change_detection = { enabled = false },
	ui = { notify = false },
})
