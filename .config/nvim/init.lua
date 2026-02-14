-- Clone 'mini.nvim' manually in a way that it gets managed by 'mini.deps'
local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
if not vim.loop.fs_stat(mini_path) then
  vim.cmd('echo "Installing `mini.nvim`" | redraw')
  local clone_cmd = {
    'git', 'clone', '--filter=blob:none',
    'https://github.com/nvim-mini/mini.nvim', mini_path
  }
  vim.fn.system(clone_cmd)
  vim.cmd('packadd mini.nvim | helptags ALL')
  vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

-- Set up 'mini.deps' (customize to your liking)
require('mini.deps').setup({ path = { package = path_package } })

-- Use 'mini.deps'. `now()` and `later()` are helpers for a safe two-stage
-- startup and are optional.
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

tslangs = { 'bash', 'cmake', 'make', 'markdown', 'lua', 'git_config', 'gitignore', 'c', 'cpp', 'python' }
now(function()
  add({
    source = 'nvim-telescope/telescope.nvim',
    depends = { 'nvim-lua/plenary.nvim'},
  })
  add({
    source = 'nvim-telescope/telescope-ui-select.nvim',
    depends = { 'nvim-telescope/telescope.nvim'},
  })
end)
later(function()
  add({
    source = 'nvim-treesitter/nvim-treesitter',
    -- Use 'master' while monitoring updates in 'main'
    checkout = 'master',
    monitor = 'main',
    -- Perform action after every checkout
    hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
  })
  add({
    source = 'neovim/nvim-lspconfig',
  })
  add(
    {
    source = "nvzone/typr",
    depends = {"nvzone/volt"},
}
  )

  -- Possible to immediately execute code which depends on the added plugin
  require('nvim-treesitter.configs').setup({
    ensure_installed = tslangs,
    highlight = { enable = true },
  })
end)

-- This is your opts table
require("telescope").setup {
  defaults = {
    mappings = {
      i = {
        ['<C-u>'] = false,
        ['<C-d>'] = false,
      },
    },
  },
  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_dropdown {
        -- even more opts
      }

      -- pseudo code / specification for writing custom displays, like the one
      -- for "codeactions"
      -- specific_opts = {
      --   [kind] = {
      --     make_indexed = function(items) -> indexed_items, width,
      --     make_displayer = function(widths) -> displayer
      --     make_display = function(displayer) -> function(e)
      --     make_ordinal = function(e) -> string
      --   },
      --   -- for example to disable the custom builtin "codeactions" display
      --      do the following
      --   codeactions = false,
      -- }
    }
  }
}

vim.api.nvim_create_autocmd('FileType', {
	pattern = tslangs, 
	callback = function() vim.treesitter.start() end,
})

vim.lsp.enable({'pylsp', 'clangd', 'lua_ls', 'marksman'})
vim.lsp.config['clangd'] = {
  cmd = { 'clangd', '--background-index', '--clang-tidy', '--completion-style=detailed', '--header-insertion=never' },
  filetypes = { 'c', 'cpp' },
  root_markers = { '.clangd', '.clang-tidy', '.clang-format', 'compile_commands.json', 'compile_flags.txt', '.git' },
}
vim.lsp.config['pylsp'] = {
  cmd = {'pylsp'},
  filetypes = {'python'},
  root_markers = { ".git", "__init__.py"},
  plugins = {
    ruff = {
      enabled = true,
      formatEnabled = true,
    },
    pycodestyle = { enabled = false },
    pyflakes = { enabled = false },
    mccabe = { enabled = false },
    autopep8 = { enabled = false },
    yapf = { enabled = false },
  }
}
----------------------------------------
-- :help [anything]
-- <Ctrl>] to dive on help links in neovim

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.expandtab = true
vim.o.smartindent = true
vim.o.winborder = "rounded"

vim.o.swapfile = false
vim.o.mouse = 'a'
vim.o.undofile = true

vim.o.relativenumber = true
vim.o.number = true
vim.o.wrap = false
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.colorcolumn = "100"
vim.o.errorbells = false

-- menu completion, wildmenu defaults to on/true, but putting here so I recall what it does
vim.o.wildmenu = true
vim.o.wildmode = "longest:full,full"

-- move lines
vim.keymap.set("n", "<C-k>", ":m -2<CR>", {desc="Move line down"})
vim.keymap.set("n", "<C-j>", ":m +1<CR>", {desc="Move line up"})
vim.keymap.set("v", "<C-k>", ":m '<-2<CR>gv", {desc="Move line down"})
vim.keymap.set("v", "<C-j>", ":m '>+1<CR>gv", {desc="Move line up"})

-- Performance
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Search
vim.o.hlsearch = true
vim.o.incsearch = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.completeopt = "fuzzy,menuone,preview"

-- builtin colors is one less plugin to deal with
-- my favs are [ retrobox | unokai ]
vim.cmd.colorscheme("unokai")

