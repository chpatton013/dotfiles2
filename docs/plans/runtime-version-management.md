# Cross-Platform Runtime Version Management (the rbenv/pyenv problem)

> **Status: implemented (config + setup pruning); pending a live apply.** mise
> adopted; `go`/`gem`/`npm` reparented; `lua` config role removed; the redundant
> go/node/ruby/lua runtime installs pruned from all three `setup-*` phases.
> The Linux source-build deps mise's ruby/lua compiles need were added to the
> setup phase too. Decisions below were approved: adopt mise; keep uv (Python)
> and rustup (Rust) independent; Node via mise's node backend. **Remaining: a
> live `setup.sh` + `config.sh` run to validate — only `--syntax-check` /
> YAML-load ran here.**

## Context

The `docs/followups.md` item (Provisioning & setup) asks for a single
cross-platform strategy for scripting-language runtime versions, then to
reconcile the existing `config/roles/{go,lua,ruby,gem,npm,python,cargo}` roles
with it. Two things need untangling first, because the current roles conflate
them:

1. **Runtime provisioning** — where the `go` / `node` / `ruby` / `lua` / `python`
   / `rust` interpreter-or-toolchain comes from, and how its *version* is chosen.
2. **Dev-tool installs** — the CLI packages this repo installs *on top of* each
   runtime (shfmt, eslint, rubocop, ripgrep, black, …) into isolated,
   PATH-exposed per-language dirs.

