# ssh role — post-quantum SSH client config

Configures the SSH **client** to prefer post-quantum (PQ) key exchange,
defending session confidentiality against "harvest-now, decrypt-later"
quantum attacks. This is the actionable slice of the broader
"quantum-safe encryption" audit (see below).

## What it does

The dotfiles **fully own `~/.ssh/config`**: the role symlinks
`config/files/ssh/config` to `~/.ssh/config` (`state: link, force: yes`), the
same way the git role owns `~/.gitconfig`. The managed file:

- Sets, for all hosts, the post-quantum key exchange policy:

  ```
  Host *
    KexAlgorithms ^mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com
  ```

  The leading `^` **prepends** these to OpenSSH's default `KexAlgorithms`
  list, so the PQ algorithms are preferred while the classical defaults remain
  as fallbacks. This is a *prefer-PQ* policy, not *PQ-only* — connecting to
  pre-9.0 servers still works. Because SSH uses the *first* obtained value for
  each option and this global `Host *` block sits at the top of the owned file,
  the PQ `KexAlgorithms` wins over anything in the Included fragments.

- `Include ~/.ssh/config.local` — an **untracked** identity fragment holding
  the user's `IdentityFile` directives. This repo is public, so identity/secret
  material is never committed; the user creates `~/.ssh/config.local`
  themselves. ssh silently ignores the Include when the file is absent. This
  mirrors how the git role Includes the untracked
  `~/.config/git/identity-work.gitconfig`.

- `Include ~/.ssh/config.d/*` — the user's host-specific configs, already split
  per file under `~/.ssh/config.d/` (the role ensures that directory exists but
  does not manage its contents).

> **Migration note:** the previous version of this role did *not* own
> `~/.ssh/config`; it only inserted an `Include` at the top via an
> Ansible-managed `blockinfile`. Now the role replaces `~/.ssh/config` with a
> symlink to the repo file. Before applying, pull any `IdentityFile` (and other
> machine-local/secret) directives out of the old `~/.ssh/config` into
> `~/.ssh/config.local` (`chmod 600`), since the old file is overwritten.

## Why key exchange (not host keys)

OpenSSH's PQ protection is in the key *exchange* (the ephemeral session key,
which is what a future quantum computer could recover from recorded traffic).
Host-key *authentication* has **no standardized PQ signature algorithm** yet,
so there is nothing to configure there — and authentication isn't vulnerable
to harvest-now-decrypt-later anyway (it's verified live).

Algorithms, in preference order:

| Algorithm | Basis | Availability |
|---|---|---|
| `mlkem768x25519-sha256` | ML-KEM (FIPS 203) hybrid | OpenSSH 9.9+ / 10.x |
| `sntrup761x25519-sha512@openssh.com` | NTRU Prime hybrid | default since OpenSSH 9.0 |

## OpenSSH version requirement / audit

`mlkem768x25519-sha256` requires **OpenSSH >= 9.9**. Unknown algorithm names
abort the client, so the fragment assumes a client that new. Status of the
OpenSSH the setup roles provide:

- **macOS** (`setup-macos/roles/dev-tools`): installs `openssh` via Homebrew →
  current (10.x). OK — supports both KEX. The dev machine used to author this
  reports `OpenSSH_10.2p1`.
- **Arch** (`setup-archlinux/roles/dev-tools`): no explicit `openssh` package;
  the rolling base system provides a current OpenSSH. OK.
- **Ubuntu** (`setup-ubuntu/roles/ssl`): installs `openssh-client` via apt. On
  the dated `ubuntu/bionic64` Vagrant box (OpenSSH 7.6) this is **too old** —
  it knows neither KEX and would abort. Even Ubuntu 24.04 (OpenSSH 9.6) has
  `sntrup761` but **not** `mlkem768` (< 9.9). This only affects the Vagrant
  test path (bit-rotted per AGENTS.md), not a real machine. **Needs a box
  bump** to an OpenSSH 9.9+ release before this fragment is valid there; until
  then it will break ssh inside that VM.

## Audit of the other quantum-safe surfaces (no action taken)

- **Symmetric / at-rest** (FileVault, LUKS, AES-256): already quantum-resistant
  — Grover only halves effective key length, and 256-bit keys retain a 128-bit
  security margin. Just prefer 256-bit. Nothing this repo configures.
- **GPG / OpenPGP**: GnuPG has no standardized PQ algorithms yet, and the repo
  manages no gpg config. Nothing actionable; revisit when PQC lands in GnuPG.
- **TLS clients** (curl, browsers; e.g. `X25519MLKEM768`): PQ hybrids are
  emerging but are library/application-driven, not dotfiles config. Out of
  scope here.

## Applying

Not yet applied on any machine (authored in a stale worktree). To apply on the
current machine:

```sh
config/config.sh --tags ssh
```

Verify afterward with `ssh -Q kex` (lists supported KEX) and
`ssh -G <host> | grep -i kexalgorithms` (shows the effective, prepended list).
