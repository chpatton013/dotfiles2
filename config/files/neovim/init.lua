-- Buffer initialization
--------------------------------------------------------------------------------

-- Behavior of several plugins depends on filetype being set. Setting it early
-- helps get consistent behavior from them.
-- Map from filetype -> [pattern]
local filetype_associations = {
    cpp = { "*.impl" },
    xml = { "*.launch", "*.plist" },
    make = { "*.make" },
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

-- Variable initialization
--------------------------------------------------------------------------------

-- Use `,` instead of `\` for the map leader
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Plugin configuration
--------------------------------------------------------------------------------

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system {
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    }
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
    "PeterRincker/vim-argumentative",   -- Rearrange function arguments
    "folke/which-key.nvim",             -- Display a popup with keybindings for ex commands
    "lewis6991/gitsigns.nvim",          -- Git buffer decorations
    "maxmx03/solarized.nvim",           -- Solarized color theme for nvim
    "michaeljsmith/vim-indent-object",  -- Treat indent structures as text objects
    "norcalli/nvim-colorizer.lua",      -- Color highlighter
    "tpope/vim-abolish",                -- Assorted word-munging utilities (Abolish, Subvert, Coerce)
    "tpope/vim-apathy",                 -- Filetype-aware values for path, suffixesadd, include, includeexpr, and define
    "tpope/vim-characterize",           -- Additional character information visible with `ga`
    "tpope/vim-commentary",             -- Easy (un)commenting of code blocks
    "tpope/vim-fugitive",               -- Integrated git commands
    "tpope/vim-repeat",                 -- Better command classification for `.`
    "tpope/vim-sensible",               -- Good defaults for everyone
    "tpope/vim-sleuth",                 -- Detect tabstop and shiftwidth automatically
    "tpope/vim-speeddating",            -- {In,De}crement (<C-A>, <C-X>) works with datetimes
    "tpope/vim-vinegar",                -- Improve usability of netrw directory browser
    "wesQ3/vim-windowswap",             -- Window swapping keybindings

    {
        "lukas-reineke/indent-blankline.nvim",  -- Add indent guides
        main = "ibl",
    },

    {
        "neovim/nvim-lspconfig",    -- Quickstart configs for LSP servers
        dependencies = {
            "folke/neodev.nvim",                    -- Configure LSP for neovim config, runtime, and plugin dirs
            "j-hui/fidget.nvim",                    -- LSP progress message window
            "williamboman/mason-lspconfig.nvim",    -- Integrate mason with lspconfig
            "williamboman/mason.nvim",              -- Package manager for LSP servers
        },
    },

    {
        "hrsh7th/nvim-cmp", -- Completion engine
        dependencies = {
            "hrsh7th/cmp-buffer",   -- nvim-cmp source for buffer words
            "hrsh7th/cmp-calc",     -- nvim-cmp source for math calculation
            "hrsh7th/cmp-cmdline",  -- nvim-cmp source for vim's cmdline
            "hrsh7th/cmp-nvim-lsp", -- nvim-cmp source for neovim builtin LSP client
            "hrsh7th/cmp-nvim-lua", -- nvim-cmp source for neovim Lua API
            "hrsh7th/cmp-path",     -- nvim-cmp source for filesystem paths
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

    {
        "nvim-treesitter/nvim-treesitter",  -- Incremental parsing engine
        dependencies = {
            "nvim-treesitter/nvim-treesitter-textobjects",  -- Syntax-aware text objects
        },
        build = ":TSUpdate",
    },
})

-- GitSigns
--------------------------------------------------------------------------------

local gitsigns_on_attach = function(bufnr)
    local gitsigns = require("gitsigns")

    local jump_to_next_hunk = function()
        if vim.wo.diff then
            return "]c"
        end
        vim.schedule(function() gitsigns.next_hunk() end)
        return "<Ignore>"
    end

    local jump_to_prev_hunk = function()
        if vim.wo.diff then
            return "[c"
        end
        vim.schedule(function() gitsigns.prev_hunk() end)
        return "<Ignore>"
    end

    vim.keymap.set(
        "n",
        "<leader>hp",
        gitsigns.preview_hunk,
        { buffer = bufnr, desc = "Preview git hunk" }
    )
    -- Don't override the built-in and fugitive keymaps.
    vim.keymap.set(
        { "n", "v" },
        "]c",
        jump_to_next_hunk,
        { expr = true, buffer = bufnr, desc = "Jump to next hunk" }
    )
    vim.keymap.set(
        { "n", "v" },
        "[c",
        jump_to_prev_hunk,
        { expr = true, buffer = bufnr, desc = "Jump to previous hunk" }
    )
end

require("gitsigns").setup(
    {
        signs = {
            add = { text = "+" },
            change = { text = "~" },
            delete = { text = "_" },
            topdelete = { text = "‾" },
            changedelete = { text = "~" },
        },
        attach_to_untracked = false,
        on_attach = gitsigns_on_attach,
    }
)

-- Telescope
--------------------------------------------------------------------------------

vim.defer_fn(
    function()
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
        vim.keymap.set("n", "<leader><space>", telescope_builtin.git_files, { desc = "Search git files" })
        vim.keymap.set("n", "<leader>sb", telescope_builtin.buffers, { desc = "[S]earch [B]uffers" })
        vim.keymap.set("n", "<leader>sf", telescope_builtin.find_files, { desc = "[S]earch [F]iles" })
        vim.keymap.set("n", "<leader>sh", telescope_builtin.help_tags, { desc = "[S]earch [H]elp" })
        vim.keymap.set("n", "<leader>sw", telescope_builtin.grep_string, { desc = "[S]earch current [W]ord" })
        vim.keymap.set("n", "<leader>sg", telescope_builtin.live_grep, { desc = "[S]earch by [G]rep" })
        vim.keymap.set("n", "<leader>sd", telescope_builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
        vim.keymap.set("n", "<leader>sr", telescope_builtin.resume, { desc = "[S]earch [R]esume" })
    end,
    0
)

-- Treesitter
--------------------------------------------------------------------------------

-- Defer Treesitter setup after first render to improve startup time of 'nvim {filename}'
vim.defer_fn(
    function()
        require("nvim-treesitter.configs").setup({
            -- Add languages to be installed here that you want installed for treesitter
            ensure_installed = {
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
            },

            -- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)
            auto_install = false,

            highlight = { enable = true },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<c-space>",
                    node_incremental = "<c-space>",
                    scope_incremental = "<c-s>",
                    node_decremental = "<M-space>",
                },
            },
            indent = { enable = true },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,   -- Automatically jump forward to textobj, similar to targets.vim
                    keymaps = {
                        -- You can use the capture groups defined in textobjects.scm
                        ["aa"] = "@parameter.outer",
                        ["ia"] = "@parameter.inner",
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,   -- whether to set jumps in the jumplist
                    goto_next_start = {
                        ["]m"] = "@function.outer",
                        ["]]"] = "@class.outer",
                    },
                    goto_next_end = {
                        ["]M"] = "@function.outer",
                        ["]["] = "@class.outer",
                    },
                    goto_previous_start = {
                        ["[m"] = "@function.outer",
                        ["[["] = "@class.outer",
                    },
                    goto_previous_end = {
                        ["[M"] = "@function.outer",
                        ["[]"] = "@class.outer",
                    },
                },
                swap = {
                    enable = true,
                    swap_next = {
                        ["<leader>a"] = "@parameter.inner",
                    },
                    swap_previous = {
                        ["<leader>A"] = "@parameter.inner",
                    },
                },
            },
        })
    end,
    0
)

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
    pyright = {},
    -- Rust
    rust_analyzer = {},
    -- Ruby
    sorbet = {},
    -- SQL
    sqlls = {},
    -- TOML
    taplo = {},
    -- Terraform
    terraformls = {},
    -- JS/TS
    tsserver = {},
    -- Vim
    vimls = {},
    -- Vue
    vuels = {},
    -- YAML
    yamlls = {},
}

vim.defer_fn(
    function()
        -- mason-lspconfig requires that these setup functions are called in this order
        -- before setting up the servers.
        require("mason").setup()
        require("mason-lspconfig").setup()

        -- Setup neovim lua configuration before lspconfig
        require("neodev").setup()

        -- nvim-cmp supports additional completion capabilities, so broadcast that to servers.
        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

        local lspconfig = require("lspconfig")
        local mason_lspconfig = require("mason-lspconfig")

        mason_lspconfig.setup({
            ensure_installed = vim.tbl_keys(language_servers),
        })
        mason_lspconfig.setup_handlers({
            function(server_name)
                local server = language_servers[server_name] or {}
                lspconfig[server_name].setup({
                    capabilities = capabilities,
                    on_attach = lsp_on_attach,
                    settings = server,
                    filetypes = server.filetypes,
                })
            end
        })
    end,
    0
)

-- System management
--------------------------------------------------------------------------------

vim.opt.shellpipe = "2>&1|tee"  -- Redirect shell pipe stderr to stdout
vim.opt.shellslash = true       -- Use forward slashes regardless of OS

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

-- Toggle various invertible settings on/off
vim.keymap.set("n", "<Leader>c", ":set cursorline!<CR>", { noremap = true })
vim.keymap.set("n", "<Leader>h", ":set hlsearch!<CR>", { noremap = true })
vim.keymap.set("n", "<Leader>n", ":set number!<CR>", { noremap = true })
vim.keymap.set("n", "<Leader>r", ":set relativenumber!<CR>", { noremap = true })
vim.keymap.set("n", "<Leader>w", ":set wrap!<CR>", { noremap = true })

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

vim.keymap.set("n", "<Leader>x", ToggleFoldEnable, { noremap = true })

-- Highlight yanked text.
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", {})
vim.api.nvim_create_autocmd("TextYankPost", {
    group = highlight_group,
    pattern = "*",
    callback = function() vim.highlight.on_yank() end,
    desc = "Highlight text briefly after yanking",
})

-- Color theme
--------------------------------------------------------------------------------

vim.opt.termguicolors = true

local solarized = require("solarized")
solarized.setup()

vim.cmd.colorscheme("solarized")
vim.opt.background = "light"

local solarized_utils = require("solarized.utils")
local solarized_palette = require("solarized.palette")
local ibl_highlight_groups = function()
    local c = solarized_palette.get_colors()
    -- base0:  Normal.fg
    -- base01: Comment.fg
    -- base03: Normal.bg
    -- base04: darker than Normal.bg
    return {
        CustomIblOdd = { fg = c.base01, bg = c.base03 },
        CustomIblEven = { fg = c.base01, bg = c.base04 },
        CustomIblScope = { fg = c.base0 },
    }
end

local ibl_hooks = require("ibl.hooks")
-- create the highlight groups in the highlight setup hook, so they are reset
-- every time the colorscheme changes
ibl_hooks.register(
    ibl_hooks.type.HIGHLIGHT_SETUP,
    function()
        local set_hl = solarized_utils.set_hl
        for name, definition in pairs(ibl_highlight_groups()) do
            set_hl(name, definition)
        end
    end
)

-- Alternate highlight groups of normal and darker backgrounds.
-- Emphasize the current scope with a vertical bar: `▏` or  `▎` look good.
require("ibl").setup({
    whitespace = { highlight = { "CustomIblOdd", "CustomIblEven" }, remove_blankline_trail = false },
    indent = { char = " ", highlight = { "CustomIblOdd", "CustomIblEven" } },
    scope = { char = "▏", show_exact_scope = true, highlight = { "CustomIblScope" } },
})

ibl_hooks.register(
    ibl_hooks.type.SCOPE_HIGHLIGHT,
    ibl_hooks.builtin.scope_highlight_from_extmark
)

-- Toggle IBL when entering/exiting visual mode.
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

require("colorizer").setup()

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

vim.defer_fn(
    function()
        local cmp = require("cmp")

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
            sources = {
                {
                    name = "buffer",
                    option = {
                        get_bufnrs = cmp_get_bufnrs,
                    }
                },
            },
        })

        cmp.setup.cmdline(":", {
            mapping = cmp.mapping.preset.cmdline(),
            sources = cmp.config.sources({
                {
                    name = "path",
                    option = {
                        trailing_slash = false,
                        label_trailing_slash = true,
                    },
                },
            }, {
                { name = "cmdline" },
            }),
        })
    end,
    0
)

vim.defer_fn(
    function()
        local which_key = require("which-key")

        which_key.setup()

        -- document existing key chains
        which_key.register({
            ["<leader>c"] = { name = "[C]ode", _ = "which_key_ignore" },
            ["<leader>d"] = { name = "[D]ocument", _ = "which_key_ignore" },
            ["<leader>g"] = { name = "[G]it", _ = "which_key_ignore" },
            ["<leader>h"] = { name = "Git [H]unk", _ = "which_key_ignore" },
            ["<leader>r"] = { name = "[R]ename", _ = "which_key_ignore" },
            ["<leader>s"] = { name = "[S]earch", _ = "which_key_ignore" },
            ["<leader>t"] = { name = "[T]oggle", _ = "which_key_ignore" },
            ["<leader>w"] = { name = "[W]orkspace", _ = "which_key_ignore" },
        })
        -- register which-key VISUAL mode
        -- required for visual <leader>hs (hunk stage) to work
        which_key.register(
            {
                ["<leader>"] = { name = "VISUAL <leader>" },
                ["<leader>h"] = { "Git [H]unk" },
            },
            { mode = "v" }
        )
    end,
    0
)

-- Input behavior
--------------------------------------------------------------------------------

vim.opt.modeline = true         -- Check files for a modeline to apply config settings
vim.opt.mouse = nil             -- Disable mouse input
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
        pattern = { "c", "cpp", "proto" },
        callback = function() vim.opt_local.commentstring = "// %s" end,
        desc = "Override commentstring for c,cpp,proto filetypes",
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
