# AGENTS.md — Repository Primer

Personal dotfiles (v2) for Chris Patton, built around Ansible. The goal is that
every machine feels identical regardless of OS. There are no build systems,
tests, or CI here — "verification" means applying a playbook and observing the
result on a real machine or in a Vagrant VM.

## The two-phase model

Everything in this repo falls into one of two phases:

1. **Platform setup** (`setup-macos/`, `setup-ubuntu/`, `setup-archlinux/`):
   installs software onto the system. Run once per machine (and again when
   adding/upgrading software). Requires root/sudo. Each directory has a
   `setup.sh` entrypoint that bootstraps Ansible and applies
   `setup.playbook.yml` with the platform's roles (package managers differ:
   Homebrew, apt/snap/flatpak, pacman/AUR).

2. **Platform-agnostic config** (`config/`): configures user space. Never
   needs root. `config/config.sh` applies `config.playbook.yml`, passing
   `dotfiles_src_dir=$repo/config/files` and the XDG variables from
   `config.vars.yml`. This is the part that changes most often.

On Linux, some setup roles build tools from source (git, neovim) into
`~/.local` (`xdg_prefix_home`); on macOS those steps are skipped
(`when: ansible_facts['os_family'] != "Darwin"`) because Homebrew provides
them.

## How config works: symlinks, not copies

The core mechanism: actual dotfiles live in `config/files/<tool>/`, and
Ansible roles in `config/roles/<tool>/` **symlink** them into place (usually
under `~/.config/dotfiles/<tool>/`, sometimes `~/.local/bin` for executables).

Consequence for agents: **editing a file under `config/files/` takes effect
immediately on this machine** — no re-apply needed. You only need to re-run
`config/config.sh` when you add/remove files, add a role, or change a
template. To apply a single role:

```sh
config/config.sh --tags neovim
```

(Every role in `config.playbook.yml` has a tag matching its name.)

## Anatomy of a config role

Roles follow a strict, repetitive convention. Study `config/roles/zshrc/` or
`config/roles/pi-agent/` as templates:

- `defaults/main.yml` — defines `<role>_config_dir` (under
  `{{dotfiles_config_dir}}` = `~/.config/dotfiles`) and `<role>_data_dir`
  (under `{{dotfiles_data_dir}}` = `~/.local/share/dotfiles`).
- `meta/main.yml` — dependencies. Almost everything depends on `shellrc`
  and/or `dotfiles`; `dotfiles` depends on `xdg`. Helper roles exist for
  shared storage: `source-releases` (`~/.local/share/source-releases`, for
  source builds) and `github-repos` (for cloned repos, e.g. `solarized`).
- `templates/vars.sh` — rendered to `{{shellrc_config_dir}}/0-<role>.sh`;
  exposes the role's directories as shell **functions** (e.g.
  `neovim_config_dir()`). This is how shell scripts discover paths at runtime.
- `tasks/main.yml` — creates directories, renders the vars template, and
  symlinks files from `{{dotfiles_src_dir}}/<tool>/` with
  `state: link, follow: no, force: yes`.

### Adding a new tool's config (the standard recipe)

1. Put the dotfiles in `config/files/<tool>/`.
2. Create `config/roles/<tool>/{defaults,meta,tasks,templates}` following the
   convention above.
3. Add `- {role: <tool>, tags: [<tool>]}` to `config.playbook.yml`
   (**alphabetical order** — the whole repo keeps lists alphabetized).
4. Run `config/config.sh --tags <tool>`.

## The shellrc ordering convention

Shell startup is assembled from fragments. The rendered `~/.zshrc` /
`~/.bashrc` source `~/.shellrc` (which defines `source_dir`) and then
`source_dir` over `~/.config/dotfiles/shellrc/` plus the shell-specific dir.
`source_dir` sorts files by **basename**, so the numeric prefix is a load
order across all roles:

- `0-*` — rendered vars files (path functions; must load first)
- `1-*` — infrastructure functions (`prepend_pathlist`, zsh modules)
- `2-*` — environment: history, locale, completion, bindings, macOS paths
- `3-*` — per-tool config: env vars, aliases, shortcuts (most fragments)
- `4-*` — prompt
- `9-*` — final PATH/LD_LIBRARY_PATH fixup

A new shell fragment goes in `config/files/<tool>/3-<tool>.sh` and must be
added to the role's symlink list (and, for core fragments, to
`config/roles/shellrc/tasks/main.yml`'s `with_items`). Forgetting the
`with_items` entry is the classic mistake — the file exists in the repo but
never gets linked.

