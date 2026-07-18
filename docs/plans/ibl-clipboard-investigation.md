# IBL indent glyphs landing in the clipboard on mouse-select

Investigation only. Follow-up: `docs/followups.md` ("Fix IBL indent-guide
characters landing in the clipboard on mouse-select in nvim").

## Bottom line

Yes, it is possible to stop IBL glyphs from being copied — but every clean fix
trades something away. The single root cause is that **the mouse is disabled in
nvim** (`init.lua:1233` `vim.opt.mouse = ""`), so mouse selection is handled by
the *terminal*, which copies rendered screen cells, not buffer text.

There is **no IBL/terminal setting** that makes rendered virtual-text glyphs
non-selectable, because the terminal has no concept of "virtual text" — it only
sees a grid of drawn characters. So any real fix is one of:

1. Route selection through nvim (`mouse=a` + buffer yank) — compromise: gives up
   terminal-native selection inside the nvim pane.
2. Make indent guides background-only (no glyph) — compromise: visual redesign,
   lose the vertical-bar look.
3. Drop the guides — compromise: lose the feature.

## Why the glyphs get captured (mechanism)

- IBL draws its guides (`indent.char = "▏"`, `scope.char = "▎"`,
  `init.lua:1044/1049`) as **virtual text**: box-drawing glyphs painted into the
  otherwise-blank leading-indent columns. They are *not* buffer content — the
  buffer there is spaces (or nothing).
- `vim.opt.mouse = ""` means nvim ignores the mouse. A left-drag is therefore a
  **terminal selection** (wezterm; default left-drag isn't rebound — only the
  `ALT|CMD` block-select is custom, `wezterm.lua:70-87`). tmux sits in the chain
  too but the model is the same.
- The terminal copies **what is rendered on the screen cells** it drags over.
  The IBL glyphs occupy real cells, so they are copied verbatim, embedded inside
  the indentation. The same would be true of any other rendered-but-non-buffer
  UI (sign column, `listchars`, `fillchars` `┆`, fold column, etc.).
- Note: the existing `ModeChanged` IBL toggle (`init.lua:1062-1076`) exists for a
  *different* reason — "the IBL highlight group overrides the visual selection
  highlight group" (a coloring issue). It does **not** help the mouse-clipboard
  case: a terminal drag never puts nvim into visual mode, so the autocmd never
  fires while you drag. (Previously the user worked around the clipboard issue by
  manually entering visual mode before a terminal select; Option A makes that
  manual dance unnecessary — see "Implemented" below.)

## Options and compromises

### Option A — `mouse=a` + buffer-based visual selection/yank (cleanest fix)

Set `vim.opt.mouse = "a"`. A mouse drag then becomes an nvim **visual
selection** addressed by buffer row/column; yanking it copies real buffer text
only — no virtual text. This genuinely fixes the glyph problem.

Also needed for it to actually reach the OS clipboard: nvim currently sets **no**
`clipboard` option, so a mouse-drag selection would land only in nvim's unnamed
register, not the system clipboard the way the terminal did. You'd add
`set clipboard=unnamedplus` (plus a working provider: `pbcopy` on macOS, or OSC52
for remote), and likely an autocmd to yank-on-mouse-release so a drag copies
without an extra keystroke.

Compromises:
- **Loses terminal-native selection inside the nvim pane.** You can no longer
  drag-select across the whole terminal grid (e.g. nvim text plus surrounding
  chrome, or spanning UI columns). It's demoted to "hold Shift to bypass app
  mouse reporting" (wezterm/iTerm honor Shift-drag) or the custom `ALT|CMD`
  block-select.
- **Click-to-position now works** (click moves the cursor) — a behavior change,
  arguably a feature, but new muscle memory; scroll-wheel scrolls the buffer,
  drag can resize splits, etc. All mouse events are now nvim's.
- Adds clipboard-provider plumbing (`unnamedplus` + provider + release autocmd) —
  more moving parts, and OSC52/pbcopy must be healthy for it to work over SSH.
- The existing `ModeChanged` toggle becomes the thing that actually matters here
  (IBL should be off during the drag so the visual highlight reads correctly);
  it's already present, so this composes.

### Option B — IBL config toggles alone (insufficient)

- **Visual-mode toggle (current `ModeChanged` approach):** only fires when nvim
  enters visual mode, which a terminal drag never does. So on its own it does
  nothing for the mouse-clipboard case. It only becomes relevant *combined with*
  Option A — at which point Option A has already solved the copy problem.
- **Change `indent`/`scope` char to a space:** the captured text becomes
  whitespace instead of box glyphs, but you've deleted the indent guides
  entirely (defeats IBL) and you'd still copy those columns as spaces.
- There is **no** IBL option to exempt its virtual text from terminal selection;
  the terminal is downstream of nvim's rendering and has no such signal.

### Option C — terminal-side selection modes (can't solve it)

wezterm copies exactly what it renders; it has no way to know which cells are
nvim virtual text. Block/rectangular and semantic-zone selection don't help.
Trailing-whitespace-on-copy stripping doesn't help either, because the glyphs are
non-space characters embedded *inside* the indentation, not trailing. No clean
terminal-only fix exists.

### Option D — background-color indent guides (full investigation)

This is the alternative the user asked to have investigated alongside Option A.
The idea: stop drawing a glyph for the guide and instead **color the background**
of the real leading-indent cells. Those cells contain actual buffer characters
(the leading spaces), so a terminal mouse-drag copies plain indentation — never a
box glyph — and terminal-native selection can stay enabled. It is the *only*
approach that removes the spurious glyphs **without** taking the mouse away from
the terminal.

**Feasibility: yes**, with caveats about the exact look (below). Three ways to
build it:

1. **IBL with space chars + whitespace highlight (least new machinery).**
   Keep IBL but neutralize its virtual text:
   ```lua
   require("ibl").setup({
       indent = { char = " ", highlight = { "CustomIblOdd", "CustomIblEven" } },
       whitespace = { highlight = { "CustomIblOdd", "CustomIblEven" },
                      remove_blankline_trail = false },
       scope = { enabled = false }, -- or char = " " with a bg-only CustomIblScope
   })
   ```
   IBL still emits a virtual char, but a **space** is visually identical to the
   underlying buffer space, so the selection copies a space either way — the
   captured text is clean. The alternating `CustomIblOdd/Even` **background**
   colors produce vertical column stripes. Simplest migration: reuses the
   existing theme-aware `CustomIblOdd/Even` groups verbatim.
   - Caveat: on **blank lines** and past end-of-line there is no real buffer cell
     to color; IBL paints virtual whitespace there. With a space char that
     virtual whitespace is invisible but is still virtual text, so a selection
     dragged across a blank line's indent can still pick up virtual spaces (they
     copy as spaces — harmless, but they are trailing whitespace). `listchars
     trail` / an editorconfig trim on save mitigates.

