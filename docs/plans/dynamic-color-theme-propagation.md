# Dynamic Color Theme Propagation

## Context

`config/files/git/gitconfig-fragments/ui.gitconfig` hardcodes `delta.light`,
which has to be hand-flipped whenever the terminal switches between light and
dark. The rest of the setup is *supposed* to be dynamic: everything downstream
already keys off `$COLOR_THEME_NAME` (the `tmux-theme` script, the shell
prompt), but the source of that value —  `color_theme_name()` in
`config/files/color-theme/color-theme` — is stubbed to `echo light` with a
`# TODO: read this from an observable file`.

The real problem is not delta-specific. It is: **propagate the controlling
terminal's light/dark state from the terminal emulator, optionally across SSH,
optionally through tmux, to arbitrary theme-aware applications** — including on
a headless work machine that has no local OS appearance to detect.

## Key realization

The propagation is already solved by terminal escape sequences, in two
directions with different support levels:

- **Pull** ("am I light or dark?") — **OSC 11** (query background color). A
  terminal round-trip, so it traverses SSH and tmux transparently. Works on the
  headless box today.
- **Push** ("tell me when it changes") — **DEC private mode 2031**
  (color-scheme change reporting): enable with `CSI ? 2031 h`, terminal sends
  `CSI ? 997 ; 1 n` (dark) / `; 2 n` (light) on change.

## Support matrix (as of 2026-07)

| Layer (this stack)      | OSC 11 (pull) | Mode 2031 (push)                              |
| ----------------------- | ------------- | --------------------------------------------- |
| wezterm (laptop)        | yes           | **no** — wezterm#6454 / PR #7723 still open   |
| SSH                     | yes           | yes (transparent byte stream)                 |
| tmux 3.5a (installed)   | yes           | yes — merged Mar 2025; `client_theme`, `%client-dark-theme`/`%client-light-theme` hooks |
| Neovim 0.11.6           | yes (native since 0.11) | yes — sets `background` live, relays into `:terminal` |
| delta 0.18              | yes (Colorsaurus: OSC 11 + DA1) | n/a (per-invocation)          |

**The only blocker for fully automatic live switching is that wezterm does not
emit mode 2031 yet.** Everything below it is ready. Pull-based detection works
end to end right now.

## Two findings that shrink the problem

1. `f-person/auto-dark-mode.nvim` (`config/files/neovim/init.lua:603`) does
   *OS-level* detection (`defaults read AppleInterfaceStyle`, gsettings) — which
   is exactly what fails on a headless remote. Neovim 0.11 already sets
   `background` by querying the terminal (OSC 11, works over SSH) and updates it
   live via 2031. Dropping the plugin should make nvim *more* correct remotely.
2. delta can auto-detect on its own (delete `light = false`), but doing so makes
   it query the terminal on every invocation and risks the OSC-reply-leak bug
   (below). Prefer routing delta through the shared `$COLOR_THEME_NAME`.

## Design

### Tier 1 — dynamic pull detection (works everywhere today)

Single source of truth: `$COLOR_THEME_NAME`, backed by an "observable file" at
`$XDG_STATE_HOME/color-theme/name` (the file the existing TODO anticipates).

- **`color-theme-detect`** (new executable): query the terminal via OSC 11
  against `/dev/tty`, compute luminance, write `light`/`dark` to the state file,
  and echo it. No-op fallback (cached value, then default) when there is no tty
  or no reply. Run once at interactive shell startup and on manual refresh —
  **not** per application invocation.
- **`color_theme_name()`**: read the state file (cheap, no tty), fall back to
  `${COLOR_THEME_DEFAULT:-dark}`.
- **delta**: define `[delta "theme-dark"]` / `[delta "theme-light"]` feature
  blocks; export `DELTA_FEATURES="theme-$COLOR_THEME_NAME"` from the color-theme
  shell fragment. Remove `light = false`. delta then uses the same source as
  tmux and the prompt, with no per-call query.

This makes the entire existing system correct per session, including on the
headless machine.

### Tier 2 — push updates (expanded scope)

