-- ---------------------------------------------------------------------
-- KOMPANION NEOVIM CONFIGURATION
--
-- About Neovim defaults
-- =====================
-- 1. 'nocompatible' is not needed (always set by default)
-- 1. 'syntax on' and 'filetype plugin indent on' are enabled
--
-- Important
-- =========
-- I have decided that I will only load things EXPLICITLY added to the
-- custom Kompanion enviroment variables. This is reflected in the use
-- of `getenv` calls below.
--
-- ---------------------------------------------------------------------

print('Loading Kompanion Neovim configuration...')

-- ---------------------------------------------------------------------
-- FUNCTIONS
-- ---------------------------------------------------------------------

-- TODO: automate the following installations:
-- pip install neovim
-- npm -g install neovim

function configure_python()
    local python_path = os.getenv('PYTHON_HOME')

    if python_path ~= nil then
        python_path = python_path .. '/python.exe'
        vim.g.python3_host_prog = python_path
    else
        vim.g.loaded_python3_provider = 0
    end
end

function configure_node()
    local node_path = os.getenv('NODE_HOME')

    if node_path == nil then
        vim.g.loaded_node_provider = 0
    end
end

-- ---------------------------------------------------------------------
-- GENERAL
-- ---------------------------------------------------------------------

-- Set space as the leader key
vim.g.mapleader = ' '

-- Disable perl
vim.g.loaded_perl_provider = 0

-- Disable ruby
vim.g.loaded_ruby_provider = 0

-- Python 3 host program
configure_python()

-- Node host program
configure_node()

-- ---------------------------------------------------------------------
-- COMMANDS
-- ---------------------------------------------------------------------

-- Enable syntax highlighting (redundant in Neovim but harmless)
vim.cmd('syntax on')

-- Enable filetype detection, plugins, and indentation rules
vim.cmd('filetype plugin indent on')

-- ---------------------------------------------------------------------
-- CONFIG
-- ---------------------------------------------------------------------

require('config.lsp')
require('config.opt')
require('config.keymap')

-- This comes last as it overrides some of the above settings
require('config.lazy')

-- ---------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------