2. **Pure highlight on real cells, no plugin (`:highlight` + `matchadd`/extmarks).**
   Drop IBL entirely and background-highlight leading-whitespace columns yourself
   (e.g. `vim.fn.matchadd` on a leading-indent pattern, or per-line extmarks with
   `hl_group` over the indent range). This guarantees only **real** cells are
   colored, so nothing virtual can ever land in the clipboard, and terminal
   selection is fully clean including blank lines. Cost: you reimplement
   indent-width/scope detection that IBL gives for free (treesitter/`shiftwidth`
   math, redraw on edits) — meaningfully more code to maintain.

3. **A background-oriented plugin (e.g. `hlchunk.nvim` indent module, or
   `mini.indentscope` for scope only).** Middle ground; still a dependency swap.

**How it looks vs. the vertical bars.** The current setup draws a thin 1/8-block
bar (`▏`) in a muted color at each indent level plus a heavier 1/4-block (`▎`) on
the active scope — a crisp, low-noise vertical line precisely one column wide.
Background striping instead tints the **whole indent column block** (typically the
full `shiftwidth`), alternating two backgrounds. It reads as wider vertical bands
rather than hairlines: more visually present, less precise about *where* the
indent stop is, and scope emphasis becomes "a differently-tinted band" instead of
a bolder line. On Solarized the effect is subtle (base03/base04 dark, base3/base4
light), but it is unavoidably a heavier, blockier look than the bars.

**The theme-switch problem the user hit** was that the background groups didn't
re-color on a dark/light switch. That is already solved in the current config and
carries over to Option D unchanged: `CustomIblOdd/Even` are computed from the
solarized palette keyed off `vim.o.background` inside the `HIGHLIGHT_SETUP` hook,
which IBL re-runs on every `ColorScheme` event, so the stripes re-derive on each
switch. (Approach 2/3 would need the same: put the `nvim_set_hl` calls in a
`ColorScheme` autocmd. Live OS→running-nvim propagation is a separate concern —
see `docs/plans/dynamic-color-theme-propagation.md`.)

**Tradeoffs vs. Option A (the chosen route).**

| | Option A (`mouse=a` + buffer yank) | Option D (background-only guides) |
|---|---|---|
| Glyphs in clipboard | Eliminated (yank copies buffer text) | Eliminated (only real cells colored) |
| Terminal-native drag | Given up inside nvim (Shift-drag to regain) | **Kept** — the point of D |
| Mouse ownership | nvim owns click/drag/scroll | terminal keeps the mouse; nvim `mouse` unchanged |
| Clipboard plumbing | needs a provider (pbcopy/xclip/OSC52) | none — terminal copies as before |
| Visual result | keeps the crisp `▏`/`▎` bars | heavier column-background stripes |
| SSH/headless | depends on OSC52 working | unaffected (terminal-side copy) |
| Complexity | small, self-contained | approach 1 small; 2/3 more code |
| Blank-line edge | n/a (yank is buffer-accurate) | virtual whitespace on blank lines (harmless spaces) |

