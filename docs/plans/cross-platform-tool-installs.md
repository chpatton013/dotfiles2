# Cross-Platform Tool Installs: ollama, Claude Code, Pi Agent

## Context

Three tools tied to the local-LLM / agent workflow are provisioned only on
macOS, or not at all. This plan closes the gaps for the two followups in
`docs/followups.md` (Provisioning & setup):

- **ollama** — the local LLM backend Pi Agent uses. Installed and started only
  on macOS: `setup-macos/roles/dev-tools/tasks/main.yml` installs the `ollama`
  brew formula and starts it via `homebrew_services` (`state: present`). No
  install or service on `setup-ubuntu` / `setup-archlinux`.
- **Claude Code** — installed only on macOS, via the `claude-code` brew cask
  (same `dev-tools` file). No Linux install.
- **Pi Agent** — has a config-only role (`config/roles/pi-agent`: symlinks
  `settings.json`/`models.json`, creates dirs incl. `pi_node_dir` =
  `~/.local/share/pi-node`) but **nothing installs the agent** on any host. The
  shell fragment `config/files/pi-agent/3-pi-agent.sh` already puts
  `$PI_NODE_PREFIX/current/bin` on `PATH`, anticipating an isolated node
  runtime + agent under that dir — which never gets populated.

## The recurring decision: `setup-*` vs `config/`

The repo's two-phase model (AGENTS.md) is the deciding axis:

- **`setup-*`** = installs software onto the *system*, **requires root**,
  package-manager-specific per platform.
- **`config/`** = configures *user space*, **never needs root**,
  platform-agnostic.

Apply that test per tool:

| Tool        | Needs root?              | Recommendation |
| ----------- | ------------------------ | -------------- |
| ollama      | yes (system pkg + service) | **`setup-*`** — per-OS native package managers; the one tool not cross-OS-uniform (artifact reality, §1) |
| Claude Code | no (native installer → `~/.local`) | **`config/`** — cross-platform user-space role; retire the macOS brew cask |
| Pi Agent    | no (node + npm into `~/.local/share`) | **`config/`** — extend the existing `pi-agent` role |

Net effect: the two agents (Claude Code, Pi Agent) become uniform user-space
`config/` installs into `~/.local` that behave identically on macOS and Linux
(incl. headless remotes without package-manager privileges). ollama is the one
exception — it stays a per-OS `setup-*` system install via native package
managers, because its release artifacts don't suit a clean uniform binary-drop
(§1); a future dotslash migration could unify it.

---

## Guiding principle: one mechanism per tool, across all OSes

Each tool uses a **single install + update mechanism on every supported OS**,
rather than per-OS-native package managers — even at the cost of not using brew /
apt / pacman. Concretely: fetch a pinned release binary into the XDG prefix and
update by bumping the pin. This keeps behavior and the update story identical
everywhere (including headless remotes without package-manager privileges) and is
a natural fit for the "evaluate dotslash" followup. Only inherently OS-specific
bits (service registration: systemd vs launchd) stay conditional.

- **Claude Code**: Anthropic's native installer (macOS + Linux, installs to
  `~/.local`, self-updates via `claude update`) — already uniform; retire the
  macOS brew cask.
- **Pi Agent**: pinned Node runtime + npm install into the isolated dir
  (Option A below), or an official runtime-managing installer (Option C) —
  uniform across OSes.
- **ollama**: the deliberate **exception** — its release artifacts resist a
  clean uniform binary-drop (macOS flat `.tgz` of binary+dylibs, Linux
  `.tar.zst`+zstd, ~139MB), so it stays on per-OS native package managers (§1).
  Revisit under the dotslash followup.

---

## 1. ollama — install + start cross-platform

### Approach

ollama is the **one exception** to the cross-OS-consistency principle (decided
2026-07-16). Its release artifacts don't suit a uniform binary-drop: macOS ships
a flat ~139MB `.tgz` (the `ollama` binary + dozens of ggml runner dylibs), Linux
ships `.tar.zst` (needs `zstd`, `bin/`+`lib/` layout) — different compression
*and* layout per platform, plus a service to manage. So we use each platform's
native package manager (simplest, least disruptive — macOS already works) and
revisit uniformity under the "evaluate dotslash" followup.

- **macOS**: unchanged — the brew `ollama` formula + `homebrew_services` in
  `setup-macos/roles/dev-tools` already install and run it.
