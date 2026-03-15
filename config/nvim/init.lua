-- ---------------------------------------------------------------------
-- init.lua - Neovim configuration
-- ---------------------------------------------------------------------

-- About Neovim defaults:
-- Note: 'nocompatible' is not needed (always set by default)
-- Note: 'syntax on' and 'filetype plugin indent on' are enabled

-- ---------------------------------------------------------------------
-- GENERAL
-- ---------------------------------------------------------------------

-- Enable syntax highlighting (redundant in Neovim but harmless)
vim.cmd('syntax on')

-- Enable filetype detection, plugins, and indentation rules
vim.cmd('filetype plugin indent on')

-- ---------------------------------------------------------------------
-- UI / Editing Comfort
-- ---------------------------------------------------------------------

-- Show absolute line numbers
vim.opt.number = true

-- Show relative numbers for efficient movement (j/k)
vim.opt.relativenumber = true

-- Highlight the current line for better focus
vim.opt.cursorline = true

-- Enable true color support in terminals that support it
vim.opt.termguicolors = true

-- ---------------------------------------------------------------------
-- Indentation, Tabs, and Text
-- ---------------------------------------------------------------------

-- Number of spaces a <Tab> counts for
vim.opt.tabstop = 4

-- Number of spaces used for autoindent and << >>
vim.opt.shiftwidth = 4

-- Convert tabs to spaces
vim.opt.expandtab = true

-- Enable smart indentation based on syntax
vim.opt.smartindent = true

-- Wrap long lines instead of cutting them visually
vim.opt.wrap = true

-- Break wrapped lines at word boundaries, not mid‑word
vim.opt.linebreak = true

-- ---------------------------------------------------------------------
-- Search Behavior
-- ---------------------------------------------------------------------

-- Case-insensitive search by default
vim.opt.ignorecase = true

-- But if the search contains uppercase, make it case-sensitive
vim.opt.smartcase = true

-- Highlight search matches
vim.opt.hlsearch = true

-- Show matches as you type
vim.opt.incsearch = true

-- ---------------------------------------------------------------------
-- Clipboard & Mouse
-- ---------------------------------------------------------------------

-- Enable mouse support in all modes
vim.opt.mouse = 'a'

-- Use the system clipboard for all yank/paste operations
vim.opt.clipboard = 'unnamedplus'

-- ---------------------------------------------------------------------
-- LSP CONFIGURATION
-- ---------------------------------------------------------------------

-- vim.lsp.enable('pyrefly')
vim.lsp.enable('rust_analyzer')

-- Show diagnostic popup
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)

-- Navigate diagnostics
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)

-- Show all diagnostics
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

-- LSP actions (when LSP is attached)
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
vim.keymap.set('n', 'K', vim.lsp.buf.hover)
vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename)
vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action)

-- ---------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------
