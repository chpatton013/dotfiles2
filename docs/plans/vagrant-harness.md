# Test Harness on Apple Silicon: Re-evaluate Vagrant

## Context

The repo's only test harness is Vagrant, used to provision a throwaway Linux VM
and run a platform's `setup-*/setup.sh` + `config/config.sh` end-to-end (there
is no other verification — see `AGENTS.md`: *"There are no build systems,
tests, or CI here"*). The valuable, provider-independent part is the ergonomics:

- `vagrant.sh` — a thin wrapper keyed on `DOTFILES_PLATFORM`; it sources
  `vagrant-env/$PLATFORM`, sets a per-platform `VAGRANT_DOTFILE_PATH`, and
  forwards to `vagrant`.
- `vagrant-env/{ubuntu,archlinux}` — export `DOTFILES_VAGRANT_BOX`,
  `DOTFILES_VAGRANT_DISKSIZE`, `DOTFILES_SETUP_DIR`.
- `Vagrantfile` — one shared file that consumes those env vars and wires the
  provision chain: `setup.sh` (root) -> `config.sh` (root) -> `config.sh` (as
  the `vagrant` user).

The followup **"Re-evaluate Vagrant as the test harness"** (`docs/followups.md`,
*Repo hygiene & tooling*, Status: Selected) flags the blocker: the harness pins
the **VirtualBox** provider, which the user has never gotten working on Apple
Silicon (same root cause as the "VMs fail/hang on macOS" note in the *Install a
backlog of packages* item). This is **largely a DECISION** — the harness choice
is the user's; this plan compares options and recommends one.

### What the harness actually pins to VirtualBox (audit)

- `Vagrantfile:10` — `config.vm.provider "virtualbox"` (hardcoded; only sets
  `memory`/`cpus`).
- `config/roles/vagrant/files/3-vagrant.sh` — `export
  VAGRANT_DEFAULT_PROVIDER=virtualbox` (the shellrc fragment forces the default
  provider on this machine).
- `vagrant-env/ubuntu` — box `ubuntu/bionic64` (18.04, **EOL**, amd64-only, a
  VirtualBox box).
- `vagrant-env/archlinux` — box `archlinux/archlinux` (VirtualBox-oriented).
- `setup-ubuntu/roles/vagrant/meta/main.yml` — depends on `virtualbox` (+
  `docker`, `libvirt`, `lxc`, `qemu`); `setup-ubuntu/roles/virtualbox/` installs
  it via apt. This is Linux-guest tooling and is orthogonal to the macOS host
  problem, but shows VirtualBox is baked in as *the* provider assumption.

### What already points toward QEMU (important — the switch is half-done)

- `config/roles/vagrant/tasks/main.yml` **already installs the `vagrant-qemu`
  plugin** (alongside `vagrant-cachier`, `-compose`, `-env`, `-sshfs`,
  `-vmware-desktop`); `vagrant-libvirt` is installed only on non-Darwin.
- `setup-macos/roles/dev-tools/tasks/main.yml` already `brew install`s **`qemu`**
  (line 35) and the **`vagrant`** cask (line 71), plus `macfuse`. There is **no
  VirtualBox on macOS** anywhere in the repo (no `setup-macos` virtualbox role).

So on an Apple-Silicon Mac the tooling to run `vagrant-qemu` is already present;
what blocks it is the three hardcoded VirtualBox pins above and the dated,
amd64/VirtualBox boxes.

## Options considered

Requirement to satisfy: on an **Apple-Silicon Mac**, provision a **fresh Ubuntu
and a fresh Arch machine** end-to-end via `setup-*/setup.sh` (needs root, real
`apt`/`pacman`, **systemd** services, source builds into `~/.local`) then apply
`config/config.sh`. That fidelity requirement (a real init system + package
manager + `brew services`-style service management on Linux) rules out anything
that isn't a full VM as the *primary* harness.

| Option | Apple-Silicon fit | Ubuntu | Arch | Churn from today | Notes |
| --- | --- | --- | --- | --- | --- |
| **Vagrant + `vagrant-qemu`** | Good (native aarch64; x86 via slow TCG emulation) | arm64 boxes exist | **weak** — no well-maintained aarch64 Arch box | **Low** — plugin + qemu already installed; change 3 pins + boxes | Keeps the whole `vagrant.sh`/env-file/provision-chain design |
| Vagrant + UTM (`vagrant_utm`) | Good (Apple Virtualization.framework) | yes | limited | Medium | New/less-proven plugin; pulls in a GUI app; least CI-friendly |
| **Lima / colima** | **Best** (Apple-Silicon-native, VZ + rosetta) | first-class images | community template | High (rewrite harness) | YAML per platform + cloud-init/provision scripts; great CLI, no GUI; not the Vagrant provision model |
| Tart | Very good (VZ, fast, OCI images) | fewer Linux images | none ready | High | CI-oriented (Cirrus); strongest for *macOS* guests, weaker for our Linux/Arch need |
| Containers (Docker/Podman) | Good, but low fidelity | n/a (not a VM) | n/a | High | No real kernel/systemd; can't faithfully test `setup-*` (services, source builds, kernel bits). At best a fast **config-only** smoke test, not a replacement |