- **Ubuntu**: the official `install.sh` (no apt package exists); it drops the
  binary in `/usr/local/bin` and installs+enables the systemd unit.
- **Arch**: the official `ollama` package via `pacman` (in the `extra` repo),
  system-managed and updated by `pacman -Syu`.

Linux install is root-level (system binary + systemd) → `setup-*`.

### Steps (implemented 2026-07-16)

- **Ubuntu** — `setup-ubuntu/roles/ollama` (added to
  `setup-ubuntu/roles/dev-tools/meta/main.yml` deps, alphabetized):
  - `apt: name=curl` (the installer needs it), `become: yes`.
  - `shell: curl -fsSL https://ollama.com/install.sh | sh`,
    `creates: /usr/local/bin/ollama`, `become: yes`.
  - `systemd: name=ollama enabled=yes state=started daemon_reload=yes`,
    `become: yes` (re-assert; the installer already enables it).
- **Arch** — `setup-archlinux/roles/ollama` (added to
  `setup-archlinux/roles/dev-tools/meta/main.yml` deps, alphabetized):
  - `pacman: name=ollama state=present`, `become: yes`.
  - the same `systemd` enable/start task.
- **macOS**: no change.
- **Cleanup**: drop any stale `brew install ollama` / `brew services start
  ollama` lines from the `README.md` TODO scratchpad.
- Not verifiable here (Linux-only): `setup-ubuntu` syntax-checks clean;
  `setup-archlinux` can't syntax-check on macOS (missing `kewlfft.aur` galaxy
  role, pre-existing). Real test is a Vagrant provision.

### Verification

- Linux: `ollama --version`; `systemctl status ollama` → `active (running)`;
  `ollama list` responds. Exercise via the Vagrant harness
  (`DOTFILES_PLATFORM=ubuntu` / `archlinux`) — expect dated-box bit-rot.
- macOS: unchanged (`brew services list | grep ollama`).

### Risks / open questions

- **Update story differs by OS** (the accepted cost of making ollama the
  exception): Arch `pacman` auto-updates with `pacman -Syu`; the Ubuntu
  `install.sh` drops a standalone binary that `apt` will *not* update (re-run the
  installer to update); brew updates via `brew upgrade`. A future dotslash
  migration would unify this.
