-- ---------------------------------------------------------------------
-- KEYMAP SUMMARY (GROUPED)
-- ---------------------------------------------------------------------
-- Diagnostics:
--   <leader>x   -> open diagnostic float at cursor
--   [d / ]d     -> jump to previous/next diagnostic
--   <leader>q   -> send diagnostics to location list
--
-- File/Explorer:
--   <leader>cd  -> open netrw explorer (:Ex)
--
-- Terminal:
--   <leader>tv  -> open terminal in vertical split (right)
--   <leader>th  -> open terminal in horizontal split (below)
--   <leader>tt  -> open PowerShell terminal in vertical split (right)
--   <leader>tf  -> open F# interactive terminal in vertical split (right)
--   <leader>tp  -> open Python terminal in vertical split (right)
--   <leader>tr  -> open Rust (evcxr) terminal in vertical split (right)
--   <Esc> (terminal mode) -> return to normal mode
--
-- Tabs:
--   <leader>tn  -> open new tab
--   <leader>tc  -> close current tab
--   <leader>tl  -> go to next tab
--   <leader>th  -> NOT AVAILABLE (used by terminal split below)
--
-- Windows/Splits:
--   <leader>sv  -> vertical split
--   <leader>sh  -> horizontal split
--   <leader>wh  -> focus left window
--   <leader>wl  -> focus right window
--   <leader>wj  -> focus lower window
--   <leader>wk  -> focus upper window
--
-- LSP:
--   gd          -> go to definition
--   gr          -> list references
--   K           -> show hover documentation
--   <leader>rn  -> rename symbol
--   <leader>ca  -> code actions
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- DIAGNOSTICS + FILE EXPLORER
-- ---------------------------------------------------------------------

-- Open netrw explorer.
vim.keymap.set('n', '<leader>cd', vim.cmd.Ex)

-- Show diagnostics for the current cursor location.
vim.keymap.set('n', '<leader>x', vim.diagnostic.open_float)

-- Jump between diagnostics.
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)

-- Populate location list with diagnostics.
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

-- ---------------------------------------------------------------------
-- TERMINAL
-- ---------------------------------------------------------------------

-- Open terminal in vertical split (right).
vim.keymap.set("n", "<leader>tv", ":rightbelow vsplit | terminal<CR>")
vim.keymap.set("n", "<leader>tV", ":leftabove vsplit | terminal<CR>")

-- Open terminal in horizontal split (below).
vim.keymap.set("n", "<leader>th", ":botright split | terminal<CR>")

-- Exit terminal mode to normal mode.
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])

-- Open shell/REPL terminals in vertical splits (right).
vim.keymap.set("n", "<leader>tt", ":rightbelow vsplit | terminal pwsh<CR>")
-- vim.keymap.set("n", "<leader>tf", ":rightbelow vsplit | terminal dotnet fsi<CR>")
-- vim.keymap.set("n", "<leader>tp", ":rightbelow vsplit | terminal python<CR>")
-- vim.keymap.set("n", "<leader>tr", ":rightbelow vsplit | terminal evcxr<CR>")

vim.keymap.set("n", "<A-Left>",  "<C-w><")
vim.keymap.set("n", "<A-Right>", "<C-w>>")
vim.keymap.set("n", "<A-Up>",    "<C-w>+")
vim.keymap.set("n", "<A-Down>",  "<C-w>-")

-- ---------------------------------------------------------------------
-- TABS + WINDOWS/SPLITS
-- ---------------------------------------------------------------------

-- Tab lifecycle/navigation.
vim.keymap.set("n", "<leader>tn", ":tabnew<CR>")
vim.keymap.set("n", "<leader>tc", ":tabclose<CR>")
vim.keymap.set("n", "<leader>tl", ":tabnext<CR>")
-- Note: <leader>th is used for terminal horizontal split (see Terminal section)

-- Create window splits.
vim.keymap.set("n", "<leader>sv", ":vsplit<CR>")
vim.keymap.set("n", "<leader>sh", ":split<CR>")

-- Move focus across windows.
vim.keymap.set("n", "<leader>wh", "<C-w>h")
vim.keymap.set("n", "<leader>wl", "<C-w>l")
vim.keymap.set("n", "<leader>wj", "<C-w>j")
vim.keymap.set("n", "<leader>wk", "<C-w>k")

-- ---------------------------------------------------------------------
-- LSP
-- ---------------------------------------------------------------------

-- LSP actions (active when an LSP client is attached).
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
vim.keymap.set('n', 'gr', vim.lsp.buf.references)
vim.keymap.set('n', 'K', vim.lsp.buf.hover)
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename)
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action)

-- ---------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------