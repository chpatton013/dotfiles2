# Followup Queue

Tracked follow-up work, grouped by activity. Each item is tagged with a rough
complexity estimate:

- **Low** — contained to one role/file, roughly a single sitting.
- **Medium** — a few files or some up-front investigation/design.
- **High** — real design work, many files, or large enough to warrant its own
  `docs/plans/` doc (often multi-session).

…and a **Status** so actionable work is identifiable at a glance:

- **Ready** — actionable now; nothing blocking a start.
- **Blocked (on …)** — not actionable until the named prerequisite (another
  queued item, a decision, or hardware) clears.

Both are shown in the tag, e.g. *(Complexity: Medium. Status: Ready.)*.

Remove items when done (git history keeps the record).

Implementation plans in `docs/plans/` (git history keeps deleted ones):

- **Implemented + merged** (kept for reference; the provisioning ones still need
  a live apply / vagrant run to validate): `bootstrap-script.md`,
  `cross-platform-tool-installs.md`, `dynamic-color-theme-propagation.md`,
  `runtime-version-management.md`, `source-build-roles.md`, `vagrant-harness.md`,
  `wezterm-fullscreen-display-changes.md`.
- **Open:** `dev-hygiene-ci.md` (lint + CI — held on a branch pending review);
  `improving-pi-agent-engineering-practices.md` (Pi Agent LLM practices).

## Provisioning & setup

