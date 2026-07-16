# Followup Queue

Tracked follow-up work, grouped by activity. Each item is tagged with a rough
complexity estimate:

- **Low** — contained to one role/file, roughly a single sitting.
- **Medium** — a few files or some up-front investigation/design.
- **High** — real design work, many files, or large enough to warrant its own
  `docs/plans/` doc (often multi-session).

Remove items when done (git history keeps the record).

## Provisioning & setup

- **Write a bootstrap script (curl|bash) that provisions a bare machine and
  delegates to the right setup/config.** *(Complexity: High.)* Why: setup/config
  currently assume tools that a fresh machine lacks, and there is no committed
  bootstrap here (the user started one on their personal Linux laptop but did
  not get far). Immediate pain: on the work Mac, "setup and config scripts both
  fail on mac because brew cellar isn't on path" (`README.md:89`) — closely
  related to the **Handle keg-only Homebrew packages** item (same PATH problem).
  Desired shape, from the `README.md` TODO (lines 86, 89, 90):
  - `curl … | bash` fetches the minimal set of tools + this repo.
  - Installs the package manager + git, downloads the repository (and possibly
    creates SSH keys).
  - Detects the OS and delegates to the correct entrypoint:
    `setup-macos/setup.sh` / `setup-ubuntu/setup.sh` / `setup-archlinux/setup.sh`,
    then `config/config.sh`.
  - Preferred tooling: **dotslash** (cross-platform executable fetching) where
    it can replace disparate package-management/provisioning steps. Not yet
    referenced anywhere in this repo.
  - Reference implementation the user already built along these lines:
    https://github.com/chpatton013/chiiiirrus/
  Also relates to the **Install a backlog of packages** item (both need
  OS/profile detection).

- **Install a backlog of packages, gated by machine profile.** *(Complexity:
  High — the machine-profile mechanism is the hard part.)* Add: `kubectl`,
  `octant`, `hub`, `graphviz`, `obsidian`, `sensiblesidebuttons`, `signal`,
  `steam`, `vscode`, `postman`, `kindle`, `virtualbox`. The blocker is that there
  is **no machine-profile concept yet** — installs are only split by OS
  (`setup-macos` / `setup-ubuntu` / `setup-archlinux`), not by headless-vs-GUI or
  work-vs-personal. Design that first, then gate:
  - **Skip on headless machines** (GUI apps): e.g. `signal`, `vscode`,
    `postman` (and by extension the other GUI ones).
  - **Skip on work machines**: e.g. `steam`, `kindle`.
  - **virtualbox**: unsure it still makes sense on macOS — every VM the user has
    tried failed to run or hung. Decide whether to drop it on macOS (note it is
    a Vagrant dependency: `setup-ubuntu/roles/vagrant/meta/main.yml` and the
    repo's Vagrant test harness use VirtualBox; there is a
    `setup-ubuntu/roles/virtualbox/`, but no macOS equivalent).
  - GUI casks currently live in `setup-macos/roles/user-tools/tasks/main.yml`;
    many of these names are also in the `README.md` TODO scratchpad (kubectl,
    octant, hub, graphviz, obsidian, virtualbox, signal, steam, etc.) — clean
    those up when done. Relates to the **Remove all remnants of iTerm and
    Alacritty** item (same user-tools files).

- **Decide a cross-platform strategy for scripting-language runtime version
  management** (the rbenv/pyenv problem), then reconcile the existing
  `config/roles/{go,lua,ruby,gem,npm,python,cargo}` roles with it. *(Complexity:
  High.)* Seed research:
  - **Unified option**: `mise` (formerly rtx) — fast Rust tool managing many
    runtimes (node, python, ruby, lua, go, ...) via asdf-compatible plugins,
    per-project `mise.toml`/`.tool-versions`, cross-platform. `asdf` is the
    older, shell-based analog. Leaning toward consolidating on `mise`.
  - **Python**: already on `uv`, which manages Python versions + tools + venvs
    and effectively supersedes pyenv/pipx for our use. Keep uv; do not add
    pyenv. Open question: let uv own Python even if mise owns everything else,
    or use mise's uv-backed python.
  - **Node/JS/TS**: candidates `fnm` or `volta` (both Rust, cross-platform,
    per-project pinning) or just `mise`.
  - **Lua**: `mise` can manage lua/luajit; `hererocks` installs lua+luarocks
    into a dir. Note: neovim and wezterm each embed their own LuaJIT and run
    their config with it, so a managed system lua is only needed for ad-hoc
    scripting / luarocks, not for those configs to work.
  - **Ruby**: `mise` (or the existing rbenv-style approach) instead of a
    dedicated build.

