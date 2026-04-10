-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

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
-- vim.cmd('syntax on')

-- Enable filetype detection, plugins, and indentation rules
-- vim.cmd('filetype plugin indent on')

-- vim.lsp.enable('pyrefly')
-- vim.lsp.enable('rust_analyzer')

-- Load options configuration
-- require('config.options')

-- Load keybindings configuration
-- require('config.keymap')

-- ---------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------