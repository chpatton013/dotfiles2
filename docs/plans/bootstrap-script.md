# Bootstrap Script (curl | bash)

## Context

There is no committed one-shot provisioner in this repo. To bring up a bare
machine today you have to already know the shape of the repo: clone it by hand,
find the right `setup-*/setup.sh`, run it, then run `config/config.sh`. Worse,
each of those entrypoints *assumes tools a fresh machine lacks* and each one
bootstraps its dependencies differently:

- `setup-macos/setup.sh` — installs Homebrew, then `brew install ansible`, then
  `ansible-galaxy collection install community.general`.
- `setup-archlinux/setup.sh` — `pacman` installs `python`/`python-pip`, then
  `pip install -r requirements.txt` (ansible) + `ansible-galaxy role/collection`.
- `setup-ubuntu/setup.sh` — **assumes `ansible-galaxy`/`ansible-playbook` are
  already on PATH** (no install step at all — the classic bare-machine gap).
- `config/config.sh` — assumes `ansible-playbook` exists; only refreshes the
  `community.general` collection.

So "get git + a package manager + ansible onto the box" is currently three
divergent, partially-missing code paths, and the user must drive the OS
detection and hand-off in their head.

Two concrete, known pains this must fix:

1. **Bare-machine tool gap.** A fresh box has neither git (to fetch this repo)
   nor ansible (to apply it). The bootstrap has to acquire both before it can
   delegate to anything here.
2. **"brew cellar isn't on PATH at provision time"** (`README.md` TODO, and the
   *Handle keg-only Homebrew packages* followup). On a fresh macOS install
   `/opt/homebrew/bin` is not on the login PATH until a later shell restart, so
   `setup.sh` installs brew and then can't find `brew`/`ansible-playbook` in the
   same session. This is the same root cause as the keg-only-link problem.

Reference implementation the user already built along these lines:
`github.com/chpatton013/chiiiirrus` (external — describe the approach only, do
not fetch/upload). Its pattern is a small self-contained bootstrap that fetches
pinned cross-platform executables via **dotslash** and drives everything from
one entrypoint; this plan brings that pattern here.

## Key realization

The three per-OS "install ansible + git" preambles are the only thing that
*must* run before the existing, already-good Ansible entrypoints. If we can make
"acquire git + a Python capable of running ansible" a **single cross-platform
step**, the bootstrap collapses to:

```
fetch minimal tools  ->  clone repo  ->  shim PATH  ->  setup-$OS/setup.sh  ->  config/config.sh
```

**dotslash** is the tool that makes that one step cross-platform. A dotslash
file is a small text manifest committed to the repo that stands in for a
platform-specific executable; when run, the dotslash runtime fetches the correct
prebuilt binary for the current OS/arch from a pinned URL, verifies its hash,
caches it under `~/.cache`, and execs it. That lets us pin **`uv`** (a single
static binary) as our cross-platform Python/ansible provider and **`git`** for
cloning, instead of three different native package-manager incantations.

dotslash itself is a prebuilt binary, so it is the one true bootstrap
dependency; everything else can be a dotslash manifest.

## Scope of what dotslash subsumes

| Step today | macOS | archlinux | ubuntu | With dotslash |
| --- | --- | --- | --- | --- |
| get a package manager | install Homebrew | (pacman present) | (apt present) | unchanged — still OS-native; dotslash does not replace brew/pacman/apt for *system* packages |
| get git (to clone) | brew (implicit) | pacman (implicit) | assumed | dotslash-pinned `git` (or curl a tarball — see SSH section) |
| get python/pip | (n/a) | `pacman python python-pip` | assumed | dotslash-pinned `uv` (bundles a managed Python) |
| get ansible | `brew install ansible` | `pip install -r requirements.txt` | **missing** | `uv tool install ansible` / `uvx ansible-playbook` |
| galaxy collection | per-script | per-script | per-script | unchanged — run once after ansible exists |

