# macOS Setup Fixes: Rosetta 2 + keg-only Homebrew PATH

Two related Provisioning & setup follow-ups (see `docs/followups.md`), both about
making a fresh macOS provision succeed unattended:

1. Install Rosetta 2 so x86_64-only apps/casks run on Apple Silicon.
2. Make keg-only Homebrew formulae (observed: `ruby`) reachable so setup/config
   stop erroring with "brew cellar isn't on path".

They are independent fixes but share the theme of "system prep the playbooks
currently assume was done by hand." Part 2 is also the concrete pain behind the
**Write a bootstrap script** follow-up (`README.md` TODO: "setup and config
scripts both fail on mac because brew cellar isn't on path").

> **Status: implemented** (see `docs/followups.md` for the commit). The original
> analysis is kept below; the resolved decisions:
>
> - **Part 1 — Rosetta:** task added to
>   `setup-macos/roles/xcode/tasks/main.yml`, arm64-guarded and skipped when
>   `/Library/Apple/usr/share/rosetta/rosetta` exists.
> - **Part 2 — `brew link` is the sole mechanism; the shellrc calc is dropped.**
>   `find_homebrew_packages` is removed from
>   `config/files/shellrc/2-pathlist-macos.sh`; `find_gnu_packages` **stays**
>   (brew link can't replace it — the `libexec/gnubin` dirs provide *un-prefixed*
>   GNU commands that linking the formula would not). A `brew link --force` task
>   in `setup-macos/roles/dev-tools/tasks/main.yml` links the keg-only CLI
>   formulae onto PATH: `file-formula`, `m4`, `ruby`, `unzip` (verified to link
>   only `bin/` + `man/`, no lib/header shadowing). Deliberately **not** linked:
>   `binutils` (its GNU `ar` would shadow Apple's `ar` during source builds — the
>   wezterm-build class of bug, now on the *provisioning* PATH via
>   `/opt/homebrew/bin`) and the keg-only *libraries* (`ncurses`, `sqlite`;
>   `berkeley-db`/`icu4c` aren't installed) whose global linking is exactly what
>   keg-only exists to prevent. Note: on current Homebrew `ruby` is no longer
>   keg-only and auto-links, so the original "ruby not on PATH" failure is
>   already resolved upstream; the task keeps `ruby` for machines/versions where
>   it is keg-only.

---

## Part 1 — Install Rosetta 2

### Context / why

Some brew casks and third-party apps ship x86_64-only binaries; on Apple Silicon
they need Rosetta 2. `softwareupdate --install-rosetta --agree-to-license`
installs it non-interactively. Today nothing in `setup-macos/` does this, so a
fresh Apple Silicon machine can install x86 casks that then fail to launch. The
`README.md` TODO scratchpad already notes this plus a "rosetta packages" group
(`sensiblesidebuttons`, `steam`, `signal`).

### Approach

Add one idempotent, `become`-elevated Ansible task, guarded to Apple Silicon and
skipped when Rosetta is already installed.

- **Role placement:** put it in `setup-macos/roles/xcode/`. That role is already
  the "system prep" role (accepts the Xcode license, installs CommandLine Tools),
  already uses `become: yes`, and is a `meta` dependency of `dev-tools`
  (`setup-macos/roles/dev-tools/meta/main.yml`), so it runs before any brew cask
  install. `dev-tools`/`homebrew` are about packages, not OS provisioning — Xcode
  is the natural home. (Rosetta has no ordering dependency on the CommandLine
  Tools block, so it can be a sibling task in the same `tasks/main.yml`.)

- **Apple Silicon guard:** `when: ansible_facts['architecture'] == 'arm64'`
  (Intel Macs neither need nor can install Rosetta). Confirm the exact fact value
  on the target during bring-up (`machdep.cpu.brand_string` /
  `ansible_facts['architecture']`).

- **Idempotency guard:** skip if Rosetta is already present. `softwareupdate
  --install-rosetta` is itself close to idempotent, but re-running it is slow and
  noisy, so gate it. Preferred check: `stat` for the runtime marker
  `/Library/Apple/usr/share/rosetta/rosetta` (or
  `/Library/Apple/usr/libexec/oah/libRosettaRuntime`); alternatively
  `pgrep -q oahd`. Prefer a file `stat` over a process check for determinism.

- **Privilege:** the install needs root. The task runs under `become: yes` (the
  `xcode` role block already does; `setup.sh` passes `--ask-become-pass` for
  non-root invocations).

### Steps

1. In `setup-macos/roles/xcode/tasks/main.yml`, add:
   - `stat` on the Rosetta runtime marker path → register `rosetta_stat`.
   - A `command`/`shell` task running
     `softwareupdate --install-rosetta --agree-to-license`, with
     `become: yes` and
     `when: ansible_facts['architecture'] == 'arm64' and not rosetta_stat.stat.exists`.
   - Follow repo YAML style (`---` + blank line, `{{item}}` with no inner spaces,
     2-space indent).
2. No new role, defaults, or playbook wiring needed — `xcode` is already pulled
   in transitively via `dev-tools`. (If we want `--tags` reachability, add a tag,
   but keep scope minimal.)

### Verification

- Fresh/Intel-simulated run: task skips on non-arm64 and when the marker exists
  (idempotent no-op on re-run).
- On an Apple Silicon machine without Rosetta: task runs once, then subsequent
  runs report `ok`/skipped. Confirm an x86-only cask launches afterward.
- `--check --diff` to preview before applying.

### Risks / open questions

- Confirm the marker path is stable across macOS versions; `pgrep oahd` is a
  fallback signal.
- `--agree-to-license` accepts Apple's license non-interactively — intended here.
- Exact `ansible_facts['architecture']` value on the target (arm64 vs aarch64)
  should be verified rather than assumed.

---

## Part 2 — Keg-only Homebrew formulae on PATH

### Context / why

On the work Mac, both `setup-macos/setup.sh` and `config/config.sh` error out
because keg-only formulae are not on `PATH` — observed with `ruby` (installed in
`setup-macos/roles/dev-tools/tasks/main.yml`), which Homebrew does not symlink
into `/opt/homebrew/bin` and instead prints its "add to PATH / `brew link`"
caveat. Other keg-only formulae likely have the same problem.

**Key finding — the interactive story is already solved, the provisioning story
is not.** `config/files/shellrc/2-pathlist-macos.sh` already prepends keg-only
bins (`find_homebrew_packages` lists `/opt/homebrew/opt/ruby/bin` among others),
and its commented-out derivation *is exactly the user's proposed method* (find
`*/bin` dirs under the Cellar, keep the ones whose `realpath` differs from
`which` after `/opt/homebrew/bin` is on PATH). So a normal interactive shell gets
`ruby` on PATH. The failure is that `setup.sh` and `config.sh` run under
`#!/bin/bash --norc` and invoke `ansible-playbook` directly — they never source
the shellrc fragments, so at *provision time* only `/opt/homebrew/bin` (if that)
is on PATH and keg-only bins are missing. Ansible tasks that shell out to `ruby`
(or a formula built against keg-only `ruby`) then fail.

Could we use `brew link` as a simpler alternative to calculating a complicated
PATH list?

### Approach

Two complementary fixes; recommend doing both, but the setup-side fix is the one
that unblocks provisioning.

**A. Make setup ensure keg-only bins are reachable during provisioning
(primary).** Options, in preference order:

- **A1 — `brew link` the needed keg-only formulae.** Add a task in
  `setup-macos/roles/dev-tools/tasks/main.yml` (after the `homebrew` install
  task) that runs `brew link --overwrite <pkg>` for the formulae we depend on at
  provision time (start with `ruby`). Simple and puts the bins in
  `/opt/homebrew/bin` (already on PATH). Downside: `brew link` on a keg-only
  formula can shadow the macOS system version (e.g. system `ruby`) — that is
  usually the intent here but should be a deliberate list, not blanket.
  Use `--overwrite`/`--force` as needed and make it idempotent (`brew link` is
  a no-op if already linked; guard with a `creates:`-style check or
  `changed_when` on output).

- **A2 — put the keg-only bin dirs on PATH for the playbook run without
  linking.** Either prepend them in the `environment:` of the tasks/role that
  need them, or export them in `setup.sh`/`config.sh` before the
  `ansible-playbook` call. Avoids mutating the brew prefix but duplicates the
  path logic that already lives in `2-pathlist-macos.sh`.

Recommend **A1** for the specific formulae the playbooks invoke (keeps PATH
derivation in one place — shellrc — and keeps the brew prefix authoritative),
falling back to A2 only if linking a formula is undesirable.

**B. Keep the interactive PATH list correct and current (secondary).**
`2-pathlist-macos.sh` already covers this via `find_homebrew_packages`, but the
list is a hand-maintained cache. Re-run the user's investigation method to catch
formulae added since the list was generated:

```
# Enumerate candidate keg-only bin dirs and check whether each executable
# actually resolves to the Cellar copy after /opt/homebrew/bin is on PATH.
executables=$(
  find -L /opt/homebrew/opt/ -name bin -type d |
  xargs -I{} find {} -type f -perm -u+x |
  xargs -I{} realpath {} |
  sort -u
)
while IFS= read -r exec; do
  if [ "$(realpath "$(which "$(basename "$exec")")")" != "$exec" ]; then
    dirname "$exec"   # this bin dir is NOT effectively on PATH -> candidate
  fi
done <<< "$executables" | sort -u
```

(This is the same logic already captured in the file's comment; the point is to
refresh the cached list and confirm `ruby` and any new keg-only formulae are
present.)

### Where PATH additions should live: shellrc vs setup

- **Interactive shells → shellrc** (`2-pathlist-macos.sh`). This is the existing,
  correct home and already handles the general keg-only case. Keep it as the
  source of truth for a user's runtime PATH.
- **Provisioning (setup.sh / config.sh) → setup-side.** shellrc is *not* sourced
  by the `--norc` provisioning scripts, so relying on it during provisioning is
  the actual bug. Fix it where the playbook runs: either `brew link` (A1, so the
  bins land in the already-on-PATH `/opt/homebrew/bin`) or an explicit
  `environment:`/export (A2). Do **not** try to make the provisioning scripts
  source shellrc — that couples the two phases and fights the two-phase model in
  `AGENTS.md`.

### Relationship to the bootstrap-script follow-up

This is the same PATH problem called out in **Write a bootstrap script**
(`README.md`: "setup and config scripts both fail on mac because brew cellar
isn't on path"). A future bootstrap that shims `/opt/homebrew/bin` (and needed
keg-only bins) onto PATH before delegating to `setup-*/setup.sh` and
`config/config.sh` would subsume the A2 variant. Fixing it here (A1) is the
narrow, immediate unblock; the bootstrap work is the broader solution. Note the
overlap so the two are reconciled, not duplicated.

### Steps

1. Confirm the exact failing formulae on the work Mac (reproduce the setup/config
   error; `ruby` is the known one). Run the investigation snippet above to list
   all effectively-off-PATH keg-only bins.
2. Add a `brew link` task (A1) to `setup-macos/roles/dev-tools/tasks/main.yml`
   for that set, idempotent and `become`-free (brew runs as the user), placed
   after the `homebrew` install task. Alphabetize the formula list per repo
   convention.
3. Refresh the `find_homebrew_packages` cached list in
   `config/files/shellrc/2-pathlist-macos.sh` if the investigation turns up
   formulae missing from it. (Editing the file under `config/files/` takes effect
   immediately; no re-apply needed — see `AGENTS.md`.)
4. If any needed formula must stay unlinked, apply A2 (`environment:` on the
   task, or export in the setup entrypoint) instead of linking it.

### Verification

- Re-run `setup-macos/setup.sh` and `config/config.sh` on the work Mac; both
  complete without the "link"/"cellar isn't on path" errors.
- In a fresh non-interactive shell after setup: `which ruby` resolves to the
  Cellar/opt copy (via link or PATH), and the investigation snippet reports no
  remaining off-PATH keg-only bins for the formulae we depend on.
- Interactive shell still resolves the same (shellrc unchanged behavior).

### Risks / open questions

- **`brew link` shadowing system tools:** linking keg-only `ruby` overrides the
  macOS system `ruby`. Intended for our use, but keep the linked set explicit and
  minimal; avoid a blanket "link everything keg-only."
- **`--overwrite` clobbering:** needed if a symlink already exists; ensure it
  only touches our formulae.
- **Cached list drift:** the hand-maintained `find_homebrew_packages` list can go
  stale as new keg-only formulae are added; the investigation method is the way
  to keep it honest (also relates to the periodic-audit follow-up).
- **Which formulae beyond `ruby`?** Open until the investigation snippet is run
  on the actual machine.