- **Evaluate dotslash for more of this repo's executables (beyond bootstrap).**
  *(Complexity: Medium.)* We already plan to use dotslash for bootstrapping (see
  the **Write a bootstrap script** item); investigate where else it fits, since
  it can unify several disparate provisioning strategies behind one
  cross-platform manifest. Current strategies worth reviewing as candidates
  (roles under `config/roles/*/tasks/main.yml` that download/build/install
  executables): source builds — `git`, `neovim`, `tmux`, `wezterm`;
  release-tarball/binary downloads — `git` (git-sizer), `bazel`, `lua`, `vim`;
  language-package installs — `cargo`/`alacritty`, `python` (uv tools). For each,
  weigh dotslash (fetch a pinned prebuilt binary) against the current approach —
  noting some are deliberately built from source for a specific version/patch
  (e.g. the `wezterm` fork for CSI 2031, see
  docs/plans/dynamic-color-theme-propagation.md, and the pinned source builds in
  the **Update tracked source-build tool versions** item), where dotslash would
  not apply.

- **Handle keg-only Homebrew packages that need `brew link` on macOS.**
  *(Complexity: Low–Medium.)* Running setup/config on the work Mac produced
  errors about needing to "link" the `ruby` package (installed in
  `setup-macos/roles/dev-tools/tasks/main.yml`), and other formulae likely need
  the same. There is no brew-link handling in the setup roles yet. Make setup
  ensure the needed binaries are on PATH (e.g. `brew link` keg-only formulae, or
  add their `/opt/homebrew/opt/<pkg>/bin` to PATH). Likely related to
  `README.md:89` ("setup and config scripts both fail on mac because brew cellar
  isn't on path"). User's notes / proposed method:
  > brew link packages:
  > - ruby
  >
  > Track down other bins that need to be linked: look for `*/bin/*` dirs within
  > the Cellar and check whether they `which` to the same realpath after
  > prepending `/opt/homebrew/bin` to the PATH.

- **Install and start the ollama service cross-platform.** *(Complexity:
  Low–Medium.)* macOS is already done: `setup-macos/roles/dev-tools/tasks/main.yml`
  installs the `ollama` brew formula and starts it via `homebrew_services`
  (`state: present`). Missing on Linux — there is no ollama install/service in
  `setup-ubuntu` or `setup-archlinux`; add it (package + service enable/start,
  e.g. systemd). Then remove the stale manual `brew install ollama` / `brew
  services start ollama` lines from the `README.md` TODO scratchpad. Context:
  ollama hosts the local LLMs the Pi Agent uses (see AGENTS.md and
  docs/plans/improving-pi-agent-engineering-practices.md).

- **Build zsh from source.** *(Complexity: Low–Medium.)* Add a role that builds
  zsh from source into the XDG prefix (`~/.local`), matching the git/neovim/tmux
  pattern, so the shell version is not tied to the system/brew package.

- **Install Rosetta 2 during macOS setup.** *(Complexity: Low.)* Add a task that
  runs `softwareupdate --install-rosetta --agree-to-license` so x86_64-only apps
  and brew casks work on Apple Silicon. Likely a system-prep task in
  `setup-macos/roles/xcode/` or `setup-macos/roles/dev-tools/`; make it
  idempotent (skip if Rosetta is already installed) and note it needs sudo. The
  `README.md` TODO scratchpad already lists this line and a "rosetta packages"
  section (sensiblesidebuttons, steam, signal) — clean those up when done.

- **Update tracked source-build tool versions.** *(Complexity: Low.)* Several
  roles pin a version of a tool we build from source; audit them and bump to
  current releases. Known as of 2026-07-15:
  - `config/roles/tmux` — bumped to `3.6a` (done, for mode 2031 support).
  - `config/roles/neovim` — `neovim_release_version` (currently `0.11.6`).
  - `config/roles/git` — `git_release_version`.
  - Also check the Linux setup roles under `setup-ubuntu/` and
    `setup-archlinux/` for any pinned source builds.

## Neovim

- **Iron out the Neovim AI-plugin setup (cursortab + minuet + avante), with
  per-project provider gating.** *(Complexity: High — may warrant its own
  `docs/plans/` doc.)* The three seem like they should synergize (cursortab =
  tab/inline completion, minuet = LLM completion source, avante = agentic
  assistant) but the user has not gotten them working together. Current state in
  `config/files/neovim/init.lua`: `cursortab.nvim` is active (`init.lua:305-310`);
  `minuet-ai.nvim` (config `init.lua:180-189`, spec/cmp source around
  `:320`/`:428-432`/`:1127`, lualine `:572`) and `avante.nvim` (`init.lua:327-404`,
  with endpoints for anthropic, moonshot, and a local `http://127.0.0.1:8765/v1`)
  are commented out. Two parts:
  1. Investigate how the three can coexist cleanly (division of labor, avoiding
     keybinding/source conflicts — overlaps the **Polish the Neovim completion
     UX** item, since cursortab already contends for `<Tab>`).
  2. **Route each tool's LLM provider by project + security policy.** Desired:
     on the work laptop, personal projects may use the user's own LLM cluster,
     while work projects must use only employer-provisioned services; models
     running locally on-machine (e.g. ollama for lightweight tab completion via
     cursortab) are acceptable for either, since queries never leave the
     machine. Needs a per-project/per-directory provider-selection mechanism.
  Related: the **Install and start the ollama service** item (local model
  availability) and the Pi Agent local-LLM work
  (docs/plans/improving-pi-agent-engineering-practices.md, AGENTS.md).

- **Build a replacement for the remote-sshfs Neovim plugin.** *(Complexity: High
  — a separate plugin project in its own repo.)* Replace the experimental
  `nosduco/remote-sshfs.nvim` fork the user has been trying (a local fork at
  `~/github/chpatton013/remote-sshfs.nvim`, wired but commented out in
  `config/files/neovim/init.lua:610-611`; its statusline is still referenced at
  `init.lua:568`). Why the current one falls short: poor ssh-config parsing that
  relies on data embedded in structured comments. Desired improvements (user's
  list):
  - A proper ssh-config parser (no reliance on structured-comment metadata).
  - Connection pooling within the nvim server.
  - Clear visual indicators when the session is working inside an sshfs mount.
  - Intelligently delegate remote commands over the ssh connection rather than
    reading every file over the sshfs link.
  - Generalized picker integration so it does not hard-depend on telescope —
    the user's picker is fzf (`fzf-lua`, `init.lua:496`; telescope is also
    present at `init.lua:523`).
  The dotfiles-side change is only swapping the plugin spec in `init.lua` once
  the plugin exists.

