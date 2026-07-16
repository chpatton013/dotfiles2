# Followup Queue

Tracked follow-up work, grouped by activity. Each item is tagged with a rough
complexity estimate:

- **Low** — contained to one role/file, roughly a single sitting.
- **Medium** — a few files or some up-front investigation/design.
- **High** — real design work, many files, or large enough to warrant its own
  `docs/plans/` doc (often multi-session).

Remove items when done (git history keeps the record).

Implementation plans in `docs/plans/` for queued items (status noted; plans with
nothing left are deleted — git history keeps them):

- `cross-platform-tool-installs.md` — Claude Code + Pi Agent + ollama installs.
  Implemented; only the `pi_node_dir` cleanup below remains.
- `source-build-roles.md` — zsh from source + source-build version updates.
  Partially implemented; the neovim 0.12 bump is pending interactive validation.
- `dynamic-color-theme-propagation.md` — terminal light/dark propagation.
  Implemented (Tier 1 + Tier 2); kept as reference for the open Terminal items.
- `wezterm-fullscreen-display-changes.md` — fullscreen resize on display change.
  Core fix implemented; edge cases remain.
- `dev-hygiene-ci.md` — file validation + GitHub Actions CI. Not started.

## Provisioning & setup

- **Remove the vestigial `pi_node_dir` isolated-node scaffolding.** *(Complexity:
  Low.)* Left over from the rolled-back Pi Agent "Option A" (isolated Node
  runtime); Pi Agent now installs via npm global (Option B), so `pi_node_dir` is
  unused. Remove it from `config/roles/pi-agent/{defaults,tasks,templates}` and
  the `PI_NODE_PREFIX` export in `config/files/pi-agent/3-pi-agent.sh`. See
  docs/plans/cross-platform-tool-installs.md.

- **Combine the `zsh` and `zshrc` roles into one.** *(Complexity: Low–Medium.)*
  The new `config/roles/zsh` (source build) and the existing `config/roles/zshrc`
  (renders `~/.zshrc` + links fragments) are currently separate. Merging them is
  fine as long as it stays a single role (no dependency cycle): union the deps
  (`[shellrc, source-releases, xdg]`), fold the build + config tasks together,
  update `config/config.playbook.yml`, and re-verify. NOTE: this reverses the
  deliberate separation in docs/plans/source-build-roles.md Part 1 (kept apart to
  avoid a zsh→zshrc cycle) — confirm the intended role name/shape before
  refactoring.

- **Write a bootstrap script (curl|bash) that provisions a bare machine and
  delegates to the right setup/config.** *(Complexity: High.)* Why: setup/config
  currently assume tools that a fresh machine lacks, and there is no committed
  bootstrap here (the user started one on their personal Linux laptop but did
  not get far). Immediate pain: on the work Mac, "setup and config scripts both
  fail on mac because brew cellar isn't on path" (`README.md:89`) — closely
  related to the (now-resolved) keg-only PATH work; a bootstrap that shims
  `/opt/homebrew/bin` onto PATH before delegating would subsume it.
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
    those up when done. The `README.md` "rosetta packages" group
    (sensiblesidebuttons, steam, signal) belongs here too. (The iTerm/Alacritty
    removal already touched the same `user-tools` file — commit `557f416`.)

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
  executables): source builds — `git`, `neovim`, `tmux`, `wezterm`, `zsh`;
  release-tarball/binary downloads — `git` (git-sizer), `bazel`, `lua`, `vim`;
  language-package installs — `cargo` tools, `python` (uv tools). For each,
  weigh dotslash (fetch a pinned prebuilt binary) against the current approach —
  noting some are deliberately built from source for a specific version/patch
  (e.g. the `wezterm` fork for CSI 2031, see
  docs/plans/dynamic-color-theme-propagation.md, and the pinned source builds
  covered by docs/plans/source-build-roles.md), where dotslash would not apply.

## Neovim

- **Make the Neovim config degrade gracefully on a partial/failed bootstrap.**
  *(Complexity: Medium.)* When nvim's config has deployed but its dependencies
  have not fully bootstrapped, the editor becomes hard to use: e.g. the config
  is applied but the terminal color theme has not, leaving text very hard to
  read; and other breakages surface as an error interrupt on *every keypress*.
  Goal: detect missing dependencies (colorscheme/plugins/providers/parsers) and
  fall back sanely — a readable default colorscheme when `solarized` or the
  terminal theme is absent, and guarding plugin/autocmd/keymap setup so a
  failure degrades instead of erroring on every event. Starting points in
  `config/files/neovim/init.lua`: the `vim.cmd.colorscheme("solarized")` call
  (solarized comes from the `solarized`/`source-releases` deps, so it is absent
  until plugins install), lazy.nvim bootstrap, and the treesitter/provider
  setup — audit which calls assume a fully-provisioned state and wrap them
  (`pcall`, existence checks, fallbacks). Hunt the "error on every keypress"
  cause (a repeatedly-firing autocmd/CursorMoved/InsertCharPre callback, or a
  broken statusline/completion component). Relates to the terminal-theme
  propagation work (docs/plans/dynamic-color-theme-propagation.md) and the
  **Audit the Neovim config composition** item (a split could isolate the
  fragile pieces).