**Bottom line:** Option D is a legitimate, lower-plumbing alternative whose whole
appeal is preserving terminal-native selection; its cost is a blockier visual
style and (for the cleanest variant) hand-rolled indent highlighting. The user
chose Option A to keep the vertical bars — Option D remains the fallback if the
loss of terminal-native drag inside nvim proves annoying.

- **`listchars`/built-in leading-indent rendering:** also drawn as screen cells
  (virtual), so it has the identical glyph-capture problem — no improvement.
- **Remove indent guides entirely:** solves it, loses the feature.

## Recommendation framing (for the user to decide)

- Want the vertical-bar guides *and* the fix, and OK giving up terminal-native
  drag inside nvim → **Option A**.
- Want to keep terminal-native drag → **Option D (background-only guides)**,
  accepting the visual restyle.
- Everything else (IBL toggles, terminal settings, char swaps) cannot fix the
  terminal-selection case on its own.

Relevant code: `config/files/neovim/init.lua` — IBL setup, `ibl_highlight_groups`,
visual-mode `ModeChanged` toggle, `vim.opt.mouse`, `listchars`/`fillchars`;
`config/files/wezterm/wezterm.lua` mouse bindings.

## Implemented (Option A)

Decision: **Option A**, keeping the vertical-bar guides *and* the theme-aware
background stripes (both already present in the IBL setup — no change needed
there).

Changes in `config/files/neovim/init.lua`, "Input behavior" section (surgical):

1. `vim.opt.mouse = ""` → `vim.opt.mouse = "a"`. The mouse now drives nvim's
   buffer-based visual mode, so a drag-selection addresses buffer rows/columns
   and never captures IBL virtual-text glyphs.
2. Added `vim.opt.clipboard = "unnamedplus"` so yanks (including the mouse
   selection) reach the system clipboard, which `mouse=""` + terminal-native
   selection used to handle.
3. Added a visual-mode mapping so releasing a drag copies to the clipboard
   automatically, mirroring the terminal's select-to-copy. A plain click never
   enters visual mode, so it only fires on a real drag. Now mapped for **both**
   `<LeftRelease>` (charwise/linewise drags) **and** `<A-LeftRelease>` (blockwise
   drags — see "Block-select fix" below).

Added a Linux clipboard provider path (setup roles) and an OSC 52 provider for
SSH/headless sessions — see "Linux clipboard provider" below.

Not changed (already satisfies the request):
- Vertical bars: `indent.char = "▏"`, `scope.char = "▎"`.
- Theme-aware background stripes: `CustomIblOdd/Even` derive from the solarized
  palette by `vim.o.background` and are re-applied by the `HIGHLIGHT_SETUP` hook
  on every colorscheme change.
- The `ModeChanged` IBL toggle stays — it serves its original purpose (the IBL
  highlight otherwise overrides the visual-selection highlight color), and it
  composes with `mouse=a` (a mouse drag enters visual mode and disables IBL for
  the duration).

Compromises accepted (per Option A): terminal-native drag inside the nvim pane is
now demoted to Shift-drag (or the wezterm `ALT|CMD` block-select); the clipboard
now depends on a working provider (pbcopy locally, OSC52 over SSH); auto-yank on
release exits visual mode, so drag-then-operate is not available (drag is
copy-oriented).

### Block-select fix

Symptom: the `<LeftRelease>` mapping fired for a normal (charwise) mouse
line-select but **not** for a mouse block-select.

Cause: nvim makes a **blockwise** mouse selection with the **Alt** modifier —
`<A-LeftMouse>`/`<A-LeftDrag>`/`<A-LeftRelease>` (nvim docs, `gui.txt`:
"`<A-LeftMouse>` … start/extend blockw[ise]"). So an Alt-drag block selection
ends with an **`<A-LeftRelease>`** event, which the plain `<LeftRelease>` mapping
never matches. (The `x` mode is not the problem — `x` already covers charwise,
linewise, and blockwise visual; the missing piece was the modified release
event.)

