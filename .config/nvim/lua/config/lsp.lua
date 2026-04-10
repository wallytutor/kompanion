-- LEGACY: all moved to lazy.lua (at least for now)

-- ---------------------------------------------------------------------
-- FUNCTIONS
-- ---------------------------------------------------------------------


-- function install_lspconfig()
--     local root = os.getenv('XDG_CONFIG_HOME')

--     if root == nil then
--         print('XDG_CONFIG_HOME is not set.')
--         return
--     end

--     local repo = 'https://github.com/neovim/nvim-lspconfig'
--     local install_path = root .. '/nvim/pack/nvim/start/nvim-lspconfig'

--     if vim.fn.isdirectory(install_path) == 0 then
--         print('Installing nvim-lspconfig...')
--         vim.fn.system({'git', 'clone', repo, install_path})
--     end
-- end

-- ---------------------------------------------------------------------
-- LSP CONFIGURATION
-- ---------------------------------------------------------------------

-- install_lspconfig()

-- vim.lsp.enable('pyrefly')
-- vim.lsp.enable('rust_analyzer')

-- ---------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------