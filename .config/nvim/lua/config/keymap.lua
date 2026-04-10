-- Open file explorer with <leader>cd
vim.keymap.set('n', '<leader>cd', vim.cmd.Ex)

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