- **Polish the Neovim completion UX.** *(Complexity: Medium.)* The current setup
  is unintuitive about when to press `<Tab>` vs. arrow keys to explore the
  completion menu, and successive attempts to add completion plugins/behaviors
  have made it more confusing rather than less. The user does not yet know
  exactly what they want, or which built-in completion options Neovim offers — so
  step one is likely to survey the options (Neovim's built-in ins-completion and
  the native LSP completion in 0.11+, `completeopt`) and decide how much can be
  done without plugins, then settle on one coherent keybinding story. Current
  stack in `config/files/neovim/init.lua`: `nvim-cmp` (`init.lua:412`) with
  sources buffer/cmdline/nvim-lsp/nvim-lua/path, `LuaSnip` (`init.lua:435-440`),
  and `cursortab.nvim` (`init.lua:305-310`, AI tab-completion). Likely a root
  cause of the `<Tab>` confusion: `cursortab` and cmp/LuaSnip both want `<Tab>`.
  (Recent churn here — see commit `b82442b` "nvim: cmp cleanup".)

- **Make Neovim's language provider integrations work reliably, regardless of
  environment.** *(Complexity: Medium.)* Goal: the language providers Neovim
  supports (python, node, ruby, perl, ...) should be enabled whenever nvim runs,
  not dependent on the ambient shell environment. Origin: the old README TODO
  "Investigate how to run neovim in a virtualenv that has this package installed"
  — "this package" = the `pynvim` (neovim) PyPI package. The venv idea was a
  python-only convenience and would not cover ruby or other languages, so the
  venv is not the goal — robust, always-on integrations are. Current state: no
  provider host is configured (`config/files/neovim/init.lua` sets no
  `g:python3_host_prog` / `g:node_host_prog` / `g:ruby_host_prog`), and no
  provider packages are installed (`config/roles/python` uses uv but does not
  install `pynvim`; no `neovim` npm/gem). Likely direction: install each provider
  package into a fixed location and point the corresponding `*_host_prog` at it,
  then verify with `:checkhealth provider`. Touches `config/roles/neovim`,
  `config/roles/{python,npm,gem}`. Overlaps the **runtime version management**
  item since both concern how python/node/ruby are provisioned.

