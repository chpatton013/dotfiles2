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
| ollama      | yes (pkg + systemd unit) | **`setup-*`** — matches the existing macOS placement in `dev-tools` |
| Claude Code | no (native installer → `~/.local`) | **`config/`** — cross-platform user-space role; retire the macOS brew cask |
| Pi Agent    | no (node + npm into `~/.local/share`) | **`config/`** — extend the existing `pi-agent` role |

Net effect: ollama stays a system concern; the two agents become uniform
user-space `config/` installs that work identically on macOS and Linux (and on
headless remotes without a package manager privilege). This also removes the
macOS-vs-Linux asymmetry for the agents entirely — the only per-platform code
left is ollama.

---

## 1. ollama — install + start cross-platform

### Approach

Keep macOS as-is (brew formula + `homebrew_services`). Add Linux via the
official install script, which downloads the binary to `/usr/local/bin` **and**
installs+enables a systemd service in one step:

```
curl -fsSL https://ollama.com/install.sh | sh
```

Decision: use the official script rather than distro packages. Ubuntu has no
ollama apt package; Arch has `ollama` in the community repo (and `ollama-cuda`),
but the official script is the documented path, self-updates on re-run, and
gives one code path for both Linux distros. (Alternative for Arch: `pacman -S
ollama` + a `systemd` `enable`/`start` — note only as an option; prefer the
script for parity with Ubuntu.) Both need root, consistent with `setup-*`.

### Steps

- **Ubuntu** (`setup-ubuntu/roles/`): add ollama tasks. Two sub-options:
  - reuse `dev-tools` (add a task block there), or
  - a dedicated `ollama` role added to `dev-tools/meta/main.yml` dependencies
    (alphabetized). Prefer a dedicated role for taggability (mirrors how other
    tools each get a role) and so `--tags ollama` is meaningful.
  - Task: `shell: curl -fsSL https://ollama.com/install.sh | sh`, guarded with
    `creates: /usr/local/bin/ollama` (or `command -v ollama`) for idempotency,
    `become: yes`.
  - The script already creates + enables the systemd unit; add an explicit
    `systemd: name=ollama enabled=yes state=started become=yes` task as a
    belt-and-suspenders / idempotent re-assert.
- **Arch** (`setup-archlinux/roles/`): same pattern (dedicated `ollama` role or
  a block in `dev-tools`). `curl … | sh` works on Arch too; the `systemd`
  enable/start task is identical.
- **macOS**: no change (already done in `setup-macos/roles/dev-tools`).
- **Cleanup**: remove any stale manual `brew install ollama` / `brew services
  start ollama` lines from the `README.md` TODO scratchpad (per the followup;
  verify they still exist — a grep this session found none, so this may already
  be done).

### Verification

- Linux: `systemctl status ollama` → `active (running)`; `ollama --version`;
  `ollama list`. Exercise via the Vagrant harness (`DOTFILES_PLATFORM=ubuntu` /
  `archlinux`) — expect bit-rot on the dated boxes.
- macOS: unchanged; `brew services list | grep ollama`.

### Risks / open questions

- The install script *replaces* the systemd unit on re-run (ollama#8389), which
  would clobber any local override. If we later need custom `OLLAMA_HOST` /
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

Recommendation: **A**, because the committed `3-pi-agent.sh` already commits us
to the isolated layout and Pi's Node ≥ 22.19 requirement is easier to guarantee
with a pinned runtime than with whatever `apt`/`pacman`/brew ships. If A proves
heavy, fall back to B and simplify the fragment.

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
- End-to-end only meaningful with ollama/vLLM reachable; `defaultProvider` in
  `settings.json` is `vLLM`, so a full run needs that backend up (out of scope —
  cross-links the Pi local-LLM plan).

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
