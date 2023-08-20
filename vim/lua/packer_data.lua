
-- Bootstrap packer
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  use('wbthomason/packer.nvim')
  -- My plugins here
  use('nvim-lua/plenary.nvim')
  use('nvim-lua/popup.nvim')
  use('nvim-treesitter/nvim-treesitter')
  use('nvim-telescope/telescope.nvim')
  use('gruvbox-community/gruvbox')
  use('tpope/vim-commentary')
  use('tpope/vim-fugitive')
  use('tpope/vim-abolish')
  use('mileszs/ack.vim')
  use({
    "iamcco/markdown-preview.nvim",
    run = function() vim.fn["mkdp#util#install"]() end,
})
                                      
  use('neovim/nvim-lspconfig')        
  use('hrsh7th/cmp-nvim-lsp')         
  use('hrsh7th/cmp-buffer')           
  use('hrsh7th/cmp-path')             
  use('hrsh7th/cmp-cmdline')
  use('hrsh7th/nvim-cmp')             
                                      
  use('hrsh7th/cmp-vsnip')
  use('hrsh7th/vim-vsnip')

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