## Testing changes

- **Config changes on the current machine**: just re-run
  `config/config.sh [--tags X]`; it's idempotent. `--check --diff` previews.
- **Linux setup changes**: use the Vagrant harness. `vagrant.sh` wraps
  `vagrant` and requires `DOTFILES_PLATFORM` (`ubuntu` or `archlinux`); it
  validates that `vagrant-env/$PLATFORM.yaml` exists and exports
  `DOTFILES_PLATFORM` for the Vagrantfile (it no longer sources a shell env
  file). Each `vagrant-env/<platform>.yaml` is a structured spec (box,
  setup dir, machine params) parsed by the Vagrantfile with Ruby's stdlib YAML
  (no plugin); `params` shadow top-level → provider → arch, so a spec lists only
  what differs. The provider defaults to `qemu` (Apple-Silicon-friendly) with
  `libvirt` and `virtualbox` also handled; override via `DOTFILES_VAGRANT_PROVIDER`.
  The host architecture is inferred (`uname -m`), preferring the matching arch
  entry and falling back to the first listed (override with
  `DOTFILES_VAGRANT_ARCH`) — so e.g. `archlinux` (no arm64 box) emulates x86_64
  on Apple Silicon, which is correct but slow. Typical loop: `./vagrant.sh up
  --no-provision`, then `./vagrant.sh provision` repeatedly. macOS is the
  actively used platform (see git log — recent work is nvim, wezterm, tmux,
  pi-agent, macOS dev-tools).
- There is no automated verification. State what you applied and what you
  observed.

## Conventions and style

- **Commit messages**: lowercase `area: summary`, e.g.
  `nvim: disable auto spellcheck`, `pi: updated models`.
- **Git identity — never override it on the CLI.** Do not pass `git -c
  user.name=…`/`-c user.email=…`, `git commit --author=…`, or set
  `GIT_AUTHOR_*`/`GIT_COMMITTER_*`. The layered gitconfig already resolves the
  correct identity per repo: `~/.gitconfig` includes
  `identity-public.gitconfig` (personal) unconditionally, then
  `identity-work.gitconfig` which overrides it where the work identity applies.
  Just run `git commit` and let git pick. In particular, do **not** use the
  email from session/environment context as a commit identity — it may be the
  work address and will attach the wrong identity (e.g. work email on a personal
  GitHub repo, or vice versa). If a commit ends up with the wrong identity,
  that's the cause.
- **YAML**: files start with `---` + blank line; Jinja without inner spaces
  (`{{item}}`, not `{{ item }}`); 2-space indent; `with_items` lists
  alphabetized.
- **Shell scripts**: `#!/bin/bash --norc`, `set -euo pipefail`, and the
  `script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  preamble.
- Rendered files get restrictive modes (0400/0700); symlinked files keep repo
  permissions.

## Notable contents

- `config/files/neovim/init.lua` — single-file Neovim config using lazy.nvim
  (bootstrapped by the neovim role, which also runs `+Lazy install` and
  `+MasonUpdate`). `lazy-lock.json` is gitignored.
- `config/files/pi-agent/` — settings/models for Pi Agent (a coding agent run
  against locally hosted LLMs via Ollama/vLLM). Linked to *both*
  `~/.config/dotfiles/pi/agent/` and `~/.pi/agent/`. Active area of work; see
  `docs/plans/` for design notes.
- `config/files/color-theme/` — homegrown scripts for switching Solarized
  light/dark across tools; several roles hook into it.
- `secure-boot/` — standalone scripts for signing kernel modules on
  SecureBoot Linux machines; not part of the playbooks.
- `README.md` — design rationale plus a long informal TODO scratchpad at the
  bottom; treat the TODO section as notes, not a work queue.

## Cautions

- `config.sh` and `setup.sh` **mutate the live machine** ($HOME symlinks,
  installed packages, `brew services`). Don't run them speculatively; prefer
  `--check --diff` or `--tags` scoping.
- The neovim role **deletes** `~/.local/share/nvim` if it isn't already a
  symlink before linking it. Be aware when running that role on a machine
  with an existing nvim setup.
- This repo is public on GitHub. **Never commit secrets** into
  `config/files/`; env fragments are the tempting place for API keys and the
  wrong one. Anything secret belongs in an untracked/ignored secrets file.
