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

Implementation plans in `docs/plans/` (git history keeps deleted ones — plans are
removed once their work merges):

- **Open:** `dev-hygiene-ci.md` (lint + CI — held on a branch pending review);
  `improving-pi-agent-engineering-practices.md` (Pi Agent LLM practices).

The provisioning + terminal work merged this session (bootstrap, runtime
management, source builds, vagrant harness, color-theme propagation, wezterm
fullscreen, the unified statusline/prompt) still wants a live apply / vagrant run
to validate end-to-end; those plans now live only in git history.

## Provisioning & setup

- **Design an auto-bootstrapping executable-distribution system; build two
  plans (separate repo vs. in this repo).** *(Complexity: High. Status: Plans
  drafted on a branch, pending review.)* Consolidate auto-bootstrapping
  executable runners (dotslash, uv, bun — per the user's `chiiiirrus` repo) plus
  the file-validator suite + pre-commit hook, behind a manifest and a renderer
  script that emits each tool's executable from a per-bootstrap-method template.
  It could also host the helpers for building the wezterm fork and anything else
  the user wants to build + publish releases for; a consuming repo could just
  download+extract a release tarball onto PATH. **Deliverable: two plans** — (a)
  as a **separate repository** this dotfiles repo distributes to the machine
  (written so a fresh agent with NO context of this repo/session could build it),
  and (b) as a **new part of this dotfiles repo**, possibly with a repo reorg.
  Both drafts are written on an unmerged worktree branch
  (`docs/plans/bin-distribution-separate-repo.md` +
  `bin-distribution-in-repo.md`); next step is reviewing/merging them and picking
  an approach to implement. See github.com/chpatton013/chiiiirrus.

- **Add AlmaLinux (and, if feasible, macOS) setup + Vagrant support.**
  *(Complexity: High. Status: Ready for AlmaLinux; macOS guest Blocked — on
  confirming it's even possible.)* Extend the two-phase model to more platforms:
  - **AlmaLinux (RHEL family):** add a `setup-almalinux/` tree mirroring
    `setup-ubuntu/` / `setup-archlinux/` but built on `dnf` (a new
    package-manager role in place of apt/pacman), plus its `setup.sh` +
    `setup.playbook.yml`, and a `vagrant-env/almalinux` env file. Reuse the
    official AlmaLinux **cloud-images publisher** on Vagrant Cloud (the
    `almalinux/9` box family) rather than a third-party box. The Vagrant harness
    rework (qemu migration) is now merged, so this can start.
  - **macOS as a Vagrant guest:** unclear whether it's possible at all — macOS
    VMs are restricted to Apple hardware and need Apple Virtualization / tart /
    UTM, not the VirtualBox/qemu Vagrant path. Investigate feasibility (e.g. a
    tart-based flow) before committing; may be a no-go.
  Touches: a new `setup-almalinux/`, `vagrant-env/`, `vagrant.sh` /
  `Vagrantfile`, and the README "Testing changes" section.

- **Remove the vestigial `pi_node_dir` isolated-node scaffolding.** *(Complexity:
  Low. Status: Deferred by user until later.)* Left over from the rolled-back Pi
  Agent "Option A" (isolated Node runtime); Pi Agent now installs via npm global
  (Option B), so `pi_node_dir` is unused. Remove it from
  `config/roles/pi-agent/{defaults,tasks,templates}` and the `PI_NODE_PREFIX`
  export in `config/files/pi-agent/3-pi-agent.sh`.

- **Combine the `zsh` and `zshrc` roles into one.** *(Complexity: Low–Medium.
  Status: Blocked — on confirming the merged role's name/shape.)* The new
  `config/roles/zsh` (source build) and the existing `config/roles/zshrc`
  (renders `~/.zshrc` + links fragments) are currently separate. Merging them is
  fine as long as it stays a single role (no dependency cycle): union the deps
  (`[shellrc, source-releases, xdg]`), fold the build + config tasks together,
  update `config/config.playbook.yml`, and re-verify. NOTE: this reverses the
  deliberate separation that kept the source-build role apart to avoid a
  zsh→zshrc cycle — confirm the intended role name/shape before refactoring.

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
  specific version/patch (e.g. the `wezterm` fork for CSI 2031, and the pinned
  source builds), where dotslash would not apply. Overlaps the bin-distribution
  item above.

## Neovim

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
  state in `config/files/neovim/init.lua`: `cursortab.nvim` is active;
  `minuet-ai.nvim` and `avante.nvim` (with endpoints for anthropic, moonshot, and
  a local `http://127.0.0.1:8765/v1`) are commented out. Two parts:
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
  `config/files/neovim/init.lua`). Why the current one falls short: poor
  ssh-config parsing that relies on data embedded in structured comments. Desired
  improvements (user's list):
  - A proper ssh-config parser (no reliance on structured-comment metadata).
  - Connection pooling within the nvim server.
  - Clear visual indicators when the session is working inside an sshfs mount.
  - Intelligently delegate remote commands over the ssh connection rather than
    reading every file over the sshfs link.
  - Generalized picker integration so it does not hard-depend on telescope —
    the user's picker is fzf (`fzf-lua`; telescope is also present).
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
  with sources buffer/cmdline/nvim-lsp/nvim-lua/path, `LuaSnip`, and
  `cursortab.nvim` (AI tab-completion). Likely a root cause of the `<Tab>`
  confusion: `cursortab` and cmp/LuaSnip both want `<Tab>`. (Recent churn here —
  see commit `b82442b` "nvim: cmp cleanup".)

## Terminal & theming

- **Build a two-sided (left + right) shell prompt that reflows on terminal
  resize.** *(Complexity: Medium. Status: Ready.)* Investigate rendering the
  prompt with sections pinned to **both** the left and right edges that stay
  correctly placed when the terminal is resized. Extends the unified renderer
  `config/files/prompt/dotfiles-prompt` (currently emits a single left-aligned
  PS1 string per surface; already re-renders every command via the zsh precmd /
  bash PROMPT_COMMAND wrappers `config/files/zshrc/4-prompt.zsh` and
  `config/files/bashrc/4-prompt.bash`). Points to investigate:
  - **zsh** has native right-side prompt support (`RPROMPT`/`RPS1`), which the
    renderer would need a new `dotfiles-prompt zsh-right` mode (or similar) to
    feed. **bash** has no native right prompt — it must be emulated (e.g. print
    the right segment with cursor positioning / `\[...\]` + `$COLUMNS`
    arithmetic inside the PS1), which is the harder half.
  - **Reflow:** because both wrappers already re-render on every command,
    `$COLUMNS` is fresh at prompt draw; true reflow of an *already-drawn* line
    on resize needs a `SIGWINCH`/`TRAPWINCH` redraw. Decide whether re-render-on-
    next-command is sufficient or a winch trap is wanted.
  - Keep the glyph-vs-ASCII vocabulary and color-theme sourcing already in
    `dotfiles-prompt`. Relates to the **Prettier styling** item below.

- **Prettier styling for the unified prompt/statusline (nerd-font glyphs).**
  *(Complexity: Medium. Status: Ready.)* The tmux statusline and zsh/bash PS1 are
  now unified into one consistent, color-theme-aware renderer
  (`config/files/prompt/dotfiles-prompt`, drawing zsh/bash/tmux from the same
  semantic slots), so the cross-shell-consistency goal is met and the prompt
  looks the same in zsh and bash. What remains is making it *pretty*: the styling
  was originally built to avoid patched fonts, which is no longer a constraint.
  Investigate nicer glyph-based separators/segments (the renderer already carries
  a glyph-vs-ASCII vocabulary gated on `PROMPT_GLYPHS` → `TERM_GLYPHS`) and a
  coherent palette across tmux/nvim/pi-agent. Needs a nerd font:
  `font-symbols-only-nerd-font` is now installed on macOS
  (`setup-macos/roles/dev-tools`), but wezterm still uses plain `Monaco`
  (`config/files/wezterm/wezterm.lua`) — wire the font in. Pairs with the
  two-sided reflow item above.

- **Fix wezterm fullscreen sizing after disconnecting a lid-closed external
  display.** *(Complexity: Medium. Status: Ready.)* Repro: laptop connected to an
  external display with the **lid closed**; disconnect the display, open the lid,
  log back in → fullscreen terminal windows don't fit the screen. Unclear whether
  they failed to resize at all, or resized before the notch inset kicked in.
  Another fullscreen/display-change edge case beyond the merged fixes — relates
  to the fork's screen-parameter/notch handling (`wezterm_fork_version`; the
  `NSApplicationDidChangeScreenParameters` reapply + own-screen inset logic).
  Needs the hardware repro; likely another fork-side fix.

## Repo hygiene & tooling

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
    `config/files/tmux/tmux-theme` (the latter may now be superseded by
    `dotfiles-prompt` — confirm and remove if unused).
  - **README drift:** the `README.md` TODO scratchpad is being migrated into
    this queue piecemeal; finish emptying it and trim the file.