- **Add AlmaLinux (and, if feasible, macOS) setup + Vagrant support.**
  *(Complexity: High. Status: Ready for AlmaLinux; macOS guest Blocked — on
  confirming it's even possible.)* Extend the two-phase model to more platforms:
  - **AlmaLinux (RHEL family):** add a `setup-almalinux/` tree mirroring
    `setup-ubuntu/` / `setup-archlinux/` but built on `dnf` (a new
    package-manager role in place of apt/pacman), plus its `setup.sh` +
    `setup.playbook.yml`, and a `vagrant-env/almalinux` env file. Reuse the
    official AlmaLinux **cloud-images publisher** on Vagrant Cloud (the
    `almalinux/9` box family) rather than a third-party box. Sequence it after
    the Vagrant harness rework lands (the qemu migration + `vagrant-harness.md`
    on the held vagrant branch, not yet on `main`).
  - **macOS as a Vagrant guest:** unclear whether it's possible at all — macOS
    VMs are restricted to Apple hardware and need Apple Virtualization / tart /
    UTM, not the VirtualBox/qemu Vagrant path. Investigate feasibility (e.g. a
    tart-based flow) before committing; may be a no-go. Depends on the settled
    harness direction.
  Touches: a new `setup-almalinux/`, `vagrant-env/`, `vagrant.sh` /
  `Vagrantfile`, and the README "Testing changes" section.

- **Source-build roles don't rebuild when their pinned version changes.**
  *(Complexity: Medium. Status: Ready.)* The `git`/`neovim`/`tmux`/`wezterm`/`zsh`
  build tasks are guarded by `creates:` on the installed binary (e.g.
  `{{xdg_bin_home}}/tmux`, wezterm's `target/release/wezterm-gui` + the app
  bundle). Once a binary exists, bumping `*_release_version` /
  `wezterm_fork_version` and re-applying the role is a **no-op** — it keeps the
  old revision (surfaced during the wezterm `b390263e2` rebuild, which had to
  have its guard targets removed by hand to actually recompile). Guard on a
  revision/version marker instead (a stamp file recording the built version, or
  compare `<bin> --version` to the pin) so a pin change forces a rebuild. This
  undermines the `/update-source-versions` skill and
  `docs/plans/source-build-roles.md`, which both assume re-applying the role
  rebuilds. Touches `config/roles/{git,neovim,tmux,wezterm,zsh}/tasks/main.yml`.

- **Remove the vestigial `pi_node_dir` isolated-node scaffolding.** *(Complexity:
  Low. Status: Deferred by user until later.)* Left over from the rolled-back Pi Agent "Option A"
  (isolated Node runtime); Pi Agent now installs via npm global (Option B), so
  `pi_node_dir` is unused. Remove it from
  `config/roles/pi-agent/{defaults,tasks,templates}` and the `PI_NODE_PREFIX`
  export in `config/files/pi-agent/3-pi-agent.sh`. See
  docs/plans/cross-platform-tool-installs.md.

- **Combine the `zsh` and `zshrc` roles into one.** *(Complexity: Low–Medium.
  Status: Blocked — on confirming the merged role's name/shape.)* The new
  `config/roles/zsh` (source build) and the existing `config/roles/zshrc`
  (renders `~/.zshrc` + links fragments) are currently separate. Merging them is
  fine as long as it stays a single role (no dependency cycle): union the deps
  (`[shellrc, source-releases, xdg]`), fold the build + config tasks together,
  update `config/config.playbook.yml`, and re-verify. NOTE: this reverses the
  deliberate separation in docs/plans/source-build-roles.md Part 1 (kept apart to
  avoid a zsh→zshrc cycle) — confirm the intended role name/shape before
  refactoring.

- **Install a backlog of packages, gated by machine profile.** *(Complexity:
  High — the machine-profile mechanism is the hard part. Status: Blocked — on
  designing a machine-profile mechanism.)* Add: `kubectl`, `octant`, `hub`,
  `graphviz`, `obsidian`, `sensiblesidebuttons`, `signal`, `steam`, `vscode`,
  `postman`, `kindle`, `virtualbox`. The blocker is that there is **no
  machine-profile concept yet** — installs are only split by OS (`setup-macos` /
  `setup-ubuntu` / `setup-archlinux`), not by headless-vs-GUI or work-vs-personal.
  Design that first, then gate:
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

- **Evaluate dotslash for more of this repo's executables (beyond bootstrap).**
  *(Complexity: Medium. Status: Ready.)* We already plan to use dotslash for
  bootstrapping (the now-merged `bootstrap.sh`); investigate where
  else it fits, since it can unify several disparate provisioning strategies
  behind one cross-platform manifest. Current strategies worth reviewing as
  candidates (roles under `config/roles/*/tasks/main.yml` that
  download/build/install executables): source builds — `git`, `neovim`, `tmux`,
  `wezterm`, `zsh`; release-tarball/binary downloads — `git` (git-sizer),
  `bazel`, `lua`, `vim`; language-package installs — `cargo` tools, `python` (uv
  tools). For each, weigh dotslash (fetch a pinned prebuilt binary) against the
  current approach — noting some are deliberately built from source for a
  specific version/patch (e.g. the `wezterm` fork for CSI 2031, see
  docs/plans/dynamic-color-theme-propagation.md, and the pinned source builds
  covered by docs/plans/source-build-roles.md), where dotslash would not apply.

## Neovim

- **Fix IBL indent-guide characters landing in the clipboard on mouse-select in
  nvim.** *(Complexity: Low–Medium. Status: Ready.)* Selecting text with the
  mouse in nvim pulls indent-blankline (IBL) virtual-text indent characters into
  the clipboard. Current hacky workaround: disable IBL during visual mode. IBL
  glyphs are virtual text (not buffer content), so a terminal mouse-drag selects
  the rendered glyphs; a cleaner fix likely routes selection through nvim's own
  mouse (`mouse=a` + a buffer-text yank) or a tidier visual-mode IBL toggle.
  Configured in `config/files/neovim/init.lua` (the `indent-blankline.nvim` /
  `ibl` setup + `ibl_highlight_groups`).

- **Audit the Neovim config composition; decide whether to split `init.lua`.**
  *(Complexity: Medium — investigation + a mechanical refactor. Status: Ready.)*
  The whole config is a single ~1,286-line `config/files/neovim/init.lua` (the
  only file under `config/files/neovim/`). Assess whether to split it into
  multiple files (e.g. by concern: options, keymaps, the lazy.nvim plugin specs,
  LSP, completion, colors/statusline, filetype settings) and, if so, decide the
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
  `docs/plans/` doc. Status: Ready.)* The three seem like they should synergize
  (cursortab = tab/inline completion, minuet = LLM completion source, avante =
  agentic assistant) but the user has not gotten them working together. Current
  state in `config/files/neovim/init.lua`: `cursortab.nvim` is active
  (`init.lua:305-310`); `minuet-ai.nvim` (config `init.lua:180-189`, spec/cmp
  source around `:320`/`:428-432`/`:1127`, lualine `:572`) and `avante.nvim`
  (`init.lua:327-404`, with endpoints for anthropic, moonshot, and a local
  `http://127.0.0.1:8765/v1`) are commented out. Two parts:
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
  — a separate plugin project in its own repo. Status: Ready.)* Replace the
  experimental `nosduco/remote-sshfs.nvim` fork the user has been trying (a local
  fork at `~/github/chpatton013/remote-sshfs.nvim`, wired but commented out in
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

- **Polish the Neovim completion UX.** *(Complexity: Medium. Status: Ready.)* The
  current setup is unintuitive about when to press `<Tab>` vs. arrow keys to
  explore the completion menu, and successive attempts to add completion
  plugins/behaviors have made it more confusing rather than less. The user does
  not yet know exactly what they want, or which built-in completion options
  Neovim offers — so step one is likely to survey the options (Neovim's built-in
  ins-completion and the native LSP completion in 0.11+, `completeopt`) and
  decide how much can be done without plugins, then settle on one coherent
  keybinding story. Current stack in `config/files/neovim/init.lua`: `nvim-cmp`
  (`init.lua:412`) with sources buffer/cmdline/nvim-lsp/nvim-lua/path, `LuaSnip`
  (`init.lua:435-440`), and `cursortab.nvim` (`init.lua:305-310`, AI
  tab-completion). Likely a root cause of the `<Tab>` confusion: `cursortab` and
  cmp/LuaSnip both want `<Tab>`. (Recent churn here — see commit `b82442b`
  "nvim: cmp cleanup".)

## Terminal & theming

- **Replace the hand-rolled tmux statusline and shell PS1 with a prettier,
  consistent system.** *(Complexity: Medium. Status: Ready.)* Why: the current
  styling was built to avoid relying on patched fonts, which is no longer a
  constraint — it is simple and high-viz but not pretty. Goals: visual
  consistency for status/prompt styling across tmux, nvim, pi agent, etc. (and
  potentially zsh), and a PS1 that looks the same in **both zsh and bash**.
  Current pieces to replace/reconcile:
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

- **Delete all remnants of Karabiner.** *(Complexity: Low. Status: Ready.)*
  Remove the leftover Karabiner-Elements config: the tracked
  `config/files/karabiner/karabiner.json` (and its `config/files/karabiner/`
  dir). Nothing links it — there is no `config/roles/karabiner`, no
  `config.playbook.yml` entry, and no setup cask (a repo-wide grep finds no
  other `karabiner` references), so it is an orphaned config file; just delete
  it. Also drop the Karabiner mentions in `docs/plans/dev-hygiene-ci.md` (cited
  as a JSON/JSONC lint-target example, ~lines 36 and 306). Mirror the earlier
  iTerm/Alacritty removal (commit `557f416`); also check for stray user-space
  state (`~/.config/karabiner`).

- **Add dev-hygiene tooling: file validation + GitHub Actions CI.**
  *(Complexity: Medium. Status: Selected.)* Port the patterns from the user's
  `chiiiirrus` repo (https://github.com/chpatton013/chiiiirrus/) — file
  validation (likely pre-commit hooks / formatters / linters) and a GitHub
  Actions CI workflow. None exist here yet (no `.github/`,
  `.pre-commit-config.yaml`, `.yamllint`, or `.ansible-lint`). Lint targets by
  prevalence in the repo: YAML (147 `.yml` / Ansible playbooks+roles), shell (46
  `.sh`, 4 `.bash`, 6 `.zsh`), lua (nvim / wezterm config), json, gitconfig.
  Candidate tools: `yamllint` + `ansible-lint` for the playbooks, `shellcheck`
  for scripts, `stylua`/`luacheck` for lua, `vim-vint` (already installed via
  `config/roles/python`). See docs/plans/dev-hygiene-ci.md. Pairs naturally with
  the **Audit the project** item (CI would enforce whatever conventions that
  audit settles on), and CI validating a fresh provision connects to the merged
  `bootstrap.sh`.

- **Audit the project for anti-patterns and simplification opportunities.**
  *(Complexity: Medium; open-ended. Status: Ready.)* A broad, project-wide
  review of `config/` and `setup-*/` against the conventions documented in
  `AGENTS.md` (role structure, shellrc load-order, alphabetized lists, symlink
  pattern), looking for cruft, duplication, and footguns. Defer the actual
  analysis until this is picked up; the `/simplify` and `/code-review` skills may
  help. Seeds noticed already (starting points, not the full list):
  - **Role taggability:** `color-theme` was defined only as a transitive
    dependency, so `--tags color-theme` was a no-op until fixed this session;
    audit other roles for the same (any role only reachable via `meta`
    dependencies is not independently applicable).
  - **Duplication:** the repetitive dark/light functions in
    `config/files/color-theme/color-theme` and the parallel structure in
    `config/files/tmux/tmux-theme`.
  - **README drift:** the `README.md` TODO scratchpad is being migrated into
    this queue piecemeal; finish emptying it and trim the file.

## Security

- **Audit and configure quantum-safe (post-quantum) encryption across the tools
  this repo manages.** *(Complexity: Medium. Status: Ready.)* Goal: protect
  confidentiality against "harvest-now, decrypt-later" quantum attacks wherever
  practical. Surfaces, most-actionable first:
  - **SSH (the clear win).** OpenSSH's PQ protection is in the key *exchange*
    (session confidentiality), not host-key auth (no standardized PQ signatures
    yet). Prefer a PQ `KexAlgorithms` in the ssh *client* config —
    `mlkem768x25519-sha256` (OpenSSH 9.9+/10) and
    `sntrup761x25519-sha512@openssh.com` (default since 9.0). The repo does
    **not** manage `~/.ssh/config` today (only
    `config/roles/ssh-agent-canonicalize`, an agent helper), so this likely
    needs a new ssh-config role/fragment. Also confirm the OpenSSH version from
    `setup-*/roles/dev-tools` (+ `setup-ubuntu/roles/ssl`) is new enough for
    these KEX.
  - **Symmetric / at-rest** (FileVault, LUKS, AES-256): already
    quantum-resistant (Grover only halves the effective key length); no action
    beyond preferring 256-bit.
  - **GPG / OpenPGP:** no standardized PQ algorithms in GnuPG yet, and the repo
    manages no gpg config — nothing actionable now; revisit when PQC lands.
  - **TLS clients** (curl/browsers, e.g. X25519MLKEM768): emerging but
    library/app-driven, not dotfiles config; note but likely out of scope.
  Deliverable: a short findings note + the concrete SSH `KexAlgorithms` change,
  gated on the installed OpenSSH supporting it.