Key discriminators for *this* repo:

- **Arch on arm64 is the hard constraint.** Vagrant Cloud has no maintained
  aarch64 Arch box; Lima has a community Arch template but it too is
  arm64-limited. Whichever harness wins, Arch-on-Apple-Silicon will be the
  fragile leg — likely served by an arm64 community image or x86 emulation.
- **Containers can't test `setup-*`** (the thing we most want to test is a full
  machine provision), so they're only a supplementary fast path, not the answer.
- **The Vagrant ergonomics are the asset**, and they're provider-agnostic. The
  provider is a small, swappable slice of the design.

## Recommendation

**Keep Vagrant; switch the provider from VirtualBox to `vagrant-qemu`.** Adopt
Lima/colima as the documented fallback if QEMU box friction (especially Arch
arm64) proves too painful in practice.

Rationale:

1. **Lowest churn for the most value.** The `vagrant.sh` wrapper, per-platform
   env files, and the `setup.sh`->`config.sh`->`config.sh` provision chain — the
   parts the user built and likes — are untouched. Only the provider slice
   changes.
2. **The tooling is already installed.** `vagrant-qemu` is already in the
   `config/roles/vagrant` plugin list and `qemu` + the `vagrant` cask are already
   installed by `setup-macos` dev-tools. The switch is essentially removing three
   VirtualBox pins and moving to arm64 boxes.
3. **It preserves multi-platform IaC.** One `Vagrantfile`, N env files — adding a
   platform stays a one-file change, which is why the harness was built this way.
4. **Full-VM fidelity** (real systemd, apt/pacman, source builds) is retained,
   which containers cannot provide.

Honest tradeoffs / why this could flip to Lima:

- `vagrant-qemu` is a **community plugin** and can be finicky; the user's history
  of "VMs fail/hang on macOS" is a real risk against any VM harness, and Vagrant
  adds a layer over QEMU that can obscure failures. If it fights back, **Lima is
  the more Apple-Silicon-native, better-maintained substrate** — the cost is
  rewriting the harness (per-platform lima YAML + provisioning that invokes
  `setup.sh`/`config.sh`, replacing the Vagrantfile provision chain) and giving
  up the Vagrant box ecosystem.
- **Arch arm64** is weak on *both*; expect to pin a specific community arm64
  image or fall back to slow x86_64 TCG emulation for Arch regardless of harness.

This is a decision for the user (see FINAL REPORT). The migration below is
written for the recommended path (Vagrant + qemu); the Lima fallback is sketched
at the end.

## Migration outline — Vagrant + qemu (recommended path)

Files that change (nothing destructive; harness doesn't run on this machine):

1. **`Vagrantfile`** — replace the hardcoded `virtualbox` provider block with a
   `qemu` provider block. `vagrant-qemu` uses `qe.arch`, `qe.machine`,
   `qe.cpu`, `qe.net_device`, `qe.memory`, `qe.smp`, etc. On Apple Silicon,
   native aarch64 guests use `qe.arch = "aarch64"` + `qe.machine = "virt"` +
   `qe.cpu = "host"`; emulated x86_64 guests set `qe.arch = "x86_64"` (much
   slower, TCG). Keep memory/cpus. Consider parameterizing the provider via an
   env var (e.g. `DOTFILES_VAGRANT_PROVIDER`, defaulting to `qemu`) sourced from
   the env file, so a platform that still needs a different provider can override
   without editing the Vagrantfile — mirrors the existing env-file convention.
   Note: `disksize.size` (the `vagrant-disksize` plugin) may not apply under the
   qemu provider the way it does under VirtualBox — verify, and drop/replace the
   plugin if it's a no-op for qemu.

2. **`vagrant-env/ubuntu`** — replace `ubuntu/bionic64` with a **maintained
   arm64** Ubuntu box (e.g. a 24.04 LTS arm64 box; `bionic64` is EOL and
   amd64-only regardless). Set `DOTFILES_VAGRANT_BOX` accordingly; add the
   provider var if introduced in step 1.

3. **`vagrant-env/archlinux`** — the weak spot. Either pin a community **arm64**
   Arch box or accept **x86_64 emulation** here (set the provider/arch env vars
   so the Vagrantfile emulates). Document the choice inline; this is the item
   most likely to need iteration.

4. **`config/roles/vagrant/files/3-vagrant.sh`** — change `export
   VAGRANT_DEFAULT_PROVIDER=virtualbox` to `qemu` (this fragment is linked
   verbatim by `config/roles/vagrant/tasks/main.yml`; re-run `config/config.sh
   --tags vagrant` to relink after editing).

5. **`config/roles/vagrant/tasks/main.yml`** — plugin list already includes
   `vagrant-qemu`; no change strictly required. Optional cleanup: prune
   VirtualBox/VMware-specific plugins that don't apply on macOS (out of scope for
   the minimal switch; fold into the *Audit the project* followup).

6. **`README.md` "Testing changes" section** (lines ~46-90) — update the prose:
   the harness now uses QEMU (not VirtualBox), state the Apple-Silicon story, and
   note the Arch-arm64 caveat. Keep the `DOTFILES_PLATFORM`/`vagrant.sh` usage
   examples (unchanged).

