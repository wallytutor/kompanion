-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ---------------------------------------------------------------------
-- UI / Editing Comfort
-- ---------------------------------------------------------------------

-- Show absolute line numbers
-- vim.opt.number = true

-- Show relative numbers for efficient movement (j/k)
-- vim.opt.relativenumber = true

-- Highlight the current line for better focus
-- vim.opt.cursorline = true

-- Enable true color support in terminals that support it
-- vim.opt.termguicolors = true

-- ---------------------------------------------------------------------
-- Indentation, Tabs, and Text
-- ---------------------------------------------------------------------

-- Number of spaces a <Tab> counts for
-- vim.opt.tabstop = 4

-- Number of spaces used for autoindent and << >>
-- vim.opt.shiftwidth = 4

-- Convert tabs to spaces
-- vim.opt.expandtab = true

-- Enable smart indentation based on syntax
-- vim.opt.smartindent = true

-- Wrap long lines instead of cutting them visually
-- vim.opt.wrap = true

-- Break wrapped lines at word boundaries, not mid‑word
-- vim.opt.linebreak = true

-- ---------------------------------------------------------------------
-- Search Behavior
-- ---------------------------------------------------------------------

-- Case-insensitive search by default
-- vim.opt.ignorecase = true

-- But if the search contains uppercase, make it case-sensitive
-- vim.opt.smartcase = true

-- Highlight search matches
-- vim.opt.hlsearch = true

-- Show matches as you type
-- vim.opt.incsearch = true

-- ---------------------------------------------------------------------
-- Clipboard & Mouse
-- ---------------------------------------------------------------------

-- Enable mouse support in all modes
-- vim.opt.mouse = 'a'

-- Use the system clipboard for all yank/paste operations
-- vim.opt.clipboard = 'unnamedplus'

-- ---------------------------------------------------------------------
-- CODE FOLDING
-- ---------------------------------------------------------------------

-- Set foldmarker, so Vim will know where to fold
-- vim.opt.foldmethod = 'marker'
-- vim.opt.foldmarker = '#region,#endregion'

-- ---------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------