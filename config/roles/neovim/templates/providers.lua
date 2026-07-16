-- Rendered by the neovim role. Pin the language-provider host programs to
-- absolute paths so provider discovery does not depend on the ambient shell
-- PATH (e.g. when nvim is launched from a GUI or a bare env).
--
-- python3: an absolute venv interpreter that can import pynvim -> fully
-- env-independent. node/ruby: the host launchers are fixed here, but those
-- scripts still resolve their own node/ruby interpreter via PATH, so they work
-- from any of our provisioned shells; full runtime isolation is deferred to the
-- runtime-version-management follow-up. perl: explicitly disabled (no perl
-- tooling in this repo).
vim.g.python3_host_prog = "{{python_neovim_venv_dir}}/bin/python3"
vim.g.node_host_prog = "{{npm_data_dir}}/bin/neovim-node-host"
vim.g.ruby_host_prog = "{{gem_data_dir}}/bin/neovim-ruby-host"
vim.g.loaded_perl_provider = 0