7. **`setup-ubuntu/roles/vagrant/meta/main.yml` + `setup-ubuntu/roles/virtualbox/`**
   — Linux-guest-side only; the macOS host switch does not require touching
   these. If the intent is to stop assuming VirtualBox anywhere, drop the
   `virtualbox` dependency from the Ubuntu vagrant role's `meta` (it already
   depends on `qemu`/`libvirt`) and consider removing the `virtualbox` role.
   **Defer** unless the user also wants Linux hosts off VirtualBox — flag as a
   follow-up, not part of the Apple-Silicon fix.

## Implemented (with a structured-spec evolution)

The qemu switch above was implemented, and — per user follow-up — the harness's
per-platform config was upgraded from shell-export env files to **structured
YAML specs** parsed by the `Vagrantfile`:

- `vagrant-env/<platform>.yaml` replaces the old shell `vagrant-env/<platform>`
  files. Each spec is a **shadowing tree**: `params` at the top level are
  overridden by provider-level params, then by architecture-level params, so a
  file specifies only what differs. `box`/`setup_dir` shadow the same way.
- The `Vagrantfile` parses the spec with Ruby stdlib `YAML` (no plugin/gem),
  detects the **host architecture** (`uname -m`), and picks the arch entry
  matching the host, falling back to the first listed (so `archlinux` emulates
  x86_64 on Apple Silicon automatically). `DOTFILES_VAGRANT_PROVIDER` and
  `DOTFILES_VAGRANT_ARCH` override provider/arch.
- Providers handled: `qemu` (default), `virtualbox`, and now **`libvirt`**
  (Linux hosts). `memory_mb`/`cpu_count` are shared across all three; `disk_gb`
  is applied under virtualbox (`vagrant-disksize`) and libvirt
  (`machine_virtual_size`) but **not qemu** (vagrant-qemu has no disk-resize).
- `vagrant.sh` no longer sources an env file; it validates the `.yaml` exists and
  exports `DOTFILES_PLATFORM` for the Vagrantfile to consume.

Still needs a live run to validate (box names, qemu machine/accel params, and
the full provision chain) — see Verification.

## Migration outline — Lima/colima (fallback path, if qemu is rejected)

Bigger rewrite; sketch only:

- Replace `vagrant.sh` with a wrapper that shells out to `limactl` keyed on
  `DOTFILES_PLATFORM`; replace `vagrant-env/*` with per-platform `lima/*.yaml`
  (image, disk, mounts, and a `provision` block that runs the setup/config
  chain). Drop the `Vagrantfile`.
- The provision chain (`setup.sh` root -> `config.sh` root -> `config.sh` user)
  moves into lima `provision` scripts or a post-`limactl start` `limactl shell`
  invocation.
- `config/roles/vagrant` becomes a `config/roles/lima` (or is dropped);
  `setup-macos` dev-tools swaps the `vagrant` cask for `lima`/`colima`.
- Same Arch-arm64 caveat applies (community template).

## Verification

Cannot run on this machine (no VM/provider here — this plan is read/static +
write-only). When implemented on the Apple-Silicon Mac:

- `DOTFILES_PLATFORM=ubuntu ./vagrant.sh up --no-provision` then `./vagrant.sh
  provision` — confirm the VM boots under qemu (native aarch64) and the full
  `setup-ubuntu/setup.sh` + `config.sh` chain completes.
- Repeat for `archlinux` — this is the risky leg; capture whether the chosen box
  is arm64-native or x86 emulated and how slow emulation is.
- Confirm `vagrant.sh halt`/`destroy` and the per-platform
  `VAGRANT_DOTFILE_PATH` isolation still work.
- Sanity-check `disksize` actually resizes under qemu (or that its removal is
  benign).

## Risks / open questions

- **`vagrant-qemu` maturity.** Community plugin; less battle-tested than the
  VirtualBox provider. If provisioning hangs/fails (the user's recurring macOS-VM
  pain), escalate to the **Lima fallback** rather than fighting the plugin.
- **Arch on arm64 (primary risk).** No maintained aarch64 Arch Vagrant box; the
  realistic choices are a specific community arm64 image (pin + revisit) or
  x86_64 TCG emulation (correct but slow). Decide per acceptable iteration speed.
  This risk is harness-independent (Lima has it too).
- **`vagrant-disksize` under qemu.** Plugin behavior may differ or be a no-op;
  verify or drop.
- **Box trust/provenance.** Moving off the official `ubuntu/*` boxes to community
  arm64 boxes means vetting the publisher.
- **Scope creep into Linux-host tooling.** The `setup-ubuntu` virtualbox/vagrant
  roles are a separate concern (Linux hosts, not the Apple-Silicon fix); resist
  bundling their cleanup here — note as a follow-up.
- **Decision is the user's.** Recommended: Vagrant + qemu (low churn, tooling
  already present). Fallback: Lima/colima. Containers are explicitly **not** a
  replacement for `setup-*` testing (no real init/kernel), at most a future fast
  config-only smoke test.
