# Statusline + Prompt Overhaul

> **Status: direction chosen — not started.** Lays out approaches for the
> Terminal & theming followup ("Replace the hand-rolled tmux statusline and
> shell PS1 with a prettier, consistent system"). The user has now weighed in
> (see the resolved decision list at the bottom): **Option B — a single unified
> hand-rolled script** driving both prompts + the tmux statusline, with runtime
> nerd-font detection and an ASCII fallback. Options A/C are kept for the record.
> A follow-on implementation plan will specify concrete files/roles.

## Context / why

The current status/prompt styling was deliberately built to avoid patched
(nerd) fonts, so it is drawn entirely from ASCII + solid color blocks. That
constraint no longer holds (we control the terminal and can install a font), and
the result is high-visibility but not pretty, and — worse — it is **three
separate implementations that drift**:

- **tmux statusline** — `config/files/tmux/tmux-theme` (a bash script that emits
  `status-left` / `status-right` / `window-status-*` format strings), invoked
  from `config/roles/tmux/templates/tmux.conf` via
  `#(tmux-theme <segment>)` with `status-interval 1`.
- **zsh prompt** — `config/files/zshrc/4-prompt.zsh` (zsh `%`-escapes,
  `prompt_segment` helper, `PROMPT_SUBST`).
- **bash prompt** — `config/files/bashrc/4-prompt.bash` (bash `\`-escapes, ANSI
  `\e[...m`, `PROMPT_COMMAND`). A **parallel but independent** reimplementation
  of the zsh one — this is the divergence we want to kill.

All three consume the same color source: **the `color-theme` system**
(`config/files/color-theme/color-theme`). That script resolves a set of semantic
256-color slots — `COLOR_THEME_{ACTIVE,INACTIVE,BODY,HIGHLIGHT,INVERT}_{BG,FG}`
plus an `ACTIVE_BG` accent derived from a hostname hash — and exports them as
env vars (`color-theme shell` → `eval`). It is **light/dark aware** via Tier 1
of `docs/plans/dynamic-color-theme-propagation.md`: `color-theme-detect` writes
`light`/`dark` to `$XDG_STATE_HOME/color-theme/name`, `color_theme_name()` reads
it, and Tier 2 (tmux `client-*-theme` hooks calling `color-theme-set`, the
wezterm CSI-2031 fork) restyles live on appearance change. **Any replacement
must keep consuming that single source of truth** so the whole stack stays in
lockstep and the live light/dark switching keeps working — this is the hard
constraint on the design.

Adjacent surfaces the followup names as "should look consistent": tmux, nvim
(lualine, already themed separately), pi-agent (`config/files/pi-agent/` — its
`settings.json` has `"theme": "dark"` and a `pi-auto-theme` plugin), and
optionally the zsh right-prompt / vcs info.

### The font question (applies to every option)

Nothing in the repo installs a nerd font today. wezterm uses plain
`Monaco` with no glyph fallback (`config/files/wezterm/wezterm.lua:7-10`), and
no font cask appears in `setup-macos/roles/dev-tools` (casks: `claude-code`,
`macfuse`, `vagrant`, `wezterm@nightly`) or `user-tools`. So **any "pretty"
option that uses powerline separators / nerd glyphs pulls in a font install as a
prerequisite**:

- Add a nerd-font cask to a setup role (e.g. `font-monaspace-nerd-font`,
  `font-jetbrains-mono-nerd-font`, or a patched Monaco-alike), and on Linux add
  the equivalent `fonts-*` / manual install.
- Add the family to the wezterm `font_with_fallback` list. **Decided: keep
  Monaco primary and append a glyph-only `Symbols Nerd Font Mono` fallback** so
  only glyphs resolve from the nerd font and body text stays Monaco. (Lower-risk
  than swapping the primary font.)
- SSH/remote caveat: glyphs only render if the **terminal emulator's** font has
  them. Inside our wezterm (local, and the rendering end of an SSH session) they
  will — but the same shell config may run under a terminal *without* the font
  (a plain console, Terminal.app, a Linux VT, a coworker's machine). That is the
  tofu risk the user flagged, and it is why Option B carries an explicit
  **glyph-capability detection + ASCII fallback** (see below) rather than
  assuming glyphs are always available.

## Options

> **Chosen: Option B.** The user picked the unified hand-rolled script (single
> source of truth for prompt + tmux statusline, no new binary dependency), with
> the added requirement of nerd-font detection + ASCII fallback. Options A and C
> are retained below for the record / in case the direction is revisited.

### Option A — Starship for prompts + a tmux theme, both fed by color-theme (not chosen)

Adopt [starship](https://starship.rs) as the **cross-shell prompt** and replace
`tmux-theme`'s hand-drawn segments with a themed statusline (either a curated
hand-written tmux status or a plugin like `catppuccin/tmux` /
`tmux-powerline`).

- **Kills the zsh/bash divergence outright**: starship is a single `starship.toml`
  rendered identically in zsh and bash (and fish, etc.), init'd with
  `eval "$(starship init zsh|bash)"`. Deletes both `4-prompt.zsh` and
  `4-prompt.bash`, replacing them with one `3-starship.sh` fragment (or a
  `4-*`), plus a new `config/roles/starship` linking `starship.toml`.
- **Pretty for free**: nerd-font powerline segments, git status/branch/stash,
  cmd duration, exit status, language versions — all built in and far nicer than
  the current blocks. Requires the font install (above) and a `starship` binary
  (brew formula on mac; source/binary on Linux — candidate for the dotslash
  followup).
- **Light/dark is the sharp edge.** starship colors live in a **static**
  `[palettes]` block selected by a single `palette = "..."` key; there is no
  first-class "read the color from `$COLOR_THEME_NAME`" at render time. Options
  to preserve Tier 1 awareness, roughly in order of cleanness:
  1. **Two configs + swap `STARSHIP_CONFIG`.** Ship `starship-dark.toml` /
     `starship-light.toml` (or one file, two palettes) and have the color-theme
     shell fragment export `STARSHIP_CONFIG` based on `$COLOR_THEME_NAME`. Live
     switching still works because starship re-reads config each prompt; the
     tmux `client-*-theme` hook already reblits the state file, so the next
     prompt picks the right config. Simple, robust; two files to keep in sync.
  2. **Render `starship.toml` from color-theme values via a template** the way
     the repo already renders `templates/vars.sh`. Loses live switching unless
     regenerated on toggle (worse than #1).
  3. Accept a single palette that reads acceptably on both backgrounds (drop
     dynamic prompt theming). Cheapest, but abandons a working feature.
  Recommended sub-choice: **#1** — keeps live light/dark, costs one duplicated
  TOML.
- **tmux side is separate work**: starship does not theme tmux. Either keep a
  (prettified) `tmux-theme` script still reading `color-theme` — lowest risk,
  keeps the live-switch hook untouched — or adopt a tmux theme plugin and drive
  its colors from `color-theme` (most plugins hardcode palettes, so this is
  fiddlier than it looks and can fight the existing `tmux-colors-solarized` +
  `client-*-theme` wiring). Leaning: **prettify the hand-rolled `tmux-theme`
  with nerd separators, keep it color-theme-driven**, rather than importing a
  plugin whose palette we'd have to fight.
- **pi-agent / nvim**: unaffected mechanically; consistency is achieved by
  matching the same solarized-ish palette + separator glyph, not by shared code.

### Option B — Unified hand-rolled system (one script, all surfaces) — CHOSEN

Keep everything homegrown but **collapse the three implementations into one**.
Write a single prompt-rendering script (e.g. `config/files/prompt/prompt`) that
emits an abstract segment list, with thin per-target adapters:

- a `--zsh` mode emitting `%`-escapes for `PS1`,
- a `--bash` mode emitting `\[\e[...m\]` escapes for `PROMPT_COMMAND`,
- reusing the **same** segment definitions and the **same** `color-theme` slots
  the `tmux-theme` script already uses (arguably fold tmux segments into the
  same script too).

- **Pros**: no new dependency, no font strictly required (though we'd still add
  nerd separators to get "pretty"), keeps the exact `color-theme` integration
  and live-switch behavior with zero new moving parts, stays in the repo's
  bash-script idiom (`#!/bin/bash --norc`, `set -euo pipefail`). Single source of
  truth for prompt + statusline means they literally cannot drift.
- **Cons**: we reimplement what starship gives for free (git status, durations,
  async segment rendering, escape-length accounting so line wrapping is correct
  — bash `\[ \]` / zsh `%{ %}` width bookkeeping is the classic footgun the two
  current scripts each handle by hand). More code to own; "pretty" is entirely
  on us. The zsh/bash escape divergence is *reduced to one file* but not
  *eliminated* — the two adapters still differ, just co-located.
- This is essentially "do the current thing, but DRY and with nicer glyphs." Low
  external risk, higher maintenance.

Per the user's decisions, Option B is scoped as follows:

- **One script drives prompt + tmux** (decision 5, "consolidate into one
  script"). tmux's `status-left` / `status-right` / `window-status-*` become
  additional emit modes of the same script (e.g. `prompt tmux-status-left`),
  alongside `prompt zsh` / `prompt bash`. This replaces both `tmux-theme` and
  the two `4-prompt.*` files with a single `config/files/prompt/prompt` (name
  TBD) plus thin shell fragments. It keeps reading the `color-theme` slots
  exactly as today, so the Tier 1/Tier 2 live light/dark pipeline is untouched.
- **No tmux plugin** (decision 2). The prettification is done in-script with
  nerd separators; we do not import catppuccin/tmux, tmux-powerline, etc. This
  also avoids fighting the existing `tmux-colors-solarized` + `client-*-theme`
  wiring.
- **pi-agent / nvim are left as-is** (decision 6). No attempt to route their
  theming through the new script; at most they inherit consistency by matching
  the same `color-theme` palette they already can. Out of scope for this work.

#### Glyph capability detection + ASCII fallback (the user's key caveat)

The user wants the script to **detect when the patched (nerd) font is not
present and fall back to output without tofu**. A program cannot ask the
terminal what font it is rendering with, so "detection" here means a
**capability flag** the script consults, resolved from cheapest/most-reliable to
least, defaulting to the safe ASCII path when unknown:

1. **Explicit override** — an env var (e.g. `PROMPT_GLYPHS=1|0`) always wins, for
   manual control and for machines the user knows about.
2. **Terminal signal** — advertise nerd-font capability from the terminal the
   same way the color-theme system advertises light/dark. Two candidate
   mechanisms, mirroring existing infrastructure:
   - **wezterm-set env/user-var.** Our wezterm config knows it has the
     `Symbols Nerd Font Mono` fallback, so it can export a marker (a
     `set_environment_variables` entry, or a wezterm user var via OSC 1337 that
     tmux can surface). wezterm already sets `TERM_PROGRAM=WezTerm` /
     `WEZTERM_EXECUTABLE`, which is a coarse proxy but does **not** survive SSH
     by default.
   - **Observable-file / capability flag**, analogous to
     `$XDG_STATE_HOME/color-theme/name`: a per-machine or per-terminal
     `glyphs`-capable marker the shell reads. Simple and SSH-agnostic, but the
     user (or a setup step) has to assert it per environment.
3. **Fallback default** — when neither is set, emit the **ASCII** rendering
   (plain separators / no powerline glyphs), i.e. behaviorally close to today's
   high-viz style. Never emit glyphs speculatively.

Design implication: the script must define **two rendering vocabularies** — a
"glyph" set (nerd separators/icons) and an "ascii" set (`|`, `>`, plain blocks)
— and choose between them from the capability flag at render time. Because the
prompt re-renders each command (and tmux repaints every second via
`status-interval 1`), a flag flip takes effect immediately, just like the
light/dark flip. This is the main new piece of design work Option B adds over
the current scripts, and the one detail to nail down in the implementation plan
(which of the mechanisms in step 2 to wire, and whether the flag is per-machine
or per-terminal). Recommended starting point: **`PROMPT_GLYPHS` override +
wezterm-exported env marker, ASCII default** — smallest surface, reuses the
"terminal advertises a capability into the shell" pattern already established
for color-theme.

### Option C — Hybrid: starship prompt + convention-shared tmux/nvim/pi look (not chosen)

Take Option A's starship prompt (solves the cross-shell requirement — the
followup's headline goal), but **explicitly scope tmux to a light prettification
of the existing `tmux-theme`** rather than a plugin, and define a small shared
"design token" note (separator glyph, which `color-theme` slot maps to which
segment role) that starship's TOML, `tmux-theme`, nvim's lualine, and pi-agent
all follow by hand. No attempt to share code across renderers — just a
documented palette + glyph convention so they *look* like one system.

- Pros: gets the biggest win (one prompt, both shells) with the least risk to
  the working Tier 1/Tier 2 color pipeline; each surface keeps its native
  theming mechanism.
- Cons: consistency is convention-enforced, not code-enforced; four places to
  update if the token set changes.

## Direction (decided)

**Option B — one unified hand-rolled script** driving both shell prompts and the
tmux statusline, in the repo's bash-script idiom, keeping the exact `color-theme`
integration (so Tier 1/Tier 2 live light/dark switching stays intact). The user
chose this over starship, prioritizing zero new binary dependency and a single
in-repo source of truth that cannot drift, and accepting that we own the prompt
internals (git status, cmd duration, and — the classic footgun — bash `\[ \]` /
zsh `%{ %}` escape-width accounting for correct line wrapping).

Two things distinguish this from "just DRY up the current scripts":

1. **Nerd-font glyphs with a no-tofu ASCII fallback.** The script picks between a
   glyph vocabulary and an ASCII vocabulary from a runtime capability flag,
   defaulting to ASCII when the font's presence is unknown (see the detection
   subsection under Option B). Recommended flag resolution: `PROMPT_GLYPHS`
   override → wezterm-exported env marker → ASCII default.
2. **The font is a glyph-only fallback**, not a primary swap: keep Monaco, append
   `Symbols Nerd Font Mono` to wezterm's `font_with_fallback`, and add the nerd
   font install to a setup role (glyph-only cask such as
   `font-symbols-only-nerd-font`, or a full family if body glyphs are also
   wanted). This should land first so the rest can rely on glyphs *when the flag
   says so*.

The remaining implementation detail to pin down (not blocking the direction) is
**which capability-flag mechanism to wire** and whether it is per-machine or
per-terminal — carried into the follow-on implementation plan.

## Decisions (resolved by the user)

1. **Prompt engine → Option B**, the unified hand-rolled script (not starship).
   Caveat carried into the design: it must **detect when the patched font is
   absent and fall back to non-tofu ASCII output** (see the glyph-detection
   subsection under Option B).
2. **tmux → no plugin.** Prettify in-script (nerd separators), still
   `color-theme`-driven; do not adopt catppuccin/tmux, tmux-powerline, etc.
3. **Font → glyph-only fallback** behind Monaco in wezterm's `font_with_fallback`
   (e.g. `Symbols Nerd Font Mono` / `font-symbols-only-nerd-font`), not a primary
   font swap. Setup role gets the cask; `wezterm.lua` gets the fallback entry.
4. **Light/dark in starship → N/A** (starship not chosen). Light/dark stays as it
   is today: the one script reads the `color-theme` slots, so Tier 1/Tier 2 live
   switching is preserved unchanged.
5. **Consistency scope → consolidate into one script.** The prompt (zsh + bash)
   and the tmux statusline are emit modes of a single script — one source of
   truth, cannot drift.
6. **pi-agent / nvim → leave them be.** No re-theming through the new script;
   out of scope.

### Still to settle in the implementation plan (not blocking)

- **Which glyph-capability mechanism** to wire (the `PROMPT_GLYPHS` override is a
  given; the auto-detect signal — wezterm-exported env marker vs. an
  observable-file capability flag — and whether it is per-machine or
  per-terminal). Recommended starting point: `PROMPT_GLYPHS` override +
  wezterm-exported env marker, ASCII default.

The follow-on implementation plan can then specify the concrete roles/files: a
new `config/roles/prompt` (or similar) with the single `prompt` script + shell
fragments, the nerd-font cask in a setup role, the `wezterm.lua` fallback entry,
deletion of `config/files/tmux/tmux-theme` and `4-prompt.{zsh,bash}` (rewiring
`tmux.conf` to the new script), and the `with_items` symlink-list updates — the
classic "file exists but isn't linked" gotcha.
