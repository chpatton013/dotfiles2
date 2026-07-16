# Source-Build Roles: zsh from Source + Version Audit

> **Status: partially implemented.** Part 1 (zsh source-build role) done
> (`e8317b4`). Part 2: git bumped to 2.55.0 (`a403e35`); the
> `/update-source-versions` skill + `# release-metadata:` convention added
> (`577efc0`). **Remaining:** the neovim 0.11 → 0.12 bump, gated on interactive
> validation (Darwin-gated build; brew nvim is the macOS driver, currently
> 0.11.6).

Covers two `docs/followups.md` items (Provisioning & setup): **Build zsh from
source** and **Update tracked source-build tool versions**.

## Context / why

The shell we run interactively is currently the system/brew `zsh`
(`setup-macos/roles/dev-tools/tasks/main.yml` installs the `zsh` formula; the
Linux `dev-tools` roles install the distro package). That ties the zsh version
to the OS package manager. Every other core interactive tool we care about —
`git`, `neovim`, `tmux`, `wezterm` — is instead built from a pinned source
release into the XDG prefix (`~/.local` = `xdg_prefix_home`) by a `config/`
role, so the version is uniform across machines and independent of the package
manager. zsh is the odd one out; Part 1 brings it into the same pattern.

Separately, source-build version pins drift. `docs/followups.md` flags three
(`git`, `neovim`, `tmux`) plus "check the Linux setup roles"; the
dynamic-color-theme plan closes with the same follow-up. Part 2 audits and
bumps them, with a specific hazard around neovim (see Risks).

### Existing precedent (the pattern to copy)

- `config/roles/git`, `config/roles/neovim`: download release tarball →
  `configure`/`make`/`make install` into `{{xdg_prefix_home}}`, idempotent via
  `creates: {{xdg_bin_home}}/<bin>`, but **Darwin-gated**
  (`when: os_family != "Darwin"`) because brew provides them on macOS.
- `config/roles/tmux` (recently generalized): builds on **all** platforms
  including macOS. On Darwin it feeds brew's `libevent`/`ncurses` include/lib
  paths into `CFLAGS`/`LDFLAGS` and passes `--enable-utf8proc` with
  `LIBUTF8PROC_*` — no pkg-config required.
- `config/roles/wezterm`: cross-platform source build; good template for macOS
  build-env massaging.
- Shared helper role `source-releases` provides
  `{{source_releases_data_dir}}` (`~/.local/share/source-releases`); every
  source-build role depends on it plus `xdg`.
- Linux `setup-*` roles do **not** pin source versions — they install distro
  build-dependency packages (e.g. `setup-ubuntu/roles/tmux` installs
  `libncurses5-dev`/`libncursesw5-dev`/`libevent-dev`; neovim/git roles install
  cmake/gettext/etc.). Version pinning lives only in `config/roles/*/defaults`.

## Part 1 — Build zsh from source

### Approach

Add a `config/roles/zsh` source-build role mirroring `tmux` (cross-platform,
including macOS — since we want to own the shell version everywhere, and unlike
git/neovim there is no reason to defer to brew here). Download the pinned zsh
release tarball, `configure`/`make`/`make install` into `{{xdg_prefix_home}}`,
guard with `creates: {{xdg_bin_home}}/zsh`. zsh needs **ncurses** (terminal) and
**PCRE** (`--enable-pcre`, for the `zsh/pcre` module); on macOS these are
keg-only brew formulae whose paths must be fed in the same way tmux feeds
libevent/ncurses.

This role builds the *binary only*. It is distinct from the existing
`config/roles/zshrc`, which renders `~/.zshrc` and links the shell fragments;
leave `zshrc` as-is. The new role should not depend on `zshrc` (avoid a cycle);
`zshrc` may optionally gain a soft dependency on `zsh` so applying it also
builds the shell, but keeping them independent (both listed in the playbook) is
simpler and matches how `neovim`/`tmux` stand alone.

### Steps

1. `config/roles/zsh/defaults/main.yml` — pin the version and derive URLs,
   following `tmux`/`git` defaults:
   - `zsh_release_version: 5.9.2` (latest stable as of 2026-07; see Part 2).
   - `zsh_release_url` — the sourceforge/GitHub release tarball for that version
     (mirror the `{{...version}}` interpolation style of the other roles).
   - `zsh_release_dir: {{source_releases_data_dir}}/zsh-{{zsh_release_version}}`.
   - `zsh_release_cflags: "-O2"` (as tmux).
2. `config/roles/zsh/meta/main.yml` — `dependencies: [source-releases, xdg]`
   (same as `git`; no shellrc needed since this role links no fragments).
