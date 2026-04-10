local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- File tree
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup({
                view = {
                    adaptive_size = true,
                },
                actions = {
                    open_file = {
                        quit_on_open = false,
                        window_picker = { enable = false },
                    },
                },

            })
            vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
        end,
    },

    -- Telescope (file switching)
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local telescope = require("telescope.builtin")
            vim.keymap.set("n", "<leader>f", telescope.find_files)
            vim.keymap.set("n", "<leader>g", telescope.live_grep)
        end,
    },

    -- Colorscheme
    {
        "folke/tokyonight.nvim",
        config = function()
            vim.cmd("colorscheme tokyonight")
        end,
    },

    -- Mason
    {
        "mason-org/mason.nvim",
        opts = {}
    },

    -- LSP servers via Mason
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "fsautocomplete",
                "omnisharp",
                "lua_ls",
                "rust_analyzer",
                "pyright",
            },
        },
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
        },
    },

    -- F# support
    {
        "ionide/Ionide-vim",
        ft = { "fsharp", "fs", "fsi", "fsx" },
    },

    -- Git signs
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup({
                signs = {
                    add = { text = "+" },
                    change = { text = "~" },
                    delete = { text = "_" },
                },
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns
                    local map = function(lhs, rhs)
                        vim.keymap.set("n", lhs, rhs, { buffer = bufnr })
                    end

                    map("]c", gs.next_hunk)
                    map("[c", gs.prev_hunk)
                    map("<leader>hs", gs.stage_hunk)
                    map("<leader>hu", gs.undo_stage_hunk)
                    map("<leader>hp", gs.preview_hunk)
                    map("<leader>hb", gs.blame_line)
                end,
            })
        end,
    },

    {
        "tpope/vim-fugitive",
    },

    -- GitHub Copilot
    {
        "github/copilot.vim",
    }
})