- **Audit the Neovim config composition; decide whether to split `init.lua`.**
  *(Complexity: Medium — investigation + a mechanical refactor.)* The whole
  config is a single ~1,286-line `config/files/neovim/init.lua` (the only file
  under `config/files/neovim/`). Assess whether to split it into multiple files
  (e.g. by concern: options, keymaps, the lazy.nvim plugin specs, LSP,
  completion, colors/statusline, filetype settings) and, if so, decide the
  layout — a `lua/` module tree required by `runtimepath`, or plain files
  sourced from `init.lua`. Note the neovim role links only `init.lua`
  (`config/roles/neovim/tasks/main.yml`, `with_items: [init.lua]`) into
  `{{neovim_config_dir}}` and symlinks that dir to `~/.config/nvim`, so a split
  means updating the role to link the new files/dir (the classic "file exists
  but isn't linked" gotcha — see AGENTS.md). Note the role now also renders a
  `providers.lua` next to `init.lua`, so a split has a sibling to sit beside.
  Several other queued Neovim items (completion-UX, AI-plugin gating) would
  touch this file, so a split may make those easier — consider sequencing this
  first.
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
  Related: local model availability (ollama, now installed cross-platform) and
  the Pi Agent local-LLM work
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

## Terminal & theming

- **Fix wezterm opening new windows in the light theme under a dark system
  appearance.** *(Complexity: Medium.)* New wezterm windows come up in the light
  color scheme even though macOS system appearance is Dark; toggling system
  appearance to Light and back to Dark corrects the affected window to dark.
  Cause is almost certainly the appearance→scheme wiring in
  `config/files/wezterm/wezterm.lua` (`get_appearance()` /
  `scheme_for_appearance()` / the one-shot `config.color_scheme =
  scheme_for_appearance(get_appearance())` at config-eval time, lines ~14-31):
  the scheme is resolved once and the initial `get_appearance()` result is wrong
  (or is the mux-server fallback path, which hard-returns `"Dark"` when
  `wezterm.gui` is nil — worth checking which side is misreporting), while the
  appearance-toggle triggers a config reload that then resolves correctly.
  Likely fix: resolve the scheme dynamically on `window-config-reloaded` (and/or
  guard the initial value) so each window picks the correct scheme at creation.
  Part of the terminal-theme story — see
  docs/plans/dynamic-color-theme-propagation.md (this is the wezterm-side
  appearance detection that feeds it).

- **Fix wezterm notch spacing wrongly applied to a fullscreen window on a
  notchless external display.** *(Complexity: Medium — likely an upstream
  wezterm/macOS quirk.)* Repro (macOS, laptop lid open, connected to an external
  display): with a fullscreen wezterm window on the external (no-notch) display,
  moving focus to an app window on the built-in (notched) display causes wezterm
  to add the notch inset to the fullscreen window on the external display —
  where there is no notch — so it gets spurious top spacing. Config already sets
  `config.macos_fullscreen_extend_behind_notch = false`
  (`config/files/wezterm/wezterm.lua:6`); the bug is that the notch inset seems
  applied per-focus/globally rather than per the window's actual screen.
  Investigate whether a wezterm setting or event handler can pin the inset to
  the window's own display, else file upstream. Closely related to the
  fullscreen resize fix (docs/plans/wezterm-fullscreen-display-changes.md) —
  same fullscreen/multi-display area; the plan's `mainScreen` quirk (a
  fullscreen window on a *secondary* display may target the wrong screen) is the
  same class of bug and likely fixed together.

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

## Repo hygiene & tooling

- **Add a status field to followup items + a ready/blocked convention; update
  the `/inbox` and `/work` commands.** *(Complexity: Low–Medium.)* Beyond the
  complexity tag, each item should carry a status so actionable work is
  identifiable at a glance — e.g. a `Status: ready` vs `Status: blocked (on …)`
  marker that briefly names the blocker for non-ready items. Then teach `/work`
  to prefer `ready` items (and surface blockers) and `/inbox` to set an initial
  status when filing. Touches `docs/followups.md` (re-annotate every item) and
  `.agents/commands/{inbox,work}.md`.

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
  `vim-vint` (already installed via `config/roles/python`). See
  docs/plans/dev-hygiene-ci.md. Pairs naturally with the **Audit the project**
  item (CI would enforce whatever conventions that audit settles on), and CI
  validating a fresh provision connects to the **Write a bootstrap script** item.

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