- The Ubuntu install script *replaces* the systemd unit on re-run (ollama#8389),
  which would clobber any local override. If we later need custom `OLLAMA_HOST` /
  models dir, put it in a drop-in (`/etc/systemd/system/ollama.service.d/…`),
  not the main unit.
- The `curl | sh` pattern conflicts with the repo's future **bootstrap /
  dotslash** direction and with dev-hygiene (no pinned version, network trust).
  Acceptable for now; note it as a candidate for dotslash later.
- GPU acceleration (CUDA/ROCm) is out of scope; the script auto-detects but the
  Vagrant boxes are CPU-only.
- Ubuntu box `bionic64` may be too old for a current systemd/ollama; may need a
  box bump (tracked separately under the Vagrant followup).

---

## 2. Claude Code — install cross-platform

### Approach

Adopt Anthropic's native installer (recommended since Oct 2025), which is
user-space and cross-platform:

```
curl -fsSL https://claude.ai/install.sh | bash
```

It places the `claude` binary in `~/.local/bin` and version data in
`~/.local/share/claude`, needs **no root and no node**, and self-updates on
startup. `~/.local/bin` is already `xdg_prefix_home`-aligned and on PATH in this
repo, so no PATH work is needed.

Decision — recommendation: a **new `config/` role `claude-code`** that runs the
native installer on *all* platforms, and **drop the `claude-code` brew cask**
from `setup-macos/roles/dev-tools/tasks/main.yml`. Rationale: uniform install
path, one update mechanism, no root, matches the "user space" definition.

Alternative (lower-churn) considered: keep the macOS brew cask and only add
Linux. Rejected because it perpetuates the per-platform split this plan is
trying to remove, and gives two divergent update paths on the two OSes.

npm option (`npm install -g @anthropic-ai/claude-code`, Node 22+): viable and
would reuse the `config/roles/npm` prefix pattern, but the native installer is
now the recommended path and avoids a node dependency, so prefer it.

### Steps

- New role `config/roles/claude-code/` following the standard recipe
  (AGENTS.md): `defaults/main.yml` (a `claude_code_data_dir`, mostly for
  convention), `meta/main.yml` (`dependencies: [shellrc]` — needs
  `~/.local/bin` on PATH, provided by the `bin`/shellrc infra), `tasks/main.yml`
  (run the installer, `creates: ~/.local/bin/claude` for idempotency). No
  `config/files/claude-code/` dotfiles unless we later want to manage
  `~/.claude/settings.json` here.
- Add `- {role: claude-code, tags: [claude-code]}` to
  `config/config.playbook.yml` in **alphabetical order** (between `cargo` and
  `color-theme`).
- Remove `claude-code` from the `homebrew_cask` list in
  `setup-macos/roles/dev-tools/tasks/main.yml`.
- Run `config/config.sh --tags claude-code`.

### Verification

- `claude --version`, `claude doctor`, `which claude` → `~/.local/bin/claude`.
- macOS: confirm the removed cask does not leave the old `/opt/homebrew`-linked
  binary shadowing the new one on PATH (relates to the keg-only/PATH followup).

### Risks / open questions

- `curl | bash` — same network-trust / no-pin caveat as ollama; dotslash
  candidate later.
- Should `~/.claude/` settings be managed by this repo (symlink pattern like
  pi-agent) or left to the tool? Out of scope here; note as a possible
  follow-on. **Caution**: `~/.claude/` may hold API keys — never commit
  secrets (AGENTS.md).
- macOS users mid-migration will have both the cask binary and the native one
  until the cask is uninstalled; document a one-time `brew uninstall --cask
  claude-code`.

---

## 3. Pi Agent — install the agent (currently config-only)

### Resolution (2026-07-16): Option B (npm global), implemented

Inspecting the installed instance settled the open questions:

- The agent is already installed as a **global npm package in the shared npm
  prefix** (`~/.local/share/dotfiles/npm/bin/pi` →
  `@earendil-works/pi-coding-agent`, v0.80.2) on system Node v24 — i.e.
  **Option B**, not the isolated `pi-node` layout (which sits empty). Binary is
  `pi`.
- `pi.dev/install.sh` exists but is an **interactive** installer whose core is
  `npm install -g @earendil-works/pi-coding-agent` into a selected prefix (plus
  optional standalone-node bootstrap) — so **Option C reduces to Option B's
  mechanism** and is unsuitable for unattended Ansible.
- Therefore **Option B**: added an `npm` (global, `NPM_PREFIX={{npm_data_dir}}`)
  install task + an `npm` meta-dep to `config/roles/pi-agent`, mirroring the npm
  role. Verified: the role applies clean and idempotent (`state: present`
  no-ops on the already-installed 0.80.2; does not force-upgrade).
- **Vestigial**: the isolated-node scaffolding (`pi_node_dir` default + its
  creation, `pi_node_dir()` in `vars.sh`, and the `pi-node/current/bin` PATH
  prepend in `3-pi-agent.sh`) is unused under B. Left in place (harmless) to
  avoid churning intentional design; a cleanup follow-up could remove it.

The A/B/C discussion below is retained for context.

### Approach

Pi Agent is a set of npm packages (Node ≥ 22.19); the interactive CLI is
`@earendil-works/pi-coding-agent` (the settings.json `lastChangelogVersion`
`0.80.2` matches this package's version line). It is user-space → **`config/`**.

Two placement choices:

1. **Extend the existing `config/roles/pi-agent`** to also install the agent.
2. Split into `pi-node`/`pi-agent-install` + `pi-agent` (config) roles.

Recommendation: **(1)** — keep it in `pi-agent`, one role owns "make Pi Agent
work." The role already creates `pi_node_dir` and the shellrc fragment already
expects `$PI_NODE_PREFIX/current/bin` on PATH.

Node-runtime decision (the real design question). The shell fragment's
`current/bin` layout signals an *isolated* node install for Pi (not the
system/brew node). Options:

- **A. Isolated node under `pi_node_dir`** (honors the existing `current`
  symlink convention): download a node release tarball into
  `pi_node_dir/<version>/`, symlink `pi_node_dir/current` → it, then
  `npm install -g @earendil-works/pi-coding-agent` with prefix =
  `pi_node_dir/current`. Fully self-contained; Pi's node version is pinned
  independent of the system. Most work, but matches the fragment already
  committed.
- **B. Reuse the repo's npm prefix pattern** (`config/roles/npm`): install the
  agent as a global npm package into `npm_data_dir`, relying on the
  system/brew node from `setup-*`. Least code, but abandons the `current/bin`
  fragment (would need to update `3-pi-agent.sh`) and couples Pi's node to the
  system node version.

- **C. Official install script** (for parity with the ollama and Claude Code
  installers) — e.g. `curl -fsSL https://pi.dev/install.sh | sh`. **Verify such
  an installer actually exists** (the package is published as
  `@earendil-works/pi-coding-agent`, so an official one-line installer may or may
  not exist), and critically, **whether it manages/pins a Node runtime** (Pi
  needs Node ≥ 22.19) or assumes a system Node. If it bundles/pins its own
  runtime, C is the least code and the most consistent with the other two tools,
  and would supersede A.

Recommendation: prefer **C if a runtime-managing official installer exists**
(consistency + least code); otherwise **A**, because the committed
`3-pi-agent.sh` already commits us to the isolated `current/bin` layout and Pi's
Node ≥ 22.19 requirement is easier to guarantee with a pinned runtime than with
whatever `apt`/`pacman`/brew ships. Fall back to **B** only if A/C prove heavy.

### Steps (option A)

- `config/roles/pi-agent/defaults/main.yml`: add `pi_node_version` (pin ≥
  22.19, e.g. current LTS) and keep `pi_node_dir`.
- `config/roles/pi-agent/meta/main.yml`: no new hard dep required (node tarball
  is self-fetched); if reusing an existing helper, depend on `source-releases`
  for the download cache dir (mirrors how source builds stage downloads).
- `config/roles/pi-agent/tasks/main.yml` (new tasks, before the symlink tasks):
  1. `get_url` the platform-appropriate node tarball
     (`node-v<ver>-darwin-arm64` / `linux-x64` — key off `ansible_facts`),
     `creates`-guarded, into `pi_node_dir/<ver>/`.
  2. `unarchive` + `file: state=link` `pi_node_dir/current` → the versioned dir.
  3. `npm` module, `global: yes`, `name: @earendil-works/pi-coding-agent`,
     `environment: { NPM_PREFIX / npm_config_prefix: "{{pi_node_dir}}/current" }`
     using that node's npm (see `config/roles/npm` for the module usage). Pin
     the agent version to match `settings.json`'s expectation if we want
     reproducibility.
  - Keep all existing dir/symlink/vars tasks unchanged.
- No `config.playbook.yml` change (role already listed).
- Run `config/config.sh --tags pi-agent`.

### Verification

- `command -v pi` (or the agent's binary name) resolves under
  `~/.local/share/pi-node/current/bin`; `pi --version` ≈ `0.80.2`.
- The plugins in `settings.json` (`npm:@narumitw/pi-goal`, etc.) resolve — Pi
  installs those itself at runtime, so just confirm the agent launches and
  loads them.
- Verification stops at install + launch + plugin load. A full end-to-end run
  would need the `vLLM` backend (`defaultProvider` in `settings.json`) reachable,
  but that backend is currently unreachable (VPN), so **do not attempt to verify
  the provider connection** — it is explicitly out of scope here (cross-links the
  Pi local-LLM plan).

### Risks / open questions

- **Exact package name / registry**: confirm `@earendil-works/pi-coding-agent`
  is the one matching this config (other forks exist: `@mariozechner/…`,
  `@oh-my-pi/…`). The `0.80.2` version and the `earendil-works/pi` repo point to
  `@earendil-works`, but verify against the installed instance the user already
  has before pinning.
- **Binary name**: confirm the CLI installs as `pi` (the fragment adds
  `current/bin` to PATH but doesn't name the binary).
- **Node version drift**: pinning node means another entry for the "update
  tracked tool versions" followup.
- If we later adopt a unified runtime manager (`mise`/`fnm` — see the runtime
  version-management followup), this isolated node install should be
  reconciled with it rather than duplicated.

---

## Cross-cutting notes

- **Ordering / dependency**: Pi depends on a running ollama (or vLLM) at
  runtime, but install order doesn't matter — `setup-*` (ollama) runs before
  `config/` (Pi) anyway in a normal provision.
- **`curl | bash` installs** (ollama, Claude Code) are the two spots most ripe
  for the future **dotslash** migration (pinned prebuilt fetch) — flag them
  there.
- **Testing reality**: macOS is the actively-used platform; Linux paths must be
  exercised in Vagrant and will likely hit dated-box bit-rot (AGENTS.md). State
  what was applied and observed; there is no CI.
- **README cleanup**: per both followups, once done, strip the corresponding
  stale lines from the `README.md` TODO scratchpad.
