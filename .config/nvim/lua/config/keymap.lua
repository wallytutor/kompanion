-- ---------------------------------------------------------------------
-- NORMAL MODE KEYMAPS
-- ---------------------------------------------------------------------

-- Open file explorer with <leader>cd
vim.keymap.set('n', '<leader>cd', vim.cmd.Ex)

-- Show diagnostic popup
vim.keymap.set('n', '<leader>x', vim.diagnostic.open_float)

-- Navigate diagnostics
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)

-- Show all diagnostics
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

-- ---------------------------------------------------------------------
-- NORMAL MODE KEYMAPS FOR LSP
-- ---------------------------------------------------------------------

-- LSP actions (when LSP is attached)
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
vim.keymap.set('n', 'gr', vim.lsp.buf.references)
vim.keymap.set('n', 'K', vim.lsp.buf.hover)
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename)
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action)

-- ---------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------