vim.keymap.set("n", "<Leader>er", "<cmd>edit $MYVIMRC<CR>", { desc = "Edit Neovim config" })
vim.keymap.set("n", "<Leader>sr", "<cmd>so $MYVIMRC<CR>", { desc = "Source Neovim config"})
vim.keymap.set("n", "<Leader>w", ":w<CR>", {desc = "Save file quickly", noremap=true})

-- keymaps for the terminal
-- I like <C-W>... well not really... but also yes.
vim.keymap.set("t", "<C-W>j", "<C-\\><C-n><C-w>j", {noremap=true})
vim.keymap.set("t", "<C-W>k", "<C-\\><C-n><C-w>k", {noremap=true})
vim.keymap.set("t", "<C-W>h", "<C-\\><C-n><C-w>h", {noremap=true})
vim.keymap.set("t", "<C-W>l", "<C-\\><C-n><C-w>l", {noremap=true})
-- vim.keymap.set("t", "<ESC>", "<C-\\><C-n>", {noremap=true})

vim.keymap.set("n", "<Leader>lf", vim.lsp.buf.format, {desc = "Format current buffer"})
vim.keymap.set("n", "<Leader>li", vim.lsp.buf.code_action, {desc = "LSP code action (includes, fixes)"})

require("telescope").load_extension("ui-select")
local function telescope_live_grep_open_files()
  require('telescope.builtin').live_grep {
    grep_open_files = true,
    prompt_title = 'Live Grep in Open Files',
  }
end
vim.keymap.set('n', '<leader>s/', telescope_live_grep_open_files, { desc = '[S]earch [/] in Open Files' })
vim.keymap.set('n', '<leader>ss', require('telescope.builtin').builtin, { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set('n', '<leader>gf', require('telescope.builtin').git_files, { desc = 'Search [G]it [F]iles' })
vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', require('telescope.builtin').resume, { desc = '[S]earch [R]esume' })

--------------------------------------------------
-- hooks for switching modes from personal dev to pairing and back
develop_mode = function()
  vim.wo.relativenumber = true
  vim.wo.number = true
  vim.wo.cursorline = true
  vim.wo.cursorcolumn = false
end
vim.api.nvim_create_user_command("DevMode", "lua develop_mode()", {})
--
pairing_mode = function()
  vim.wo.relativenumber = false
  vim.wo.number = true
  vim.wo.cursorline = true
  vim.wo.cursorcolumn = true
end vim.api.nvim_create_user_command("PairMode", "lua pairing_mode()", {})
--
blank_mode = function()
  vim.wo.relativenumber = false
  vim.wo.number = false
  vim.wo.cursorline = false
  vim.wo.cursorcolumn = false
end
vim.api.nvim_create_user_command("BlankMode", "lua blank_mode()", {})

--------------------------------------------------
-- Language specific abbreviations
local function markdown_abbrevs()
  vim.keymap.set("i", "iitem", "- [ ] ", {buffer=0, noremap=true})
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = markdown_abbrevs,
})

--------------------------------------------------
-- NOTES and other records
-- default records to $HOME since it is usually backed up
--------------------------------------------------
local records_path = os.getenv("RECORDS_HOME") or "${HOME}/records/"

local function user_records(file_name)
  local file = records_path .. file_name
  vim.cmd("tabnew" .. file)
  -- move to end of file
  vim.cmd(":normal G$zz")
end

notes = function()
  user_records("notes.md")
end
vim.api.nvim_create_user_command("Notes", "lua notes()", {})

goals = function()
  user_records("goals.md")
end
vim.api.nvim_create_user_command("Goals", "lua goals()", {})

todo = function()
  user_records("todo.md")
end
vim.api.nvim_create_user_command("Todo", "lua todo()", {})


vim.api.nvim_create_user_command(
  "NewNote",
  function()
    vim.cmd("Notes")
    local date_str = vim.fn.strftime('%Y-%m-%d %H:%M:%S')
    vim.api.nvim_put(
    {
      "",
      "## " .. date_str,
      ""
    }, "l", true, true)
  end,
  {}
)
vim.keymap.set('n', '<Leader>nn', function() vim.cmd('NewNote') end, {})

-- generic tool for injecting date time string blocks
local function goals_injection(prefix, time_code)
  vim.cmd("Goals")
  local date_str = vim.fn.strftime(time_code)
  vim.api.nvim_put(
    {
      "",
      prefix .. date_str,
      ""
    }, "l", true, true)
end

vim.api.nvim_create_user_command(
  "SetGoalsDay",
  function()
    goals_injection("#### Daily Goals: ", '%Y-%m-%d (%a)')
  end,
  {}
)

vim.api.nvim_create_user_command(
  "SetGoalsWeek",
  function()
    goals_injection("### Weekly Goals: ", '%Y-%m (Week %V)')
  end,
  {}
)

vim.api.nvim_create_user_command(
  "SetGoalsMonth",
  function()
    goals_injection("## Month Goals: ", '%Y-%m')
  end,
  {}
)

vim.api.nvim_create_user_command(
  "SetGoalsYear",
  function()
    goals_injection("# Year Goals: ", '%Y')
  end,
  {}
)
