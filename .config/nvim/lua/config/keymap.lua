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

-- Open terminal in vertical split
vim.keymap.set("n", "<leader>tv", ":vsplit | terminal<CR>")

-- Open terminal in horizontal split
vim.keymap.set("n", "<leader>th", ":split | terminal<CR>")

-- Toggle terminal mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])

vim.keymap.set("n", "<leader>tt", ":vsplit | terminal pwsh<CR>")
vim.keymap.set("n", "<leader>tf", ":vsplit | terminal dotnet fsi<CR>")
vim.keymap.set("n", "<leader>tp", ":vsplit | terminal python<CR>")
vim.keymap.set("n", "<leader>tr", ":vsplit | terminal evcxr<CR>")


-- ---------------------------------------------------------------------
-- TAB MANAGEMENT
-- ---------------------------------------------------------------------

vim.keymap.set("n", "<leader>tn", ":tabnew<CR>")
vim.keymap.set("n", "<leader>tc", ":tabclose<CR>")
vim.keymap.set("n", "<leader>tl", ":tabnext<CR>")
vim.keymap.set("n", "<leader>th", ":tabprevious<CR>")

vim.keymap.set("n", "<leader>sv", ":vsplit<CR>")
vim.keymap.set("n", "<leader>sh", ":split<CR>")
vim.keymap.set("n", "<leader>wh", "<C-w>h")
vim.keymap.set("n", "<leader>wl", "<C-w>l")
vim.keymap.set("n", "<leader>wj", "<C-w>j")
vim.keymap.set("n", "<leader>wk", "<C-w>k")

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