-- :help [anything]
-- <Ctrl>] to dive on help links in neovim

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.o.swapfile = false
vim.o.mouse = 'a'
vim.o.undofile = true

vim.o.relativenumber = true
vim.o.number = true
vim.o.wrap = false
vim.o.cursorline = true

-- Performance 
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Search
vim.o.hlsearch = true
vim.o.incsearch = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.completeopt = "fuzzy,menuone,preview"

vim.cmd.colorscheme("industry")

-- hooks for switching modes from personal dev to pairing and back
develop_mode = function()
  vim.wo.relativenumber = true
  vim.wo.number = true
  vim.wo.cursorline = false
  vim.o.hlsearch = false
end
vim.api.nvim_create_user_command("DevMode", "lua develop_mode()", {})
--
pairing_mode = function()
  vim.wo.relativenumber = false
  vim.wo.number = true
  vim.wo.cursorline = true
  vim.o.hlsearch = true
end
vim.api.nvim_create_user_command("PairMode", "lua pairing_mode()", {})