The config "language roles" today mostly do job #2 and silently assume job #1 is
handled elsewhere (by the `setup-*` phase's native package manager). There is no
version management at all — you get whatever version brew / apt / pacman ships.

### Where runtimes come from today

| Runtime | macOS (`setup-macos/roles/dev-tools`) | Linux (`setup-ubuntu` / `setup-archlinux`) | Version management |
| ------- | ------------------------------------- | ------------------------------------------ | ------------------ |
| Go      | `golang` brew formula                 | `golang-go` apt (PPA) / `go` pacman        | none (distro pin)  |
| Node    | `node` brew formula                   | `nodejs`+`npm` apt / `nodejs` pacman       | none               |
| Ruby    | `ruby` brew formula (`brew link --force`) | `ruby`+`ruby-dev` apt / `ruby` pacman   | none               |
| Lua     | `lua` brew formula                    | source build (config `lua` role, Linux only) / `lua` pacman | pinned tarball on Linux, distro on mac |
| Python  | `python` brew formula, **but** superseded by `uv` (config `python` role) | `python3` apt / distro | **uv** (already good) |
| Rust    | `rustup` (config `rust` role, user-space) | same `rust` role | **rustup** (already good) |

So: **Python and Rust already have real, cross-platform, user-space version
managers** (`uv`, `rustup`). Go / Node / Ruby / Lua do not — they ride on
whatever the OS package manager gives, which defeats the repo's "every machine
feels identical" goal and can't pin a version per project.

### What the config language roles actually do

- **`go`** — `go install`s `shfmt`, `buildifier`, `buildozer` into
  `{{go_data_dir}}` (`~/.local/share/dotfiles/go`); links `3-go.sh` (sets
  `GO111MODULE=on`, puts `~/go/bin` on PATH); symlinks `~/go` → `go_data_dir`.
  Consumes a Go toolchain from PATH.
- **`lua`** — **Linux-only** source build of Lua 5.4.6 into `{{xdg_prefix_home}}`
  (`when: os_family != "Darwin"`). No shellrc fragment, no dev-tools. macOS gets
  Lua from brew. This role is *only* a runtime provisioner.
- **`ruby`** — **does not exist** as a config role. The followup lists it, but
  there is only a `gem` role. Ruby the runtime comes entirely from `setup-*`.
- **`gem`** — `gem install`s `neovim` (→ `neovim-ruby-host`), `rubocop`, `sass`
  into `{{gem_data_dir}}`; sets `GEM_HOME` + PATH via `3-gem.sh`. Consumes a Ruby
  from PATH.
- **`npm`** — `npm -g` installs `eslint`, `eslint-plugin-vue`, `js-beautify`,
  `neovim` (→ `neovim-node-host`), `remark-cli` into `{{npm_data_dir}}`; sets
  `NPM_PREFIX`/`NODE_PATH`/PATH and renders `~/.npmrc` (`prefix`). Consumes Node
  from PATH.
- **`python`** — installs `uv`; `uv python install --default`; `uv tool install`
  awscli/black/git-filter-repo/grip/vim-vint (+ gdbgui on 3.11); creates the
  pynvim provider venv. This is the model to copy: a real version manager owning
  the runtime, tools installed on top.
- **`cargo`** — `cargo install`s ripgrep/fd/delta/bat/tree-sitter-cli via the
  `rust` role's `rustup`-provided cargo, plus bat config + bat-extras. Consumes
  the user-space rustup toolchain (`{{rust_cargo_home}}`).

Key realization: **`python` and `cargo` are already the target shape** — a
user-space version manager (`uv` / `rustup`) owns the runtime, and a thin role
installs dev-tools onto it. The work is to bring Go / Node / Ruby / Lua up to
that same shape with a single unifying manager, without regressing the two that
already work.

## The manager survey

### mise (formerly rtx) — the proposed unifier

- Single fast Rust binary; **entirely user-space** (installs to `~/.local/bin`,
  data under `~/.local/share/mise`) — no root, so it fits the repo's emerging
  "uniform user-space installs into `~/.local`, one mechanism per tool across all
  OSes" principle (see `docs/plans/cross-platform-tool-installs.md`).
- Manages many runtimes (node, ruby, go, lua/luajit, python, java, …) via
  asdf-compatible plugins **plus** its own faster backends (aqua, ubi, core).
- Per-project pinning via `mise.toml` / `.tool-versions` (asdf-compatible), plus
  a global default set (`mise use -g node@lts ruby@3.3 …`).
- Activation model: either `mise activate` (injects into shell, resolves per-dir
  on `cd`) or `mise activate --shims` (a static `~/.local/share/mise/shims` dir
  of shim executables that works in **non-interactive / GUI-launched** processes
  too). The shims mode is important for the Neovim provider hosts (below).
- Can install CLI tools too (via aqua/ubi/npm/cargo/pipx backends) — so it could
  in principle subsume parts of the dev-tool installs, though we do **not**
  propose that in v1.

### Alternatives considered

- **asdf** — mise's shell-based predecessor. Same plugin ecosystem and
  `.tool-versions` format, but slower (shell, not Rust) and needs a runtime
  dependency chain. mise is a strict upgrade for our use; no reason to pick asdf.
- **fnm / volta** (Node-only) — both Rust, cross-platform, per-project pinning.
  Excellent single-purpose Node switchers. But adopting one *and* mise means two
  managers with two config formats; mise's node backend already covers this.
  Only worth it if Node switching perf/DX under mise proves inadequate.
- **rbenv / pyenv / nvm / gvm** — the classic per-language shell managers. Each
  is one-language, shell-based, and per-OS-fiddly to install. Adopting mise is
  precisely to *avoid* a zoo of these. Not recommended.
- **uv** (Python) — already adopted; see recommendation. uv is a better Python
  manager than mise's python plugin for our workflow (it also owns tools + venvs).
- **rustup** (Rust) — the canonical, Rust-team-blessed toolchain manager;
  user-space; already adopted via the `rust` role. mise *has* a rust backend but
  upstream itself recommends rustup for real Rust work. Keep rustup.

## Recommendation

**Adopt `mise` as the cross-platform runtime version manager for Go, Node, Ruby,
and (optionally) Lua — as a new user-space `config/` role — while keeping the two
managers that already work (`uv` for Python, `rustup` for Rust) independent.**

Rationale:
- One asdf-compatible tool, one config format (`.tool-versions` / `mise.toml`),
  pinnable per project and globally — this is the actual "rbenv/pyenv problem"
  fix the followup asks for.
- Because mise is user-space, the runtimes move **out of `setup-*`** (brew / apt
  / pacman) and **into `config/`**, giving identical versions and update stories
  on every OS, including headless remotes without package-manager privileges —
  exactly the pattern `cross-platform-tool-installs.md` established for the
  agents.
- Don't fold in `uv`/`rustup`: they're already best-in-class for their languages,
  already user-space, already give reproducible versions. Folding them into mise
  would be churn with a functional regression risk and no upside. (If a *project*
  pins python/rust via `.tool-versions`, mise can delegate to its uv/rustup-style
  backends without us changing the dotfiles' own tooling.)

Placement: a new **`config/roles/mise`** role (user-space install of the mise
binary into `~/.local/bin`, an activation fragment, and a rendered global
`config.toml` / `.tool-versions` pinning default versions). It becomes a `meta`
dependency of the `go`, `gem`, `npm`, and (if kept) `lua` roles, replacing their
implicit reliance on a `setup-*`-provided runtime. The corresponding runtime
lines are then removed from `setup-macos/roles/dev-tools` and the Linux setup
roles.

### Activation: use shims, globally on PATH

Add `~/.local/share/mise/shims` to PATH via a `1-*` shellrc fragment (or fold
into the `9-*` PATH fixup) **and** rely on `mise activate` for interactive
per-directory resolution. The shims dir matters because it makes mise-managed
runtimes resolvable from **non-interactive and GUI-launched** processes — which
is what the Neovim provider hosts need (below). This is the mechanism that closes
the "full runtime isolation is deferred to the runtime-version-management
follow-up" note in `config/roles/neovim/templates/providers.lua`.

## Role-by-role reconciliation

### `go` — keep, reparent onto mise
- Runtime: drop the implicit brew/apt/pacman Go dependency; add `mise` to
  `meta/main.yml`, pin `go` in the global mise versions. Remove `golang` from
  `setup-macos/roles/dev-tools` and the `setup-ubuntu/roles/go` /
  `setup-archlinux` Go install.
- Dev-tools (`shfmt`, `buildifier`, `buildozer`) and `3-go.sh` / `~/go` symlink:
  **keep as-is**; they now run against mise's Go. The `go_version` gate
  (`go get` vs `go install`) can be simplified once the version is mise-pinned
  (always modern), but that's optional cleanup.

### `lua` — drop the source build; runtime optional via mise
- The Linux-only 5.4.6 source build exists only to provide a `lua` interpreter.
  Neovim and WezTerm each **embed their own LuaJIT** and run their configs with
  it, so a managed system Lua is needed only for ad-hoc scripting / luarocks.
- Recommendation: **remove the `lua` config role's source build** (and the `lua`
  brew formula / distro packages) and, *if* ad-hoc Lua is still wanted, pin
  `lua` or `luajit` in mise instead. If ad-hoc Lua is not actually used, drop
  Lua entirely. Either way this role either disappears or becomes a two-line mise
  pin — a clear simplification.

### `ruby` — no role to reconcile; runtime moves to mise
- There is **no `config/roles/ruby`** (the followup lists it, but only `gem`
  exists). "Reconciling ruby" means: stop getting Ruby from `setup-*`
  (`ruby` brew formula + the `brew link --force ruby`, plus `ruby`/`ruby-dev` on
  Linux) and pin `ruby` in mise instead. No new role needed unless we want a
  dedicated one; the `gem` role already carries the Ruby-side dev-tools.

### `gem` — keep, reparent onto mise
- Add `mise` to `meta`; `gem install` now targets mise's Ruby. `GEM_HOME` stays
  `{{gem_data_dir}}` so `rubocop` / `sass` / `neovim-ruby-host` still land in an
  isolated, PATH-exposed dir independent of the Ruby version.
- Watch item: with a mise-managed Ruby, confirm `gem` resolves to mise's `gem`
  (via shims) at provision time. The existing comment in the role about the
  ansible `gem` module's `~/.gem` divergence still applies — keep the explicit
  `gem install --install-dir/--bindir` with the per-item `creates` guard.

### `npm` — keep, reparent onto mise
- Add `mise` to `meta`; Node comes from mise. Keep `NPM_PREFIX` / `~/.npmrc`
  `prefix` = `{{npm_data_dir}}` so global installs (eslint, neovim-node-host, …)
  stay isolated from the Node version.
- Remove `node` from `setup-macos/roles/dev-tools` and the Linux `node` roles.
- Node manager decision: **use mise's node backend** (not fnm/volta) unless
  switching DX proves inadequate — see decisions.

### `python` — keep on uv, unchanged
- No change. uv already owns Python versions + tools + the pynvim venv and
  supersedes pyenv/pipx for our use. Do **not** route Python through mise.
- Optional (low priority): register the uv-installed Python with mise so
  `.tool-versions` files that pin python resolve, or let mise's uv backend handle
  project pins. Not required for the dotfiles' own tooling; decide per the
  "keep uv independent?" question.

### `cargo` — keep on rustup, unchanged
- No change. The `rust` role's user-space `rustup` already provides a
  cross-platform, pinnable toolchain, and `cargo install` puts the CLI tools
  (ripgrep/fd/delta/bat/tree-sitter-cli) where the shellrc expects. Do **not**
  fold Rust into mise.

### Interaction with the Neovim provider hosts
`config/roles/neovim/templates/providers.lua` pins three host programs:
- `python3_host_prog` → `{{python_neovim_venv_dir}}/bin/python3` — an absolute uv
  venv interpreter, already fully env-independent. **No change.**
- `node_host_prog` → `{{npm_data_dir}}/bin/neovim-node-host` and
  `ruby_host_prog` → `{{gem_data_dir}}/bin/neovim-ruby-host` — the launcher paths
  are pinned, **but those scripts still resolve their own `node` / `ruby` via
  PATH**. Today that only works from a provisioned interactive shell; a
  GUI-launched nvim (bare env) can't find node/ruby, which is the isolation gap
  the providers.lua comment defers to *this* follow-up.
- Fix under mise: the `3-mise.sh` fragment puts `~/.local/share/mise/shims` on
  PATH for every provisioned shell, so `neovim-node-host` / `neovim-ruby-host`
  resolve a deterministic, mise-pinned node/ruby (a single stable shims dir
  rather than a version-specific bin dir). This is the concrete payoff of mise
  for the provider story. Caveat: a shellrc fragment only affects **shells** — an
  nvim launched from a GUI with a bare PATH still won't see the shims unless the
  shims dir is exported into the GUI login environment (e.g. `launchctl setenv`
  on macOS) or the host launchers are pinned to absolute mise shim paths; that
  fully-GUI-proof step is a possible follow-up. (`perl` stays disabled —
  `loaded_perl_provider = 0`.)

## What was implemented (config side)

1. **`config/roles/mise`** — user-space install of the mise binary via the
   official installer (`curl https://mise.run | sh`) into `~/.local/bin`
   (uniform across OSes, mirroring the `python`/`rust` roles; config phase never
   uses brew). Renders a global `config.toml` pinning `go`, `lua@5.4.6`,
   `node@lts`, `ruby`; runs `mise install` + `mise reshim`. Uses mise's default
   dirs (`$XDG_DATA_HOME/mise`, `$XDG_CONFIG_HOME/mise`) so shims resolve without
   env plumbing.
2. **`config/files/mise/3-mise.sh`** — shell-agnostic fragment (works in bash and
   zsh) exporting `MISE_DATA_DIR`/`MISE_CONFIG_DIR` and prepending the shims dir
   to PATH via `prepend_pathlist`. Chose the shims model over `mise activate`
   precisely because it is shell-agnostic and works in non-interactive processes.
3. **Reparented** `go`, `gem`, `npm`: added `mise` to each `meta/main.yml` and
   prepended `{{mise_shims_dir}}` to the dev-tool install tasks' `environment.PATH`
   so the runtime resolves to mise at provision time. All dev-tool installs stay
   in their existing `*_data_dir` (`go_data_dir`, `gem_data_dir`, `npm_data_dir`).
4. **Removed** the `lua` config role (source build) and its `config.playbook.yml`
   entry; Lua the runtime now comes from the mise pin. Added `mise` to the
   playbook (alphabetical, between `go` and `neovim`).
5. **Neovim providers preserved**: `providers.lua` is untouched. The node/ruby
   host launchers still live in `npm_data_dir`/`gem_data_dir`; with the shims dir
   on PATH they now resolve a deterministic mise-pinned node/ruby, closing the
   PATH gap the providers.lua comment flagged. The python uv provider venv is
   unchanged.

## Remaining work

- **Setup-* runtime pruning — DONE** (static edits, needs a live `setup.sh` to
  verify). Removed the now-redundant runtimes mise owns:
  - `setup-macos/roles/dev-tools`: dropped `golang`, `lua`, `node`, `ruby` brew
    formulae. (This worktree's base had no `brew link --force` task, so nothing to
    prune there.)
  - `setup-ubuntu`: dropped `go`, `lua`, `node`, `ruby` from
    `roles/dev-tools/meta` and **deleted** the four runtime-only roles
    `roles/{go,lua,node,ruby}`.
  - `setup-archlinux/roles/dev-tools`: dropped `go`, `lua`, `nodejs`, `ruby` from
    the pacman list.
  - **Deliberately kept**: `python` (owned by uv, still a bootstrap prereq),
    `neovim` / `vim` (not mise-managed), and — critically — the vim role's own
    build deps `lua5.3` / `liblua5.3-dev` / `python3-dev` / `ruby-dev`
    (`setup-ubuntu/roles/vim`), which compile vim with lua/python/ruby support and
    are genuine build dependencies, not runtimes. Untouched.
- **Linux source-build deps for mise — DONE** (static edits, needs a live
  `setup.sh` + `config.sh` to verify). mise installs **node/go as prebuilt
  binaries** (no build deps), but compiles **ruby (via ruby-build) and lua from
  source**. Previously ruby/lua came as prebuilt distro packages, so their build
  deps were never required; now they are:
  - `setup-ubuntu/roles/dev-tools` (apt): added `libssl-dev`, `libreadline-dev`,
    `libyaml-dev` (ruby-build needs all three; lua needs `libreadline-dev`).
    `build-essential` + `zlib1g-dev` were already present.
  - `setup-archlinux/roles/dev-tools` (pacman): added `libyaml` only. `openssl`
    and `readline` are core packages guaranteed present (pacman depends on
    openssl; `bash` in `base` depends on readline), and `base-devel` is already
    installed by the `aur` and `neovim` roles — all of which run in the setup
    phase before the config-phase `mise install`, so they are available in time.
  - **macOS**: nothing added — Homebrew supplies `openssl`/`readline`/`libyaml`
    transitively (as deps of other formulae) and ruby-build discovers them, so a
    mac apply needs no extra setup packages. Confirm on first live run.
- **Live validation** — only `--syntax-check` + a YAML-load ran (the macOS/arch
  setup syntax-checks also surface pre-existing missing-collection errors —
  `community.general`, `kewlfft.aur` — unrelated to these edits). A real
  `config/config.sh --tags mise,go,gem,npm,neovim` apply is needed to confirm:
  mise installs; runtimes resolve to mise; dev-tools land in the isolated dirs;
  first-time Ruby/Lua compile from source succeeds (needs the deps above); nvim
  `:checkhealth provider` node/ruby hosts pass, including from a GUI-launched
  nvim (which depends on the shims dir being on the GUI's PATH — see risks).

## Decisions for the user

1. **Adopt mise as the unifier for Go/Node/Ruby/Lua?** Recommend **yes**. One
   asdf-compatible, user-space, cross-platform manager; runtimes move out of
   `setup-*` into `config/`. Tradeoff: a new dependency and a shims-on-PATH
   activation step; first Ruby build compiles from source (slow on headless/CI).
2. **Keep uv independent for Python (vs. mise-owned)?** Recommend **keep uv
   independent**. uv already owns versions + tools + venvs and beats mise's python
   plugin for our workflow. Tradeoff: two managers coexist, and a project's
   `.tool-versions` python pin isn't honored unless we register uv's python with
   mise (optional).
3. **Node manager under mise, or a dedicated fnm/volta?** Recommend **mise's node
   backend**. Tradeoff: fnm/volta have marginally snappier per-dir Node switching;
   choosing one means two managers/config formats for no real gain here.
4. **Keep rustup for Rust (vs. mise)?** Recommend **keep rustup**. It's the
   canonical toolchain manager, already user-space, and upstream mise itself
   defers to it. Tradeoff: Rust stays outside the single `.tool-versions` story.
5. **Drop any existing roles?** Recommend **drop the `lua` source-build role**
   (nvim/WezTerm embed their own LuaJIT; managed Lua is only for ad-hoc/luarocks)
   — either remove Lua entirely or replace with a one-line mise pin. No `ruby`
   config role exists to drop. `python`/`cargo` stay unchanged. Tradeoff: if you
   do use ad-hoc Lua/luarocks, keep the mise pin rather than removing outright.
</content>