3. `config/roles/zsh/tasks/main.yml` — closely follow `tmux/tasks/main.yml`'s
   build block:
   - `unarchive` the tarball into `{{source_releases_data_dir}}`.
   - `shell` build step (`executable: /bin/bash`, `set -ex`):
     - Base `cflags="{{zsh_release_cflags}}"`, empty `ldflags`,
       `configure_flags`.
     - On Darwin (`if [ "$(uname)" = Darwin ]`): for `ncurses` and `pcre2`
       (verify whether zsh wants `pcre` vs `pcre2` at configure time; if the
       release only supports the legacy `--enable-pcre`/`pcre-config`, use the
       `pcre` formula), append `brew --prefix` include/lib to
       `cflags`/`ldflags`; set `configure_flags="--enable-pcre"`. Consider
       `--enable-multibyte` (usually default) and, if the keg-only
       `pcre`/`ncurses` `bin` dirs are needed for `*-config` scripts, prepend
       them to `PATH` for the configure run.
     - `CFLAGS="$cflags" LDFLAGS="$ldflags" ./configure
       --prefix={{xdg_prefix_home}} $configure_flags`, then `make
       --jobs={{ansible_facts['processor_vcpus']}}`, `make install`.
     - `creates: "{{xdg_bin_home}}/zsh"`.
   - Note: zsh source builds sometimes need `make check`-free installs and may
     want `--disable-gdbm`; keep the configure line minimal and expand only if
     the build complains. Do **not** gate on Darwin — build everywhere.
4. `config/config.playbook.yml` — add `- {role: zsh, tags: [zsh]}` in
   **alphabetical** position (between `wezterm` and `zshrc`, at the end of the
   list).
5. Linux `setup-*` build deps — add zsh's build dependencies to the Linux
   `dev-tools` (or a dedicated `zsh`) setup role so the source build has what it
   needs: `libncurses-dev` + `libpcre2-dev` (apt) / `ncurses` + `pcre2`
   (pacman), plus the usual `autoconf`/`gettext`/build toolchain (largely
   already present via existing dev-tools). macOS needs brew `ncurses` and
   `pcre`/`pcre2` present — add them to
   `setup-macos/roles/dev-tools/tasks/main.yml` (`ncurses`, `pcre2`) alongside
   the existing keg-only deps.
6. Login-shell interaction (see Risks) — the built `~/.local/bin/zsh` only
   becomes the *login* shell if it is in `/etc/shells` and selected via `chsh`,
   both of which need root and thus belong in the `setup-*` phase, not this
   user-space `config/` role. This plan's role stops at producing the binary on
   `PATH`; wiring it as the login shell is a follow-on decision (keep brew/system
   zsh as the login shell initially, exec the XDG zsh from `.zshrc`/`.profile`,
   or add a setup-phase `chsh` task). Note the brew `zsh` line in
   `setup-macos/roles/dev-tools` can stay until cutover is trusted (side-by-side,
   the way the wezterm fork lives beside the cask).

### Verification

- `config/config.sh --tags zsh --check --diff`, then apply.
- `~/.local/bin/zsh --version` reports the pinned version;
  `~/.local/bin/zsh -c 'zmodload zsh/pcre && echo ok'` confirms the PCRE module
  built. Confirm it appears ahead of the system zsh once `~/.local/bin` is on
  `PATH`. Interactive smoke test: launch it, confirm the existing zshrc
  fragments load cleanly. Idempotency: re-run is a no-op (guarded by `creates`).
- Linux paths can only be exercised via the Vagrant harness (dated boxes; expect
  bit-rot), so note them as written-but-unverified as the wezterm Linux path
  was.

## Part 2 — Version audit / bump

### Currently pinned source builds

| Role | Var | Pinned now | Latest stable (2026-07) | Action |
| --- | --- | --- | --- | --- |
| `config/roles/tmux` | `tmux_release_version` | `3.6a` | 3.6a | none (just bumped for mode 2031) |
| `config/roles/git` | `git_release_version` | `2.41.0` | 2.55.0 | bump (safe; big gap) |
| `config/roles/neovim` | `neovim_release_version` | `0.11.6` | 0.12.4 | **hold** — see risk |
| `config/roles/wezterm` | `wezterm_fork_version` | fork SHA `f33e689f` | n/a | leave pinned (deliberate fork for CSI 2031) |
| `config/roles/zsh` (new) | `zsh_release_version` | `5.9.2` (this plan) | 5.9.2 | ship current |

Linux `setup-*` roles pin **no** source versions — they install distro packages
+ build deps. Nothing to bump there beyond keeping build-dep package lists
correct (e.g. ncurses/pcre for the new zsh build).

### Approach & steps

