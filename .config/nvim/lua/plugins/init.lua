return {
  -- Git related plugins
  -- 'tpope/vim-abolish (not currently using but plan to revisit)
  'tpope/vim-fugitive',
  'tpope/vim-commentary',
  'tpope/vim-rhubarb',
  'christoomey/vim-tmux-navigator',
  -- countdown timer
  {
  'cbrgm/countdown.nvim',
    opts = {
      default_minutes = 15,
    },
  },

  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',


  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- See `:help lualine.txt`
    opts = {
      options = {
        icons_enabled = false,
        theme = 'onedark',
        component_separators = '|',
        section_separators = '',
      },
    },
    setup = {
      tabline = {
        -- add the timer to the tabline bar
        -- lualine_x = { timer, "encoding", "fileformat", "filetype" },
      },
    },
  },

  {
    -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help ibl`
    main = 'ibl',
    opts = {},
  },

  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim', opts = {} },

}