The original ceiling was that wezterm does not emit mode 2031 yet (issue #6454,
PR #7723 open, awaiting triage). Rather than wait for upstream, we build our own
wezterm from a fork that carries PR #7723, removing the ceiling.

**Fork (done).** `github.com/chpatton013/wezterm`, branch `csi-2031`, pinned at
`f33e689fb2f77f77516a4cc6c07a0e5e5e3f22dd` — the single commit from TymekDev's
PR #7723 ("implement mode CSI 2031 (color appearance reporting)") on top of
wezterm `main`. Touches the escape parser, term state, mux, and GUI (9 files).
Caveat: the PR is AI-assisted, awaiting triage, and reports *system appearance*
rather than true palette changes; treat the whole chain as experimental and be
ready to rebase the branch if upstream moves.

**wezterm source-build role (config playbook).** Follows the existing
source-build precedent of the `git` / `neovim` roles (build into
`xdg_prefix_home` = `~/.local`), but — unlike those — this one is *for* macOS,
since the GUI terminal is the laptop. Steps: clone the fork at the pinned SHA
into the source-releases data dir; run wezterm's dependency bootstrap; build
release; install. On macOS the GUI artifact is `WezTerm.app`, so "install" means
packaging/placing the app bundle. `creates:`-guarded for idempotency. Open
decision below on install strategy.

**tmux.** `set -g allow-passthrough on` plus `%client-dark-theme` /
`%client-light-theme` hooks that rewrite the state file and re-source
`tmux-theme`, so the status bar restyles live and new shells inherit it.

**nvim.** Drop `auto-dark-mode.nvim` (OS-level detection, fails headless); rely
on Neovim 0.11 native OSC 11 + mode 2031 detection.

**Manual refresh.** A `color-theme refresh` command / keybind that re-runs
`color-theme-detect` and pokes running apps — useful as a fallback and during
bring-up before the full push chain is trusted.

### Resolved decisions (Tier 2)

- **Install strategy**: side by side. macOS installs `~/Applications/WezTerm.app`
  and leaves the brew cask (`/Applications`) untouched; switch over manually once
  trusted.
- **Cross-platform**: the wezterm source build runs on both macOS and Linux (no
  packaged wezterm carries the PR). macOS produces the `.app`; Linux installs
  binaries + terminfo + desktop/icon into the XDG prefix (`~/.local`). Linux
  system build deps belong in the `setup-*` playbooks.
- **tmux**: bumped the from-source build to `3.6a` (first release with mode 2031
  + `client-*-theme` hooks) and made it cross-platform too — removed the
  macOS gate; macOS configure gets brew's libevent/ncurses paths and
  `--enable-utf8proc` via `LIBUTF8PROC_*` (no pkg-config needed). The tmux.conf
  hook block is version-gated (`>= 3.6`) so older tmux still loads cleanly.

## Caveats

- **OSC 11 reply leaking into the shell** (e.g. superset#4041): a background
  query's reply can land as stray prompt input when a foreground tool queries
  through a multiplexer. Querying once at shell init into the cached file (vs.
  delta querying on every git command inside tmux) avoids latency and minimizes
  exposure.
- **macOS archiver clash (wezterm build)**: brew `binutils` puts a GNU `ar`
  ahead of Apple's `/usr/bin/ar` on PATH. wezterm's vendored static libs
  (freetype, openssl, ...) then get GNU-format archives that macOS `ld` rejects
  ("archive member '/' not a mach-o file"). The role forces
  `AR`/`RANLIB`/`CMAKE_AR`/`CMAKE_RANLIB=/usr/bin/...` on Darwin and clears
  `target/release/build` so the archives regenerate.
- **tmux version skew on cutover**: a newer tmux client attaching to an
  already-running older server fails with the misleading "open terminal failed:
  not a terminal" (tmux #4356), *not* a build defect — verified this way after
  the 3.6a source build (a fresh-socket attach `tmux -L … new` works; the
  default socket fails while a 3.5a server is still running). Cutover requires a
  one-time `tmux kill-server` (ends existing sessions) so the 3.6a server owns
  the default socket.
- **Per-session vs global state**: a single file assumes one active appearance
  at a time (true for a single laptop). Keying the file by tty/session is
  possible but more complexity than currently warranted — leave a comment.

## Status

- [x] Tier 1: `color-theme-detect`, `color_theme_name()` rewrite, delta feature
      blocks + `DELTA_FEATURES`, remove `light = false`, link new script in role.
      Detection/classification/fallback and delta light-vs-dark switching all
      verified. Applying the `color-theme` role symlinks `color-theme-detect`;
      new shells then cache and export the detected theme.
- [x] Made `color-theme` a first-class role in `config.playbook.yml` (was only
      pulled in transitively via `zshrc`/`tmux`, so `--tags color-theme` was a
      no-op). Config applied clean on macOS.
- [x] Forked wezterm with PR #7723 -> `chpatton013/wezterm@csi-2031` (pinned
      `f33e689f`).
- [x] Tier 2 wiring: cross-platform wezterm source-build role (side-by-side
      install); tmux bumped to `3.6a` + cross-platform + version-gated 2031
      hooks (verified: builds on macOS, hooks activate under 3.6a, inert under
      3.5a); `color-theme-set` helper + `color-theme-refresh` shell function;
      removed `auto-dark-mode.nvim`.
- [x] wezterm fork build (macOS): built and installed to
      `~/Applications/WezTerm.app` (mach-o arm64, reports the fork commit
      `f33e689f`); brew cask left intact. Required forcing Apple's `ar` (see
      caveat). Linux install path written but not yet exercised on a Linux host.
- [x] Verified in the running system: our `~/Applications/WezTerm.app` is the
      active GUI (`WEZTERM_EXECUTABLE` confirms), gives a real TTY, and our tmux
      `3.6a` attaches cleanly on a fresh socket. The earlier "not a terminal"
      was tmux version skew against the running brew 3.5a server, not a build
      bug (see caveat).
- [x] Cutover + live test: after `tmux kill-server` (3.6a now owns the default
      socket), toggling macOS Appearance in our WezTerm propagates through the
      2031 push chain and re-themes the status bar / prompt / delta live.
      **Verified end to end (2026-07-15).**
- [ ] Follow-up: audit other source-build tool versions (see docs/followups.md).