Fix: map both release events to the same yank. Replaces the single mapping:
```lua
for _, lhs in ipairs({ "<LeftRelease>", "<A-LeftRelease>" }) do
    vim.keymap.set("x", lhs, '"+y', {
        desc = "Copy mouse selection to the clipboard on release",
    })
end
```
Note: `config/files/wezterm/wezterm.lua` binds `ALT|CMD`+drag to a *terminal*
block-select (`SelectTextAtMouseCursor("Block")`), which bypasses nvim entirely
and would still capture glyphs; a plain **Alt**-drag passes through to nvim and is
what the `<A-LeftRelease>` mapping handles. If the user routinely uses `ALT|CMD`
for block-copy inside nvim, that wezterm binding should be reconsidered (out of
scope here; noted for follow-up).

### Interaction with the "no IBL in visual mode" toggle

Setup: the `ModeChanged` autocmds run `IBLDisable` on entering any visual mode and
`IBLEnable` on leaving it. With `mouse=a`, a mouse drag **enters visual mode**, so
IBL's guides stop rendering *during* the selection. This makes it ambiguous from
the outside whether clean clipboard content is due to (a) the buffer-based yank or
(b) the guides being toggled off mid-drag.

Analysis — **the fix is robust independent of the toggle.** The reason glyphs are
excluded is that `"+y` yanks a **visual selection addressed by buffer position**;
IBL guides are **virtual text** with no buffer position, so they are *never* part
of a register yank, whether or not they are currently drawn on screen. The toggle
only changes what is *painted*, not what is *in the buffer*. So even if IBL stayed
enabled throughout the drag, the yank would still copy only real buffer text. The
toggle is therefore **not load-bearing** for the clipboard fix.

Why the toggle still exists: its original, independent purpose is that the IBL
highlight group otherwise overrides the Visual selection highlight color (a
cosmetic issue) — unrelated to the clipboard. It composes fine with `mouse=a`.

Advice: **no change to the toggle is required.** Keep it for its cosmetic purpose.
To *verify* that the buffer-yank alone excludes glyphs (rather than the toggle
masking the problem), temporarily disable the toggle (`:IBLEnable` won't stick
while the autocmds run — comment out the `visual_ibl_group` autocmds or
`:autocmd! visual_ibl_group`), keep IBL visibly on, drag-select across indented
lines, and confirm the clipboard still has no `▏`/`▎`. (Expected: clean.)

### Linux clipboard provider

`clipboard=unnamedplus` needs an external provider on Linux (macOS has built-in
`pbcopy`/`pbpaste`). Two layers:

Setup change (Ansible; installs the tool on the box):
- `setup-ubuntu/roles/user-tools/tasks/main.yml` — already installed `xclip`;
  added `wl-clipboard` (Wayland `wl-copy`/`wl-paste`).
- `setup-archlinux/roles/user-tools/tasks/main.yml` — added `xclip` and
  `wl-clipboard` (arch had neither).
- nvim auto-detects a provider in priority order (wl-copy → xclip → xsel → …), so
  installing these is all that is needed for a local X/Wayland session. `xsel` was
  not added since `xclip` already covers X11; add it only if a tool insists on it.

init.lua change (SSH/headless, no X/Wayland tool):
- On a headless host reached over SSH there is no display server, so the above
  tools have nothing to talk to. Added an **OSC 52** provider, gated on
  `SSH_TTY`/`SSH_CONNECTION`, that makes the terminal emulator itself perform the
  copy over the wire:
  ```lua
  if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
      local osc52 = safe_require("vim.ui.clipboard.osc52")
      if osc52 then
          vim.g.clipboard = {
              name = "OSC 52",
              copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
              paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
          }
      end
  end
  ```
  `vim.ui.clipboard.osc52` is built into nvim ≥ 0.10 (no plugin). It is gated on
  SSH so local macOS/Linux sessions keep their native provider. Requires the
  terminal (wezterm) and any intermediary (tmux) to permit OSC 52 clipboard
  writes; OSC 52 *paste* is often unsupported by terminals and falls back to the
  last copied text, which is acceptable.

### Needs interactive verification (cannot be checked headlessly)

- A charwise mouse drag and an **Alt** (blockwise) mouse drag both leave the
  selected buffer text in the system clipboard with **no** `▏`/`▎` glyphs and no
  gutter/sign content.
- With the `ModeChanged` toggle temporarily disabled and IBL visibly on, a
  drag-select still yields glyph-free clipboard content (confirms the yank, not
  the toggle, is what excludes glyphs).
- `clipboard=unnamedplus` reaches the OS clipboard locally: pbcopy on macOS;
  `wl-copy`/`xclip` on a Linux desktop session after the setup role runs.
- Over SSH to the headless box, the OSC 52 provider copies through
  wezterm (and tmux, if `set -g allow-passthrough`/`set-clipboard on`); confirm
  `:echo has('clipboard')`/`:checkhealth` and an actual copy round-trip.
- Single click still just positions the cursor without clobbering the clipboard.
- The `ModeChanged` toggle + `mouse=a` don't fight (no flicker/redraw issues)
  during a drag.