## Terminal & theming

- **Replace the hand-rolled tmux statusline and shell PS1 with a prettier,
  consistent system.** *(Complexity: Medium.)* Why: the current styling was built
  to avoid relying on patched fonts, which is no longer a constraint — it is
  simple and high-viz but not pretty. Goals: visual consistency for
  status/prompt styling across tmux, nvim, pi agent, etc. (and potentially zsh),
  and a PS1 that looks the same in **both zsh and bash**. Current pieces to
  replace/reconcile:
  - tmux statusline: `config/files/tmux/tmux-theme` (generates status-left/right
    and window formats) driven from `tmux.conf`
    (`config/roles/tmux/templates/tmux.conf`).
  - prompts: `config/files/zshrc/4-prompt.zsh` and
    `config/files/bashrc/4-prompt.bash` (separate implementations today — hence
    the zsh/bash divergence).
  - shared color source: the `color-theme` system
    (`config/files/color-theme/color-theme`) feeds both tmux-theme and the
    prompt; a replacement should keep light/dark awareness from Tier 1 (see
    docs/plans/dynamic-color-theme-propagation.md).
  - Candidates to investigate: a cross-shell prompt like starship (single config
    for zsh+bash, nerd-font glyphs) and a tmux theme/plugin; requires a patched
    (nerd) font — note wezterm currently uses plain `Monaco`
    (`config/files/wezterm/wezterm.lua`) with no nerd-font install in the setup
    roles, so a font install would be part of this.

- **Fix wezterm fullscreen re-sizing on display changes.** *(Complexity:
  Medium.)* When connecting to an external display whose resolution differs from
  the native one, a fullscreen (borderless) wezterm window stays at the old
  display's size instead of filling the new screen — and vice-versa on
  disconnect. Goal: a fullscreen wezterm window should automatically resize to
  fill the current screen whenever the window's size/screen changes. This is
  already an open TODO in the config: `config/files/wezterm/wezterm.lua:41` ("on
  screen resize event, for each window, if window is fullscreen,
  re-fullscreen"); startup fullscreen is set at `wezterm.lua:35-38` and the
  toggle bind at `wezterm.lua:45`. Likely direction: handle wezterm's
  `window-resized` (and/or a screen-change) event and re-apply fullscreen
  (`toggle_fullscreen`/`SetWindowLevel`/native fullscreen) for fullscreen
  windows. Note this is upstream wezterm config behavior, not the CSI-2031 fork
  specifically (see docs/plans/dynamic-color-theme-propagation.md for the fork
  context).

## Repo hygiene & tooling

- **Investigate/fix multi-line paste into Claude Code inserting `j` for
  newlines.** *(Complexity: Medium — cross-stack, partly an external tool.)*
  When pasting multi-line text **into the Claude Code TUI**, newlines come
  through as the letter `j` instead of line breaks. Observed this session; the
  user believes it is Claude Code's fullscreen/paste handling under tmux (it
  does **not** happen with our wezterm build generally — only when pasting into
  Claude Code). Likely mechanism: a newline is `LF` = `Ctrl-J` = `0x0A`, so
  something in the wezterm→tmux→Claude Code input chain is mistranslating pasted
  newlines (bracketed-paste not propagated, or an `extended-keys`/`csi-u`
  interaction). Starting points: tmux `extended-keys`/`extended-keys-format
  csi-u` and paste handling in `config/roles/tmux/templates/tmux.conf`, and
  wezterm paste settings (e.g. `canonicalize_pasted_newlines`) in
  `config/files/wezterm/wezterm.lua`. Note: the root cause may live in Claude
  Code itself (upstream, not this repo), in which case the deliverable is a
  terminal/tmux-side mitigation or a bug report rather than a repo fix.