Deliberately **out of scope for dotslash**: the OS-native package manager itself
(Homebrew / pacman / apt / snap / flatpak) and everything the `setup-*` roles
install through it. Homebrew in particular is load-bearing on macOS (it provides
git, neovim, tmux, etc. that Linux builds from source) and cannot be replaced by
dotslash without rewriting every macOS role. dotslash's job is strictly the
*bootstrap* tools needed to reach `ansible-playbook`. A broader dotslash audit of
the source-build/release-download roles is tracked separately (the *Evaluate
dotslash for more of this repo's executables* followup) and is **not** part of
this plan.

## Design

### Entrypoint

A single committed script, `bootstrap.sh` at repo root, is the `curl | bash`
target and also runnable locally (idempotent, so re-running is safe). Because
`curl | bash` runs with no repo on disk, the script is written to work in two
modes:

- **Remote mode** (`curl -fsSL <raw-url>/bootstrap.sh | bash`): the script has
  no `$BASH_SOURCE` repo around it. It fetches the tools, clones the repo to a
  known location, then re-execs the on-disk copy of itself for the rest.
- **Local mode** (`./bootstrap.sh` from a clone): repo already present; skip the
  clone, proceed to provisioning.

Preamble matches repo convention: `#!/bin/bash --norc`, `set -euo pipefail`, and
the `script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` line
(guarded, since in remote mode `BASH_SOURCE` is the pipe).

High-level flow:

1. Detect OS/arch.
2. Install the dotslash runtime (the only non-dotslash fetch).
3. Use dotslash-pinned `git` to clone the repo to `~/github/chpatton013/dotfiles2`
   (matching the user's existing checkout layout) if not already present; re-exec
   the on-disk `bootstrap.sh` in local mode.
4. Shim the OS package manager onto PATH (macOS brew shim; see below).
5. Ensure a cross-platform ansible via dotslash-pinned `uv` (`uv tool install
   ansible`), unless a system ansible is already present.
6. Delegate: run `setup-$OS/setup.sh "$@"`, then `config/config.sh`.

Env knobs (all optional, for re-runs and testing): `DOTFILES_DIR` (clone
target), `DOTFILES_REPO` (override remote), `DOTFILES_REF` (branch/tag),
`--config-only` / `--setup-only` flags to run just one phase.

### OS detection

`uname -s` -> `Darwin` = macos, `Linux` = read `/etc/os-release` `ID`/`ID_LIKE`
to distinguish `ubuntu`/`debian` from `arch`/`archlinux`. Map to the existing
`setup-{macos,ubuntu,archlinux}` directory names; fail loudly with a clear
message on anything unmapped (e.g. Fedora) rather than guessing. `uname -m`
(`arm64`/`aarch64` vs `x86_64`) feeds the dotslash manifests' platform keys.

### The PATH shim (brew cellar problem)

Before delegating on macOS, prepend the Homebrew bin dirs to PATH for the
current process so freshly-installed formulae resolve in the same session:

```sh
for d in /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin; do
  [ -d "$d" ] && PATH="$d:$PATH"
done
export PATH
```

This is exported *before* invoking `setup-macos/setup.sh`, which fixes the
"setup and config scripts both fail on mac because brew cellar isn't on path"
symptom directly. It is intentionally broad (covers Apple-Silicon
`/opt/homebrew` and Intel `/usr/local`). The narrower, per-formula version of
this problem (keg-only packages like `ruby` needing
`/opt/homebrew/opt/<pkg>/bin`) is the separate *Handle keg-only Homebrew
packages* followup and should be solved **inside the setup roles**, not here —
the bootstrap shim only guarantees `brew` itself and normal formulae are
reachable. This plan should note the relationship so the two fixes stay
consistent (both are "put the right brew dir on PATH").

### dotslash usage

- **Runtime install.** dotslash is a single prebuilt binary per platform. The
  bootstrap installs it with a pinned, hash-checked `curl` to a fixed cache dir
  (`~/.local/bin/dotslash` or `~/.cache/dotslash/`), then puts it on PATH. This
  one fetch is the only step that cannot itself be a dotslash file (chicken/egg).
- **Committed manifests.** Add a `bootstrap/dotslash/` directory with manifests
  for the bootstrap tools we want cross-platform: at minimum `uv`, optionally
  `git`. Each manifest pins version + per-(os,arch) URL + sha256 + size, so a
  provision is reproducible and offline-cache-friendly.
- **ansible via uv.** After `uv` is available, `uv tool install ansible` (or
  `uvx ansible-playbook`) provides ansible identically on all three OSes,
  replacing brew/pip/pacman divergence. `ansible-galaxy collection install
  community.general` then runs once. (Open decision below: do we adopt uv-backed
  ansible everywhere, or keep native ansible where it already works and only use
  uv to *fill the gap* on ubuntu?)

### SSH-key handling

Cloning over HTTPS needs no key and works for a public repo, so the **default
path is HTTPS clone, no key generation**. SSH keys are only needed for pushing
and for private-repo access, which is a post-provision concern, not a
bootstrap-blocker. Recommended design:

- Default: `git clone https://git...`. Zero interaction, works headless and in
  CI.
- Opt-in (`--ssh` or `DOTFILES_SSH=1`): if no key exists, generate an
  `ed25519` key (`ssh-keygen -t ed25519 -N ''`), print the public key, and pause
  with instructions to add it to GitHub — but do **not** try to automate the
  GitHub API upload (needs a token; out of scope and a secrets risk in a public
  repo). This keeps the bootstrap non-interactive by default.

This is a decision point for the user (below); the safe recommendation is
HTTPS-clone-by-default with SSH as an explicit opt-in flag.

### Idempotency & re-run behavior

Every step is guarded so `bootstrap.sh` is safe to re-run (the same contract the
existing entrypoints honor):

- dotslash runtime: install only if the pinned binary/hash is absent.
- clone: `git clone` only if `$DOTFILES_DIR/.git` is absent; otherwise leave the
  checkout alone (do **not** auto-pull — the user may have local work; print a
  note instead).
- uv / ansible: install only if missing; `uv tool install` is itself idempotent.
- PATH shim: prepend-if-present is naturally idempotent within a process.
- delegation: `setup.sh`/`config.sh` are already idempotent Ansible applies;
  pass through `"$@"` so `--check --diff` and `--tags` scoping still work
  end-to-end (e.g. `bootstrap.sh -- --tags neovim`). Given the CLAUDE.md caution
  that these mutate the live machine, the bootstrap should **echo exactly what it
  is about to run and honor a `--dry-run`** that stops before the two applies.

### Hand-off to existing scripts

The bootstrap does not reimplement any provisioning logic — it only guarantees
preconditions (git + uv, and brew's PATH on macOS), then calls the entrypoints:

```sh
"$repo/setup-$os/setup.sh" "$@"     # platform setup (sudo/become as today)
"$repo/config/config.sh"            # user-space config
```

The entrypoints now **self-provision ansible via uvx** (see below), so they work
whether driven by the bootstrap or run standalone; the bootstrap only has to
ensure `uv` exists. `setup-*/setup.sh` keep their own `--ask-become-pass` logic.

## Implementation status

Implemented (see `bootstrap.sh` at repo root and `bootstrap/dotslash/{uv,git}`),
with the following decisions locked in:

- **curl/wget is the only hard dependency.** All fetches go through a
  `fetch_stdout`/`fetch_file` dispatch that uses whichever of curl/wget is
  present; everything else (dotslash runtime, then git/uv/ansible) is fetched
  with those.
- **dotslash-first tooling.** `install_dotslash` runs *before* `ensure_git` so
  git can come through dotslash. A generic `dotslash_tool <name>` installs a tool
  from its committed manifest (`bootstrap/dotslash/<name>`), fetching the
  manifest over curl/wget in remote mode. `ensure_git`/`ensure_uv` prefer
  dotslash, then fall back (system git → OS-native install for git; official
  installer for uv). The end-state goal is pure-dotslash provisioning once the
  manifests carry real pins; the fallbacks keep a bare box working until then.
- **ansible provider:** uv-backed ansible on *all* platforms (uniform; fixes the
  ubuntu gap), and provisioned **by the entrypoints themselves** rather than by
  the bootstrap. A shared helper `bootstrap/ansible.sh` (sourced by
  `config/config.sh` and all three `setup-*/setup.sh`) exposes `ensure_uv`
  (installs uv via its official installer if missing) and `ansible_uvx` (runs
  `uvx --from "$ANSIBLE_UVX_FROM" ansible-*`; default `ANSIBLE_UVX_FROM=ansible`,
  the community bundle that includes `community.general`). Each entrypoint calls
  `ensure_uv` then runs its galaxy + playbook steps through `ansible_uvx`. The
  bootstrap therefore only ensures `uv` (no more `ensure_ansible`); on macOS the
  entrypoint still installs Homebrew (the package manager the playbook drives)
  but no longer brew-installs ansible; on arch the pip/`python-pip` ansible
  install and `requirements.txt` are dropped (uv provides ansible), keeping only
  a system `python3` for module execution. `kewlfft.aur` (an arch galaxy *role*)
  and `community.general` are still installed via `ansible_uvx ansible-galaxy`.
- **PATH shim:** `shim_path` gates the Homebrew dirs behind `OS == macos` and
  prepends the tool bin dirs (dotslash/uv) via a single `prepend_path` helper.
- **SSH keys:** HTTPS clone by default; `--ssh` opt-in generates an ed25519 key
  (path overridable via `SSH_KEY`) and prints it for manual add to GitHub (no
  API upload). `ssh-keygen` stays a system tool (OpenSSH is not a dotslash
  candidate).
- **clone:** shallow + single-branch by default (`DOTFILES_CLONE_DEPTH`, set 0
  for full); location defaults to `~/github/<repo>`, overridable via
  `DOTFILES_DIR`. Existing clones are never auto-pulled.
- **skipped-phase warnings:** `--setup-only`/`--config-only` emit a warning
  naming the script the user must still run.

### Resolved: ansible via uvx in the entrypoints

The entrypoints invoke ansible through `uvx` (via `bootstrap/ansible.sh`), and
the bootstrap's `ensure_ansible` step is gone. This removes a manually-managed
runtime (no installed `ansible`/brew-ansible/pip-ansible to keep updated) and
keeps the entrypoints usable standalone (they self-provision `uv`). Tradeoff
accepted: the entrypoints now require `uv` (auto-installed) and each ansible
invocation pays uvx's first-run env resolution (cached thereafter).

### Known residual items (need a real bare-machine run)

- The `bootstrap/dotslash/{uv,git}` manifests ship as unpopulated scaffolds
  (placeholder `REPLACE_ME`/`REPLACE_VERSION`); `manifest_populated` detects this
  and callers fall back (uv → official installer; git → system/native) until
  real version/size/digest pins are filled in. So both work today but are not yet
  hash-pinned. Note git is not published as a clean single prebuilt binary for
  every platform, so populating `git` needs a chosen per-platform source (see the
  manifest's notes).
- dotslash runtime asset naming varies per release; the URL is best-effort with
  `DOTSLASH_VERSION`/`DOTSLASH_URL` overrides, and tools fall back to native
  installers if dotslash can't be obtained.
- git native fallback on macOS prefers `brew install git`, else the interactive
  Xcode Command Line Tools dialog.
- The remote-mode clone + re-exec and the `--ssh` keygen flow are exercised only
  via `--dry-run`; both need a real bare-machine run to confirm end-to-end.
- The `uvx`-based entrypoints are unverified end-to-end (no ansible run here):
  confirm that `uvx --from ansible ansible-playbook` resolves the bundle,
  that galaxy-installed `community.general`/`kewlfft.aur` (in `~/.ansible`) are
  visible to the uvx-run playbook, and that ansible's interpreter discovery is
  happy on each OS (arch keeps a system `python3` for this reason).
