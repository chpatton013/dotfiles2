-- Pre-plugin configuration
--------------------------------------------------------------------------------

-- Behavior of several plugins depends on filetype being set. Setting it early
-- helps get consistent behavior from them.
-- Map from filetype -> [pattern]
local filetype_associations = {
    cpp = { "*.impl" },
    xml = { "*.launch", "*.plist" },
    make = { "*.make" },
    terraform = { "*.tf" },
    text = { "INSTALL", "NEWS", "TODO" },
}
local filetype_association_group = vim.api.nvim_create_augroup("FileTypeAssociation", {})
for filetype, pattern in pairs(filetype_associations) do
    vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
        group = filetype_association_group,
        pattern = pattern,
        callback = function() vim.opt_local.filetype = filetype end,
        desc = "Filetype association for " .. filetype .. " files",
    })
end

-- Color theme plugin requires termguicolors to be set prior to setup.
vim.opt.termguicolors = true

-- Some plugins resolve leader when setting up their own bindings, so set it
-- early before those plugins load.
-- Use `,` instead of `\` for the map leader
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Plugin configuration
--------------------------------------------------------------------------------

function gitsigns_on_attach(bufnr)
    local gitsigns = require("gitsigns")

    local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
    end

    -- Navigation
    map("n", "]c", function()
        if vim.wo.diff then
            vim.cmd.normal({"]c", bang = true})
        else
            gitsigns.nav_hunk("next")
        end
    end)

    map("n", "[c", function()
        if vim.wo.diff then
            vim.cmd.normal({"[c", bang = true})
        else
            gitsigns.nav_hunk("prev")
        end
    end)

    -- Actions
    map("n", "<leader>hs", gitsigns.stage_hunk)
    map("n", "<leader>hr", gitsigns.reset_hunk)

    map("v", "<leader>hs", function()
        gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end)

    map("v", "<leader>hr", function()
        gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end)

    map("n", "<leader>hS", gitsigns.stage_buffer)
    map("n", "<leader>hR", gitsigns.reset_buffer)
    map("n", "<leader>hp", gitsigns.preview_hunk)
    map("n", "<leader>hi", gitsigns.preview_hunk_inline)

    map("n", "<leader>hb", function()
        gitsigns.blame_line({ full = true })
    end)

    map("n", "<leader>hd", gitsigns.diffthis)

    map("n", "<leader>hD", function()
        gitsigns.diffthis("~")
    end)

    map("n", "<leader>hQ", function() gitsigns.setqflist("all") end)
    map("n", "<leader>hq", gitsigns.setqflist)

    -- Toggles
    map("n", "<leader>tb", gitsigns.toggle_current_line_blame)
    map("n", "<leader>td", gitsigns.toggle_word_diff)

    -- Text object
    map({"o", "x"}, "ih", gitsigns.select_hunk)
end

local whick_key_fallback_table = {
    Up = "<Up> ",
    Down = "<Down> ",
    Left = "<Left> ",
    Right = "<Right> ",
    C = "<C-…> ",
    M = "<M-…> ",
    D = "<D-…> ",
    S = "<S-…> ",
    CR = "<CR> ",
    Esc = "<Esc> ",
    ScrollWheelDown = "<ScrollWheelDown> ",
    ScrollWheelUp = "<ScrollWheelUp> ",
    NL = "<NL> ",
    BS = "<BS> ",
    Space = "<Space> ",
    Tab = "<Tab> ",
    F1 = "<F1>",
    F2 = "<F2>",
    F3 = "<F3>",
    F4 = "<F4>",
    F5 = "<F5>",
    F6 = "<F6>",
    F7 = "<F7>",
    F8 = "<F8>",
    F9 = "<F9>",
    F10 = "<F10>",
    F11 = "<F11>",
    F12 = "<F12>",
}

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable", -- latest stable release
        lazyrepo,
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo(
            {
                { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
                { out, "WarningMsg" },
                { "\nPress any key to exit..." },
            },
            true,
            {}
        )
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
    spec = {
        -- Behavior

        "michaeljsmith/vim-indent-object",  -- Treat indent structures as text objects
        "tpope/vim-apathy",                 -- Filetype-aware values for path, suffixesadd, include, includeexpr, and define
        "tpope/vim-repeat",                 -- Better command classification for `.`
        "tpope/vim-sensible",               -- Good defaults for everyone
        "tpope/vim-sleuth",                 -- Detect tabstop and shiftwidth automatically

        {
            "nvim-treesitter/nvim-treesitter",  -- Incremental parsing engine
            lazy = false,
            build = ":TSUpdate",
            opts = {},
        },
        {
            "nvim-treesitter/nvim-treesitter-textobjects",  -- Syntax-aware text objects
            branch = "main",
            opts = {},
            init = function()
                -- Disable entire built-in ftplugin mappings to avoid conflicts.
                -- See https://github.com/neovim/neovim/tree/master/runtime/ftplugin for built-in ftplugin
                vim.g.no_plugin_maps = true
            end,
        },

        {
            "mason-org/mason-lspconfig.nvim", -- Integrate mason with nvim's lsp config API
            dependencies = {
                {
                    "folke/lazydev.nvim", -- Configure LuaLS for neovim config
                    ft = "lua",
                    opts = {
                        library = {
                            -- See the configuration section for more details
                            -- Load luvit types when the `vim.uv` word is found
                            {
                                path = "${3rd}/luv/library",
                                words = { "vim%.uv" },
                            },
                        },
                    },
                },
                {
                    "j-hui/fidget.nvim", -- LSP progress message window
                    opts = {
                        notification = { override_vim_notify = true },
                    },
                },
                { "mason-org/mason.nvim", opts = {} }, -- Package manager for LSP servers
                "neovim/nvim-lspconfig", -- LSP server configurations
            },
        },

        -- Commands

        "PeterRincker/vim-argumentative",   -- Rearrange function arguments
        "tpope/vim-abolish",                -- Assorted word-munging utilities (Abolish, Subvert, Coerce)
        "tpope/vim-characterize",           -- Additional character information visible with `ga`
        "tpope/vim-commentary",             -- Easy (un)commenting of code blocks
        "tpope/vim-fugitive",               -- Integrated git commands
        "tpope/vim-speeddating",            -- {In,De}crement (<C-A>, <C-X>) works with datetimes

        {
            "sindrets/winshift.nvim", -- Move window splits
            opts = {},
        },

        -- Interactive

        "kevinhwang91/nvim-bqf",            -- Improve quickfix window
        "tpope/vim-vinegar",                -- Improve usability of netrw directory browser

        {
            "hrsh7th/nvim-cmp", -- Completion engine
            opts = function(_, opts)
                opts.sources = opts.sources or {}
                table.insert(opts.sources, {
                  name = "lazydev",
                  group_index = 0, -- set group index to 0 to skip loading LuaLS completions
                })
            end,
            dependencies = {
                "hrsh7th/cmp-buffer",   -- nvim-cmp source for buffer words
                "hrsh7th/cmp-calc",     -- nvim-cmp source for math calculation
                "hrsh7th/cmp-cmdline",  -- nvim-cmp source for vim's cmdline
                "hrsh7th/cmp-nvim-lsp", -- nvim-cmp source for neovim builtin LSP client
                "hrsh7th/cmp-nvim-lua", -- nvim-cmp source for neovim Lua API
                "hrsh7th/cmp-path",     -- nvim-cmp source for filesystem paths

                -- Snippet Engine & its associated nvim-cmp source
                {
                    "L3MON4D3/LuaSnip",
                    build = "make install_jsregexp",
                },
                "saadparwaiz1/cmp_luasnip",
            },
        },

        {
            "folke/trouble.nvim", -- Beautified diagnostics
            opts = {},
            cmd = "Trouble",
            keys = {
                {
                  "<leader>xx",
                  "<cmd>Trouble diagnostics toggle<cr>",
                  desc = "Diagnostics (Trouble)",
                },
                {
                  "<leader>xX",
                  "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
                  desc = "Buffer Diagnostics (Trouble)",
                },
                {
                  "<leader>cs",
                  "<cmd>Trouble symbols toggle focus=false<cr>",
                  desc = "Symbols (Trouble)",
                },
                {
                  "<leader>cl",
                  "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
                  desc = "LSP Definitions / references / ... (Trouble)",
                },
                {
                  "<leader>xL",
                  "<cmd>Trouble loclist toggle<cr>",
                  desc = "Location List (Trouble)",
                },
                {
                  "<leader>xQ",
                  "<cmd>Trouble qflist toggle<cr>",
                  desc = "Quickfix List (Trouble)",
                },
            },
        },

        {
            "folke/which-key.nvim", -- Display a popup with keybindings for ex commands
            opts = {
                icons = {
                    -- Enable mappings if we have a Nerd font.
                    mappings = vim.g.have_nerd_font,
                    -- Pass an empty table to use the default icons if we have a Nerd
                    -- font. Otherwise, pass a table of text strings.
                    keys = vim.g.have_nerd_font and {} or whick_key_fallback_table,
                },
            },
        },

        {
            "ibhagwan/fzf-lua",
            dependencies = {
                {
                    "MeanderingProgrammer/render-markdown.nvim",
                    opts = {
                        sign = { enabled = false },
                    },
                },
                "hpjansson/chafa",
                "nvim-tree/nvim-web-devicons",
            },
            opts = {
                previwers = {
                    builtin = {
                        extensions = {
                            ["jpg"] = {"chafa"},
                            ["png"] = {"chafa"},
                            ["svg"] = {"chafa"},
                        },
                    },
                },
            },
        },

        {
            "nvim-telescope/telescope.nvim",    -- Fuzzy finder over lists
            branch = "0.1.x",
            dependencies = {
                "BurntSushi/ripgrep",               -- Line-based regex pattern file search
                "debugloop/telescope-undo.nvim",    -- View and search undo tree with Telescope
                "nvim-lua/plenary.nvim",            -- Neovim Lua utility library

                {
                    "nvim-telescope/telescope-fzf-native.nvim", -- FZF sorter for telescope written in C
                    build = "make",
                    cond = function() return vim.fn.executable "make" == 1 end,
                },
            },
        },

        -- Visual

        {
            "lewis6991/gitsigns.nvim",          -- Git buffer decorations
            opts = {
                attach_to_untracked = false,
                on_attach = gitsigns_on_attach,
            },
        },
        {
            "maxmx03/solarized.nvim",           -- Solarized color theme for nvim
            opts = {},
        },
        {
            "norcalli/nvim-colorizer.lua",      -- Color highlighter
            opts = {},
        },
        {
            "ecthelionvi/NeoColumn.nvim", -- Selective color column
            opts = {},
        },
        {
            "lewis6991/satellite.nvim", -- Decorated scrollbar
            opts = {},
        },
        {
            "nvim-lualine/lualine.nvim", -- Configurable statusline
            opts = {
                theme = "solarized_light",
            },
            dependencies = {
                "nvim-tree/nvim-web-devicons",
            },
        },
        {
            "Bekaboo/dropbar.nvim", -- Window context drop-down bar
            dependencies = {
                "nvim-telescope/telescope-fzf-native.nvim",
                build = "make"
            },
            config = function()
                local dropbar_api = require("dropbar.api")
                vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
                vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
                vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })
            end
        },
        {
            "nvim-treesitter/nvim-treesitter-context",  -- Show surrounding function context
            opts = {},
        },

        {
            "lukas-reineke/indent-blankline.nvim",  -- Add indent guides
            main = "ibl",
        },
    },
    checker = { enabled = true, notify = false },
})

-- Telescope
--------------------------------------------------------------------------------

local telescope = require("telescope")
local telescope_actions = require("telescope.actions")
local telescope_undo_actions = require("telescope-undo.actions")

telescope.setup({
    extensions = {
        undo = {
            mappings = {
                i = {
                    ["<cr>"] = telescope_undo_actions.restore
                },
            },
        },
    },
    defaults = {
        mappings = {
            i = {
                ["<C-u>"] = false,
                ["<C-d>"] = false,
                ["<C-q>"] = (
                    telescope_actions.smart_send_to_qflist +
                    telescope_actions.open_qflist
                ),
            },
        },
    },
})

-- Enable telescope fzf native, if installed
pcall(telescope.load_extension, "fzf")
telescope.load_extension("undo")

local telescope_builtin = require("telescope.builtin")
-- vim.keymap.set("n", "<leader><space>", telescope_builtin.git_files, { desc = "Search git files" })
vim.keymap.set("n", "<leader>sb", telescope_builtin.buffers, { desc = "[S]earch [B]uffers" })
vim.keymap.set("n", "<leader>sf", telescope_builtin.find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>sh", telescope_builtin.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sw", telescope_builtin.grep_string, { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", telescope_builtin.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", telescope_builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", telescope_builtin.resume, { desc = "[S]earch [R]esume" })

local fzf = require("fzf-lua")
vim.keymap.set("n", "<leader><space>", fzf.global, { desc = "Fzf global search" })
vim.keymap.set("n", "<leader>F", fzf.builtin, { desc = "[F]zf builtin commands" })
vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "[F]zf [B]uffers" })
vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "[F]zf [F]iles" })
vim.keymap.set("n", "<leader>fm", fzf.manpages, { desc = "[F]zf [M]an pages" })
vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "[F]zf [H]elp" })
vim.keymap.set("n", "<leader>fw", fzf.grep_cword, { desc = "[F]zf current [W]ord" })
vim.keymap.set("n", "<leader>fW", fzf.grep_cWORD, { desc = "[F]zf current [W]ORD" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "[F]zf by [G]rep" })
vim.keymap.set("n", "<leader>fd", fzf.diagnostics_document, { desc = "[F]zf document [D]iagnostics" })
vim.keymap.set("n", "<leader>fD", fzf.diagnostics_workspace, { desc = "[F]zf workspace [D]iagnostics" })
vim.keymap.set("n", "<leader>fr", fzf.resume, { desc = "[F]zf [R]esume" })

-- Treesitter
--------------------------------------------------------------------------------

local treesitter = require("nvim-treesitter")
local treesitter_languages = {
    "bash",
    "c",
    "cpp",
    "go",
    "java",
    "javascript",
    "json",
    "lua",
    "python",
    "rust",
    "starlark",
    "terraform",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
}
local treesitter_language_options = {}
for _, lang in pairs(treesitter_languages) do
  treesitter_language_options[lang] = { enable = true, fold = true, indent = true }
end
treesitter.install(treesitter_languages)
local treesitter_callback = function(opts)
    if not opts.enable then
        return
    end
    vim.treesitter.start()
    if opts.fold then
        vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo[0][0].foldmethod = "expr"
    end
    if opts.indent then
        vim.bo.indentexpr = "v:lua.require('nvim-treesitter').indentexpr()"
    end
end


-- Language servers
--------------------------------------------------------------------------------

-- This function gets run when an LSP connects to a particular buffer.
local lsp_on_attach = function(_, bufnr)
    local nmap = function(keys, func, desc)
        if desc then
            desc = "LSP: " .. desc
        end

        vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
    end

    nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
    nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")

    local telescope_builtin = require("telescope.builtin")
    nmap("gd", telescope_builtin.lsp_definitions, "[G]oto [D]efinition")
    nmap("gr", telescope_builtin.lsp_references, "[G]oto [R]eferences")
    nmap("gI", telescope_builtin.lsp_implementations, "[G]oto [I]mplementation")
    nmap("<leader>D", telescope_builtin.lsp_type_definitions, "Type [D]efinition")
    nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
    nmap("K", vim.lsp.buf.hover, "Hover Documentation")

    -- Create a command `:Format` local to the LSP buffer.
    vim.api.nvim_buf_create_user_command(
        bufnr,
        "Format",
        function(_) vim.lsp.buf.format() end,
        { desc = "Format current buffer with LSP" }
    )
end

local language_servers = {
    -- Ansible
    ansiblels = {},
    -- Antlr
    antlersls = {},
    -- Arduino
    arduino_language_server = {},
    -- ASTGrep
    ast_grep = {},
    -- Bash
    bashls = {},
    -- C/C++
    clangd = {},
    -- CSS
    cssls = {},
    -- DockerCompose
    docker_compose_language_service = {},
    -- Docker
    dockerls = {},
    -- Dot
    dotls = {},
    -- GraphQL
    graphql = {},
    -- Heml
    helm_ls = {},
    -- HTML
    html = {},
    -- JSON
    jsonls = {},
    -- XML
    lemminx = {},
    -- Lua
    lua_ls = {},
    -- Markdown
    marksman = {},
    -- CMake
    neocmake = {},
    -- C#
    omnisharp = {},
    -- Perl
    perlnavigator = {},
    -- Python
    pyright = {
        cmd={"pyright-langserver", "--pythonversion=3.12"},
    },
    -- Rust
    rust_analyzer = {},
    -- Ruby
    -- sorbet = {}, -- TODO: Upgrade ruby to >=3.0.0
    -- SQL
    sqlls = {},
    -- TOML
    taplo = {},
    -- Terraform
    terraformls = {},
    -- JS/TS
    ts_ls = {},
    -- Vim
    vimls = {},
    -- Vue
    vuels = {},
    -- YAML
    yamlls = {},
}

vim.lsp.config("*", { on_attach = lsp_on_attach })
for name, opts in pairs(language_servers) do
    vim.lsp.config(name, opts)
end

require("mason-lspconfig").setup({
    ensure_installed = vim.tbl_keys(language_servers),
    automatic_enable = {
        exclude = {"clangd"},
    },
})

-- System management
--------------------------------------------------------------------------------

vim.opt.shellpipe = "2>&1|tee"  -- Redirect shell pipe stderr to stdout
if vim.loop.os_uname().sysname == "Windows_NT" then
    vim.opt.shellslash = true   -- Use forward slashes on Windows
end

vim.opt.autoread = false    -- Do not refresh files changed outside of editor
vim.opt.swapfile = false    -- Do not use swap files
vim.opt.writebackup = false -- Do not backup the destination file before writing

-- Treat all files like UTF-8
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.api.scriptencoding = "utf-8"

-- Window management
--------------------------------------------------------------------------------

vim.opt.hidden = true       -- Use hidden buffers so unsaved buffers can go to the background
vim.opt.lazyredraw = true   -- Defer screen redraw when running commands
vim.opt.scrolloff = 1       -- Keep lines of context visible when scrolling vertically
vim.opt.sidescrolloff = 5   -- Keep columns of context visible when scrolling horizontally
vim.opt.splitright = true   -- Open vertical window splits starboard
vim.opt.splitbelow = true   -- Open horizontal window splits aft

-- Use C-hjkl to change splits
vim.keymap.set("n", "<C-h>", "<C-w><Left>", { noremap = true })
vim.keymap.set("n", "<C-j>", "<C-w><Down>", { noremap = true })
vim.keymap.set("n", "<C-k>", "<C-w><Up>", { noremap = true })
vim.keymap.set("n", "<C-l>", "<C-w><Right>", { noremap = true })

-- Use CA-hjkl to rearrange splits
vim.keymap.set("n", "<C-A-h>", "<Cmd>WinShift left<CR>", { noremap = true })
vim.keymap.set("n", "<C-A-j>", "<Cmd>WinShift down<CR>", { noremap = true })
vim.keymap.set("n", "<C-A-k>", "<Cmd>WinShift up<CR>", { noremap = true })
vim.keymap.set("n", "<C-A-l>", "<Cmd>WinShift right<CR>", { noremap = true })
vim.keymap.set("n", "<C-A-w>", "<Cmd>WinShift<CR>", { noremap = true })

-- Use C-t to change tabs
vim.keymap.set("n", "<C-t>e", ":tabnew<CR>", { noremap = true })
vim.keymap.set("n", "<C-t>%", ":tabnew<Space>%<CR>", { noremap = true })
vim.keymap.set("n", "<C-t>n", ":tabnext<CR>", { noremap = true })
vim.keymap.set("n", "<C-t>p", ":tabprevious<CR>", { noremap = true })
vim.keymap.set("n", "<C-t>d", ":tabclose<CR>", { noremap = true })

-- Text rendering
--------------------------------------------------------------------------------

vim.opt.breakindent = true      -- Indent wrapped lines
vim.opt.cpoptions:append("$")   -- Show dollar sign at end of text to be changed
vim.opt.display:append("uhex")  -- Show unprintable characters hexadecimal as <xx> instead of using ^C and ~C
vim.opt.foldmethod = "syntax"   -- Fold based on language syntax (manual,indent,expr,syntax,diff,marker)
vim.opt.foldenable = false      -- Do not open file folded
vim.opt.list = true             -- Visualize whitespace characters
vim.opt.showmatch = true        -- Show matching () {} etc
vim.opt.cursorline = true       -- Show cursorline by default
vim.opt.wrap = false            -- Do not soft-wrap lines by default

vim.opt.listchars = {
    tab = "⇥·",
    trail = "·",
    extends = "⇉",
    precedes = "⇇",
    conceal = "░",
    nbsp = "·",
}

vim.opt.fillchars = {
    vert = "┆",
    fold = "░",
}

-- Highlight yanked text.
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", {})
vim.api.nvim_create_autocmd("TextYankPost", {
    group = highlight_group,
    pattern = "*",
    callback = function() vim.hl.on_yank() end,
    desc = "Highlight text briefly after yanking",
})

-- Toggle various invertible settings on/off
--------------------------------------------------------------------------------

-- Toggle line numbers and relative line numbers consistently.
vim.b.persist_relativenumber = vim.opt.relativenumber:get()
-- Hide number and relativenumber together, but only show relativenumber if
-- it was set previously.
function ToggleLineNumbers()
    if vim.opt.number:get() then
        vim.opt.number = false
        vim.opt.relativenumber = false
    else
        vim.opt.number = true
        vim.opt.relativenumber = vim.b.persist_relativenumber
    end
end
-- Only change relativenumber if number is shown, but record the change for
-- later use.
function ToggleRelativeLineNumbers()
    vim.b.persist_relativenumber = not vim.b.persist_relativenumber
    if vim.opt.number:get() then
        vim.opt.relativenumber = vim.b.persist_relativenumber
    end
end

-- Toggle foldcolumn and foldenable together
function ToggleFoldEnable()
    if vim.opt.foldenable:get() then
        vim.opt.foldcolumn = "0"
        vim.opt.foldenable = false
    else
        vim.opt.foldcolumn = "2"
        vim.opt.foldenable = true
    end
end

vim.keymap.set("n", "<leader>tC", ":ToggleNeoColumn<CR>", { noremap = true })
vim.keymap.set("n", "<leader>tR", ":set cursorline!<CR>", { noremap = true })
vim.keymap.set("n", "<leader>th", ":set hlsearch!<CR>", { noremap = true })
vim.keymap.set("n", "<leader>tn", ToggleLineNumbers, { noremap = true })
vim.keymap.set("n", "<leader>tr", ToggleRelativeLineNumbers, { noremap = true })
vim.keymap.set("n", "<leader>tw", ":set wrap!<CR>", { noremap = true })
vim.keymap.set("n", "<leader>tx", ToggleFoldEnable, { noremap = true })

-- Color theme
--------------------------------------------------------------------------------

vim.cmd.colorscheme("solarized")
vim.opt.background = "light"

local solarized_utils = require("solarized.utils")
local ibl_highlight_groups = function()
    local palette = solarized_utils.get_colors()
    local c = {}
    if vim.o.background == "dark" then
        c.normal_fg = palette.base0
        c.normal_bg = palette.base03
        c.muted_fg = palette.base01
        c.vibrant_bg = palette.base04
    else
        c.normal_fg = palette.base00
        c.normal_bg = palette.base3
        c.muted_fg = palette.base1
        c.vibrant_bg = palette.base4
    end
    return {
        CustomIblOdd = { fg = c.muted_fg, bg = c.normal_bg },
        CustomIblEven = { fg = c.muted_fg, bg = c.vibrant_bg },
        CustomIblScope = { fg = c.normal_fg, bg = "NONE" },
    }
end

local ibl_hooks = require("ibl.hooks")
-- create the highlight groups in the highlight setup hook, so they are reset
-- every time the colorscheme changes
ibl_hooks.register(
    ibl_hooks.type.HIGHLIGHT_SETUP,
    function()
        for name, definition in pairs(ibl_highlight_groups()) do
            vim.api.nvim_set_hl(0, name, definition)
        end
    end
)

-- Alternate highlight groups of normal and darker backgrounds.
-- Use a thinner vertical bar than default for indents in the inactive scope.
-- Use a thicker vertical bar than default for the indent in the active scope.
require("ibl").setup({
    whitespace = {
        highlight = { "CustomIblOdd", "CustomIblEven" },
        remove_blankline_trail = false,
    },
    indent = {
        highlight = { "CustomIblOdd", "CustomIblEven" },
        char = "▏", -- Left One Eighth Block
        smart_indent_cap = true,
    },
    scope = {
        highlight = { "CustomIblScope" },
        char = "▎", -- Left One Quarter Block
        show_exact_scope = true,
    },
})

ibl_hooks.register(
    ibl_hooks.type.SCOPE_HIGHLIGHT,
    ibl_hooks.builtin.scope_highlight_from_extmark
)

-- Toggle IBL when entering/exiting visual mode because the IBL highlight group
-- overrides the visual selection highlight group.
local visual_ibl_group = vim.api.nvim_create_augroup("visual_ibl_group", {})
vim.api.nvim_create_autocmd("ModeChanged", {
    group = visual_ibl_group,
    pattern = "[vV\x16]*:*",
    command = "IBLEnable",
    desc = "Enable indent-blanklines when exiting visual mode",
})
vim.api.nvim_create_autocmd("ModeChanged", {
    group = visual_ibl_group,
    pattern = "*:[vV\x16]*",
    command = "IBLDisable",
    desc = "Disable indent-blanklines when entering visual mode",
})

-- Search and Completion
--------------------------------------------------------------------------------

-- Case-insensitive searching UNLESS \C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Ignore generated files in the source tree
local generated_files = {
    "*.sw?",    -- Vim swap files
    "*.pyc",    -- Python bytecode
}
for _, match in ipairs(generated_files) do
    vim.opt.wildignore:append(match)
end

vim.opt.wildignorecase = true -- Tab completion is case-insensitive

-- When only one option matches the tab-completion search, complete to that full
-- match. Otherwise, lists the greatest-common substring of all matches without
-- opening the wildmenu. Open the wildmenu when the greatest-common substring is
-- listed and <Tab> is pressed again.
vim.opt.wildmode = "list:longest,full"

-- Show insert-mode completion popup menu even with one match, and include
-- extra information in the preview window.
vim.opt.completeopt = "menuone,noselect"

local cmp = require("cmp")

local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()
luasnip.config.setup()

local cmp_get_bufnrs = function()
    local buf = vim.api.nvim_get_current_buf()
    local line_count = vim.api.nvim_buf_line_count(buf)
    local byte_size = vim.api.nvim_buf_get_offset(buf, line_count)
    -- Skip buffers that are larger than 1MB
    if byte_size > 1024 * 1024 then
        return {}
    end
    return { buf }
end

local cmp_select_next_item = function(fallback)
    if cmp.visible() then
        cmp.select_next_item()
    else
        fallback()
    end
end

local cmp_select_prev_item = function(fallback)
    if cmp.visible() then
        cmp.select_prev_item()
    else
        fallback()
    end
end

cmp.setup({
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end
    },
    completion = {
        completeopt = "menu,menuone,noinsert",
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-d>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<CR>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
        }),
        ["<Tab>"] = cmp.mapping(cmp_select_next_item, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(cmp_select_prev_item, { "i", "s" }),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
    }, {
        {
            name = "buffer",
            option = {
                get_bufnrs = cmp_get_bufnrs,
            }
        },
    }),
})

cmp.setup.cmdline({ "/", "?" }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
        {
            name = "buffer",
            option = {
                get_bufnrs = cmp_get_bufnrs,
            }
        },
    }),
})

cmp.setup.cmdline(":", {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
        {
            name = "path",
            option = {
                trailing_slash = true,
                label_trailing_slash = true,
            },
        },
    }, {
        { name = "cmdline" },
    }),
})

local which_key = require("which-key")

-- Document existing key chains
which_key.add({
    { "<leader>c", group = "[C]ode", mode = { "n", "x" } },
    { "<leader>d", group = "[D]ocument" },
    { "<leader>g", group = "[G]it" },
    { "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
    { "<leader>r", group = "[R]ename" },
    { "<leader>s", group = "[S]earch" },
    { "<leader>t", group = "[T]oggle" },
    { "<leader>w", group = "[W]orkspace" },
})

-- Input behavior
--------------------------------------------------------------------------------

vim.opt.modeline = true         -- Check files for a modeline to apply config settings
vim.opt.mouse = ""              -- Disable mouse input
vim.opt.joinspaces = false      -- Do not insert two spaces after a '.', '?', and '!'
vim.opt.textwidth = 80          -- Automatically break lines at whitespace to get this width
vim.opt.virtualedit = "block"   -- Allow the cursor to move to columns without text

-- Whitespace handling
vim.opt.expandtab = true    -- Use the appropriate number of spaces to insert a <Tab>
vim.opt.shiftwidth = 2      -- Number of spaces to use for each step of (auto)indent.
vim.opt.tabstop = 2         -- Number of spaces that a <Tab> in the file counts for
vim.opt.softtabstop = 2     -- Number of spaces that a <Tab> counts for while performing editing operations

-- Comment formatting
vim.opt.commentstring = "# %s"      -- Most languages use `#` as their line-comment character
local format_options = {
    "r",   -- Insert comment leader after hitting <Enter>
    "o",   -- Insert comment leader after hitting 'o' or 'O' in command mode
    "n",   -- Auto-format lists, wrapping to text after the list bullet char (requires autoindent)
    "l",   -- Don't auto-wrap if a line is already longer than textwidth
}
for _, opt in ipairs(format_options) do
    vim.opt.formatoptions:append(opt)