- **Re-evaluate Vagrant as the test harness (does not work on Apple Silicon).**
  *(Complexity: Medium.)* The IaC approach is nice, but the harness relies on the
  **VirtualBox** provider (`Vagrantfile:10`), which the user has not gotten
  working on Apple Silicon. Harness pieces: `vagrant.sh` (wrapper keyed on
  `DOTFILES_PLATFORM`), `Vagrantfile` (virtualbox provider + `vagrant-disksize`
  plugin), `vagrant-env/archlinux` (box `archlinux/archlinux`) and
  `vagrant-env/ubuntu` (box `ubuntu/bionic64` — also quite dated), the README
  "Testing changes" section, plus `config/roles/vagrant` and
  `setup-ubuntu/roles/vagrant`. Decide whether to keep Vagrant with an
  Apple-Silicon-friendly provider (qemu/`vagrant-qemu`, UTM) or switch harness
  entirely (Lima/colima, Tart, containers). Same root cause as the VirtualBox
  concern in the **Install a backlog of packages** item (VMs failing/hanging on
  macOS). Note VirtualBox is wired as a Vagrant dependency on Linux
  (`setup-ubuntu/roles/vagrant/meta/main.yml`).

- **Add dev-hygiene tooling: file validation + GitHub Actions CI.**
  *(Complexity: Medium.)* Port the patterns from the user's `chiiiirrus` repo
  (https://github.com/chpatton013/chiiiirrus/) — file validation (likely
  pre-commit hooks / formatters / linters) and a GitHub Actions CI workflow.
  None exist here yet (no `.github/`, `.pre-commit-config.yaml`, `.yamllint`, or
  `.ansible-lint`). Lint targets by prevalence in the repo: YAML (147 `.yml` /
  Ansible playbooks+roles), shell (46 `.sh`, 4 `.bash`, 6 `.zsh`), lua (nvim /
  wezterm config), json, gitconfig. Candidate tools: `yamllint` + `ansible-lint`
  for the playbooks, `shellcheck` for scripts, `stylua`/`luacheck` for lua,
  `vim-vint` (already installed via `config/roles/python`). Pairs naturally with
  the **Audit the project** item (CI would enforce whatever conventions that
  audit settles on), and CI validating a fresh provision connects to the **Write
  a bootstrap script** item.

- **Audit the project for anti-patterns and simplification opportunities.**
  *(Complexity: Medium; open-ended.)* A broad, project-wide review of `config/`
  and `setup-*/` against the conventions documented in `AGENTS.md` (role
  structure, shellrc load-order, alphabetized lists, symlink pattern), looking
  for cruft, duplication, and footguns. Defer the actual analysis until this is
  picked up; the `/simplify` and `/code-review` skills may help. Seeds noticed
  already (starting points, not the full list):
  - **Role taggability:** `color-theme` was defined only as a transitive
    dependency, so `--tags color-theme` was a no-op until fixed this session;
    audit other roles for the same (any role only reachable via `meta`
    dependencies is not independently applicable).
  - **Duplication:** the repetitive dark/light functions in
    `config/files/color-theme/color-theme` and the parallel structure in
    `config/files/tmux/tmux-theme`.
  - **README drift:** the `README.md` TODO scratchpad is being migrated into
    this queue piecemeal; finish emptying it and trim the file.

- **Remove all remnants of iTerm and Alacritty** (wezterm is the terminal now).
  *(Complexity: Low.)* Remnants as of 2026-07-15:
  - Alacritty:
    - `config/roles/alacritty/` (whole role) and its line in
      `config/config.playbook.yml`.
    - `setup-ubuntu/roles/alacritty/`, `setup-archlinux/roles/alacritty/`, and
      the `alacritty` dependency in each platform's
      `dev-tools/meta/main.yml`.
  - iTerm:
    - `config/files/iterm2/` (`com.googlecode.iterm2.plist`).
    - `iterm2` cask in `setup-macos/roles/user-tools/tasks/main.yml`.
    - The two iTerm2 TODO lines in `README.md`.
  - Check for any user-space state left behind (e.g. `~/.config/alacritty`).