1. **git → 2.55.0** (from 2.41.0). Low risk: git is highly backward compatible
   and our use is a tarball build with our own `gitconfig`. Bump
   `git_release_version` in `config/roles/git/defaults/main.yml`; the URL/dir
   interpolate automatically. Re-verify the `git_release_cflags`
   (`-std=gnu99 -O2`) still compiles on current git (recent git may prefer a
   newer C standard — drop/adjust the `-std` if configure complains). Verify:
   build, `~/.local/bin/git --version`, run a few real commands (delta pager,
   `git-sizer` still resolves).
2. **neovim → HOLD at 0.11.x, patch-only.** 0.12.4 is stable upstream, but our
   `config/files/neovim/init.lua` is tuned to 0.11 (the color-theme plan's
   support matrix explicitly cites "Neovim 0.11.6"; 0.12 ships breaking changes
   — native insert-mode completion, built-in plugin manager, statusline/UI
   changes — that can collide with our lazy.nvim/nvim-cmp/lualine setup). Nvim
   cannot be verified headless here, so a minor bump risks silently breaking the
   config. Recommendation:
   - Bump only to the latest **0.11 patch** (confirm whether >0.11.6 exists;
     stay on the 0.11 line).
   - Treat 0.11 → 0.12 as its own task gated on reviewing the 0.12 release notes
     and interactively testing the config (overlaps the open nvim completion-UX
     and AI-plugin follow-ups, which already churn the completion stack). Do not
     fold it into a routine version bump.
3. **tmux** — already at 3.6a (latest); no change. Keep the version-gated 2031
   hook block in `tmux.conf`.
4. **How to check latest going forward**: for each pinned tool, compare the
   `*_release_version` default against the project's releases page (git:
   github.com/git/git; neovim: github.com/neovim/neovim; zsh:
   zsh.sourceforge.io / github.com/zsh-users/zsh; tmux:
   github.com/tmux/tmux). Prefer the newest release on the tool's *current
   stable line*, and pin conservatively at patch level.

I'd like to push the neovim version to stable upstream. I'm here to help
validate interactively.

Let's add to the scope of this task: build a skill to help update these source
versions in the future. Include the distinction between minor patches that
shouldn't require interactive review and major ones in cases where you don't
have a fully-automated validation mechanism. The skill shouldn't encode the
details about each specific application, but should instead look for that
information when it executes. That means we should have some convention for
where we record that information in the ansible roles. Maybe comments in the
defaults file that specifies the version for each source build?

### Verification

- After each bump: `config/config.sh --tags <role>` builds cleanly and the
  installed binary reports the new version. For git and zsh, exercise real
  usage. For neovim, do **not** bump the minor without an interactive
  `:checkhealth` + config smoke test on a real machine.

## Risks / open questions

- **neovim minor bump (0.12) can break the config and can't be verified
  headless.** Mitigation above: patch-only bumps within 0.11; defer 0.12 to a
  reviewed, interactively tested task. Highest-risk item in this plan.
- **zsh login-shell cutover needs root** (`/etc/shells` + `chsh`). Out of scope
  for the user-space `config/` role; decide the setup-phase mechanism (or an
  exec-from-rc shim) separately. Keep brew/system zsh installed side-by-side
  until the source build is trusted.
- **macOS zsh build deps — `pcre` vs `pcre2`.** Confirm at configure time which
  the pinned zsh release wants (`--enable-pcre` historically uses `pcre-config`
  from the legacy `pcre` formula). Adjust the brew formula name and the setup
  dep list accordingly. Also confirm keg-only `ncurses`/`pcre*` need their
  include/lib fed in (they do on macOS, as with tmux) and whether their `bin`
  `*-config` scripts must be on `PATH` for configure.
- **git `-std=gnu99`** may be stale for git 2.55; be ready to relax the cflag.
- **Linux paths unverified.** Vagrant boxes are dated; Linux zsh build + setup
  deps will be written-but-unexercised until run on a real Linux host, as with
  the wezterm Linux install path.
- **dotslash overlap.** A separate follow-up weighs replacing some source builds
  with dotslash-fetched prebuilt binaries. zsh (and the version bumps) are
  candidates to reconsider there later; not in scope here.

### Cited current stable versions (2026-07)

- zsh **5.9.2** ([zsh releases](https://zsh.sourceforge.io/releases.html),
  [zsh-users/zsh](https://github.com/zsh-users/zsh/releases))
- neovim **0.12.4** (2026-07-05;
  [neovim releases](https://github.com/neovim/neovim/releases)) — repo pins
  0.11.6.
- git **2.55.0** (2026-06-29;
  [git releases](https://github.com/git/git/releases)) — repo pins 2.41.0.
- tmux **3.6a** ([tmux releases](https://github.com/tmux/tmux/releases)) —
  already pinned.
