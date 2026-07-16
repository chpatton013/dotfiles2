# Neovim Language Providers

## Context

Neovim delegates `:python3`, `node`, `ruby`, and `perl` remote-plugin work to
external "provider" host programs. Whether a provider is enabled depends on
Neovim finding both the host launcher (`neovim-node-host`, `neovim-ruby-host`,
a `pynvim`-capable python) and its runtime. Today that discovery is left to the
ambient shell environment, so providers work only when nvim happens to be
launched from a shell that has our `$NPM_PREFIX/bin`, `$GEM_HOME/bin`, and a
`pynvim`-bearing python on `PATH` — and silently degrade when nvim is launched
from a GUI, a bare `env`, or a different machine.

Goal: **the python/node/ruby providers are enabled whenever nvim runs,
independent of the ambient env; perl is explicitly disabled.** Verified with
`:checkhealth provider`.

Origin: the old README TODO "run neovim in a virtualenv that has this package
installed" (`pynvim`). The venv was a python-only convenience and doesn't cover
ruby/node — the real goal is robust, always-on integrations, not a venv.

### Current state (corrects the followup's "no packages installed" note)

- `config/files/neovim/init.lua` sets **no** `g:python3_host_prog` /
  `g:node_host_prog` / `g:ruby_host_prog` and disables no providers.
- `config/roles/npm/tasks/main.yml` **already installs** the `neovim` npm
  package into `{{npm_data_dir}}` (`~/.local/share/dotfiles/npm`); the host
  ends up at `{{npm_data_dir}}/bin/neovim-node-host`.
- `config/roles/gem/tasks/main.yml` **already installs** the `neovim` gem into
  `{{gem_data_dir}}`; host at `{{gem_data_dir}}/bin/neovim-ruby-host`.
- `config/roles/python` uses `uv` but installs **no** `pynvim` (uv tools are
  executables; `pynvim` is a library, so it doesn't fit `uv tool install`).
- Playbook order is alphabetical: `gem` … `neovim` … `npm` … `python`, so
  **neovim currently applies before npm/python** — relevant to ordering below.

So this is mostly a *pin-the-host-paths* task plus adding `pynvim`, not a
from-scratch install.

## Approach

1. Install each provider package into a fixed, role-owned location (keep npm's
   and gem's `neovim`; add a `pynvim` venv for python).
2. Point the matching `g:*_host_prog` at absolute paths so provider discovery
   never consults `PATH`. Feed those paths to `init.lua` from the neovim role
   (rendered Lua fragment) rather than hardcoding, to keep the path definitions
   in the language roles.
3. Disable the perl provider outright (no perl tooling in this repo).

## Steps

### 1. python — install `pynvim` into a fixed venv (`config/roles/python`)

- Add `python_neovim_venv_dir` (e.g. `{{dotfiles_data_dir}}/python/neovim-venv`)
  to a new `config/roles/python/defaults/main.yml`.
- Add tasks: `uv venv --python 3.12 {{python_neovim_venv_dir}}` then
  `uv pip install --python {{python_neovim_venv_dir}} pynvim`, both
  `creates:`-guarded on `{{python_neovim_venv_dir}}/bin/python`. Pin 3.12 to
  match `pyright --pythonversion=3.12` in `init.lua`.
- Host program: `{{python_neovim_venv_dir}}/bin/python3` (a venv interpreter
  that can `import pynvim`; nvim invokes it directly, no shell venv activation).

### 2. node / ruby — no package change (`config/roles/{npm,gem}`)

- Both already install the `neovim` package into fixed dirs; leave as-is.
- Confirm the host launchers land at `{{npm_data_dir}}/bin/neovim-node-host`
  and `{{gem_data_dir}}/bin/neovim-ruby-host` (they do, given `NPM_PREFIX` /
  `GEM_HOME`). No task edits expected here beyond that verification.

### 3. neovim — pin host programs (`config/roles/neovim`, `init.lua`)

- Add `python`, `npm`, `gem` to `config/roles/neovim/meta/main.yml`
  `dependencies` so (a) those dirs' vars are defined when neovim renders and
  (b) the provider packages exist before neovim's `+Lazy install`/verify runs
  (fixes the current gem→neovim→npm→python ordering).
- Add a `templates/providers.lua` to the neovim role rendering absolute paths:
  - `vim.g.python3_host_prog = "{{python_neovim_venv_dir}}/bin/python3"`
  - `vim.g.node_host_prog = "{{npm_data_dir}}/bin/neovim-node-host"`
  - `vim.g.ruby_host_prog = "{{gem_data_dir}}/bin/neovim-ruby-host"`
  - `vim.g.loaded_perl_provider = 0`  -- explicitly disable perl
  Render it to `{{neovim_config_dir}}/providers.lua` (`mode: 0400`), alongside
  the existing `0-neovim.sh` render task.
- In `config/files/neovim/init.lua`, near the top (before plugins/provider use,
  by the leader/termguicolors block), load it:
  `pcall(dofile, vim.fn.stdpath("config") .. "/providers.lua")`.
  Guard with `pcall` so a machine that hasn't re-applied the role still starts.

### 4. apply

- `config/config.sh --tags python,gem,npm,neovim` (or a full apply). Adding a
  new rendered file needs a re-apply; editing `init.lua` alone takes effect
  immediately (symlinked).

## Verification

Confirm each provider independent of the shell env:

- `nvim --headless "+checkhealth provider" +qa` (redirect to a file) — expect
  python3, node, ruby all **OK** with the pinned host paths, perl reported
  **disabled** (not error).
- `:echo has("python3")` / `has("node")` / `has("ruby")` all return `1`.
- Env-independence proof: `env -i HOME="$HOME" TERM="$TERM" nvim --headless
  "+checkhealth provider" +qa` — providers still OK with an empty `PATH`-less
  env (this is the whole point; if node/ruby fail here, see risks).
- Spot-check the rendered paths exist: `neovim-node-host`, `neovim-ruby-host`,
  and `<venv>/bin/python3 -c "import pynvim"`.

## Risks / open questions

- **Runtime discovery still leaks (node/ruby).** Pinning `*_host_prog` fixes the
  *launcher* location, but `neovim-node-host` / `neovim-ruby-host` are shebang
  scripts (`#!/usr/bin/env node`, ruby) that still resolve their interpreter via
  `PATH`. Under a truly stripped env the `env -i` check may fail for node/ruby
  even though python (absolute venv interpreter) passes. Full independence needs
  the node/ruby runtimes pinned too — **directly overlaps the runtime
  version-management followup** (mise/fnm/uv). Options: wrapper scripts that
  hardcode the interpreter, or accept "works from any of our provisioned shells"
  as the bar for node/ruby and defer full isolation to that item. Decide the bar.
- **Path duplication vs. single source.** Rendering `providers.lua` from the
  neovim role (with `npm`/`gem`/`python` as meta deps) keeps paths defined in the
  language roles; the alternative — `vim.fn.expand("~/.local/share/dotfiles/…")`
  hardcoded in `init.lua` — is simpler but duplicates the XDG layout. Plan
  assumes the rendered-fragment approach.
- **Python version pinning.** Venv pinned to 3.12 to match pyright; revisit if
  the default python bumps. `uv venv` otherwise uses uv's default.
- **Ordering already assumed.** The meta-dep reorder is load-bearing; without it
  a `--tags neovim`-only apply would pin paths to not-yet-installed hosts.
- **Cross-platform.** Paths are XDG-relative and work on Linux and macOS; no
  Darwin gating needed. Untested on the dated Vagrant Linux boxes.