end

-- Spell check language and dictionaries
vim.opt.spelllang = "en_us"
vim.opt.dictionary:append("spell")
if vim.fn.filereadable("/usr/share/dict/words") then
    vim.opt.dictionary:append("/usr/share/dict/words")
end

-- Smash to exit insert mode because <Esc> is too far away from home row
vim.keymap.set("i", "kj", "<Esc>", { noremap = true })

-- No one ever intends to enter ex-mode. Make it harder by rebinding to QQ
vim.keymap.set("n", "Q", "<nop>", { noremap = true })
vim.keymap.set("n", "QQ", "Q", { noremap = true })

-- Toogle paste mode on/off
vim.keymap.set("n", "<Leader>p", ":set paste!<CR>", { noremap = true })

-- Local overrides for specific filetypes
--------------------------------------------------------------------------------

local filetype_settings_group = vim.api.nvim_create_augroup("FileTypeSettings", {})
local filetype_settings = {
    {
        pattern = { "c", "cpp", "json", "proto" },
        callback = function() vim.opt_local.commentstring = "// %s" end,
        desc = "Override commentstring for c,cpp,json,proto filetypes",
    },
    {
        pattern = { "lua", "sql" },
        callback = function() vim.opt_local.commentstring = "-- %s" end,
        desc = "Override commentstring for lua,sql filetypes",
    },
    {
        pattern = { "vim" },
        callback = function() vim.opt_local.commentstring = "\" %s" end,
        desc = "Override commentstring for vim filetype",
    },
    {
        pattern = { "gitcommit", "mail", "markdown", "text" },
        callback = function() vim.opt_local.spell = true end,
        desc = "Enable spell-check in prose files",
    },
    {
        pattern = { "bzl", "lua", "python", "vim" },
        callback = function() vim.opt_local.foldmethod = "indent" end,
        desc = "Use indent-folding for syntax-sparse filetypes",
    },
    {
        pattern = { "bzl", "lua", "python", "vim" },
        callback = function()
            vim.opt_local.shiftwidth = 4
            vim.opt_local.tabstop = 4
            vim.opt_local.softtabstop = 4
        end,
        desc = "4-space indentation in syntax-sparse languages",
    },
    {
        pattern = { "bzl", "python", "yaml" },
        callback = function() vim.opt_local.indentkeys:remove("<:>") end,
        desc = "Do not trigger indent when `:` is pressed in some languages",
    },
    {
        pattern = { "make" },
        callback = function() vim.opt_local.expandtab = false end,
        desc = "Tabs are different than spaces in make syntax",
    },
}
for _, setting in pairs(filetype_settings) do
    vim.api.nvim_create_autocmd("FileType", {
        group = filetype_settings_group,
        pattern = setting.pattern,
        callback = setting.callback,
        desc = setting.desc,
    })
end
for lang, opts in pairs(treesitter_language_options) do
    vim.api.nvim_create_autocmd("FileType", {
        group = filetype_settings_group,
        pattern = { lang },
        callback = function() treesitter_callback(opts) end,
        desc = "Enable treesitter for ft=" .. lang
    })
end
