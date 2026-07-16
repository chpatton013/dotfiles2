# Wezterm Fullscreen Resizing on Display Changes

## Context

Our wezterm window starts fullscreen and can be toggled fullscreen with
`Cmd+Enter` (`config/files/wezterm/wezterm.lua`): startup fullscreen is applied
in the `gui-startup` handler (`wezterm.lua:35-39`), and the toggle bind is at
`wezterm.lua:43`. Fullscreen here is wezterm's non-native borderless mode
(`macos_fullscreen_extend_behind_notch = false`, and we do **not** set
`native_macos_fullscreen_mode`, so the default `false` = borderless is in use).

The problem: connect or disconnect an external display whose resolution differs
from the built-in one, and a window that was fullscreen stays sized to the *old*
display's geometry instead of refilling the *new* screen. There is already a
standing TODO for exactly this at `wezterm.lua:41`:
"on screen resize event, for each window, if window is fullscreen,
re-fullscreen".

This is upstream-wezterm config behavior, not specific to our CSI-2031 fork
(see `docs/plans/dynamic-color-theme-propagation.md` for the fork context).

## Findings & pivot to a source fix (2026-07-16)

We prototyped the Lua `window-resized` handler below and instrumented it (file
logging to `/tmp/wezterm-fs-debug.log`). What we learned on the real machine:

- **Entering/exiting fullscreen fires `window-resized`** (two events each, ~1ms
  apart; the second is a duplicate with `changed=false`). Pixel sizes are clean
  (`3024x1964` fullscreen, `984x674` windowed); `prev_fs`/`size_changed` track
  correctly; entry does not re-toggle (no flicker). So the Lua handler's logic
  is sound.
- **Changing the built-in display resolution while fullscreen fires *nothing*.**
  No `window-resized`, and `get_dimensions()` stays `3024x1964` throughout —
  Retina "scaled resolutions" change the logical scale, not the backing pixel
  size, so there is no size delta for an event or for polling to react to.
- **But the frame *is* wrong** in that case (user-confirmed: dead space /
  clipping) — the borderless fullscreen frame goes stale even though pixels
  didn't change. So this is a real bug with no Lua-visible signal.

Root cause, from the fork source (`window/src/os/macos/window.rs`): wezterm sets
its internal `screen_changed` flag only from `windowDidChangeScreen:`
(`did_change_screen`, registered ~line 3275), which fires when a window moves to
a **different monitor**. It does **not** hook an *in-place* resolution/backing
change of the current display (no `windowDidChangeBackingProperties:` observer,
no `NSApplicationDidChangeScreenParametersNotification` observer). When
`screen_changed` is set, `draw_rect` calls `did_resize` → `WindowEvent::Resized`
→ Lua `window-resized`, and wezterm re-lays-out. So the mechanism exists; it's
just not triggered for in-place changes.

Available Lua window events are only: `bell`, `update-status`,
`window-config-reloaded`, `window-focus-changed`, `window-resized` (+
`gui-startup`/`gui-attached`). None fires for an in-place resolution change, so
this **cannot** be fixed in Lua config.

**Decision:** fix it at the source in our `csi-2031` fork — hook the missing
macOS screen-parameter/backing change and set `screen_changed`, so wezterm
re-lays-out itself (which also makes `window-resized` fire, covering both the
external-monitor and in-place cases). If that works, the Lua handler below
becomes unnecessary and should be removed.

### Plan: diagnostic build first (pessimistic)

We are not certain which macOS hook fires for an in-place scaled-resolution
change (`windowDidChangeBackingProperties:` may not fire if the backing scale
factor is unchanged; `NSApplicationDidChangeScreenParametersNotification`
reliably fires but needs an app-level observer). To avoid guessing wrong across
slow rebuilds, **build #1 is instrumentation only**: add `log::` logging to
`did_change_screen`, register + log `windowDidChangeBackingProperties:`, register
+ log an observer for `NSApplicationDidChangeScreenParametersNotification`, and
log the `screen_changed` branch in `draw_rect` and in `did_resize`. Rebuild,
reproduce (fullscreen, then change built-in resolution), and read the wezterm
log to see exactly which callback(s) fire. Build #2 wires the confirmed hook to
set `screen_changed` (the real fix) and drops the diagnostics.

This diagnostic work is done against the local build tree
(`~/.local/share/source-releases/wezterm-csi-2031`) and installed to
`~/Applications` manually; only once the fix is confirmed do we commit it to the
`csi-2031` fork branch and bump `wezterm_fork_version` in
`config/roles/wezterm/defaults/main.yml` for a clean role-driven rebuild.

## Resolution (2026-07-16): fixed in the fork

Diagnostic build confirmed on the machine: `NSApplicationDidChangeScreenParameters`
fires on every in-place resolution change (regardless of window focus);
`windowDidChangeBackingProperties:` never fires (dead end); `windowDidChangeScreen:`
fires only for monitor moves. Crucially, setting `screen_changed` alone did **not**
fix the frame — `did_resize` recomputes content, not the window frame — so an
explicit `setFrame` to the current screen is required. A first attempt that did
the re-apply in `draw_rect` worked but only after the window was refocused
(draw_rect waits for a paint); moving the re-apply into the notification handler
made it focus-independent.

**Fix** — fork `csi-2031`, commit `b51f4655`, `window/src/os/macos/window.rs`:
- Register the window view as an observer of
  `NSApplicationDidChangeScreenParametersNotification`.
- In that handler, if the window is in simple (non-native) fullscreen,
  immediately re-apply the current screen frame
  (`setFrame(NSScreen::mainScreen().frame)`) and `setNeedsDisplay` — not
  deferred to `draw_rect`, so an unfocused window doesn't keep a stale frame.
- Also re-apply on the existing `windowDidChangeScreen:` → `draw_rect` path as a
  backstop for monitor moves.

Verified: in-place resolution change now corrects the fullscreen frame without
needing to click the window. Dotfiles wired: `wezterm_fork_version` bumped to
`b51f4655`; the Lua prototype below was removed from
`config/files/wezterm/wezterm.lua`. To pick up the diagnostic-free build,
`config/config.sh --tags wezterm` re-clones the new SHA and rebuilds (the
locally-installed app already carries the fix).

Known limitation / follow-ups: uses `mainScreen` to match wezterm's existing
fullscreen-entry behavior, so a fullscreen window on a *secondary* display may
target the wrong screen (pre-existing quirk, not worsened). The external-display
connect/disconnect case should be covered (the notification + windowDidChangeScreen
backstop both fire) but was **not** verified on hardware. Consider upstreaming
the patch.

## Approach (Lua prototype — superseded by the source fix above; removed from wezterm.lua)

Wezterm exposes the pieces we need:

- **`window-resized` event** — fires when the window is resized *and* when
  transitioning between fullscreen and windowed mode. Callback signature is
  `function(window, pane)`.
- **`window:get_dimensions()`** — returns a table that includes an
  `is_full_screen` boolean, giving us a reliable "is this window fullscreen?"
  check (there is no dedicated getter; this field is the documented way).
- **`window:toggle_fullscreen()`** — the only programmatic fullscreen control
  (no `set_fullscreen(bool)` exists). "Re-fullscreen" therefore means
  toggle-off then toggle-on, which forces wezterm to recompute the borderless
  frame against the *current* active screen.

Plan: add a `window-resized` handler that, when the window reports
`is_full_screen`, re-applies fullscreen so the borderless frame is recomputed
for the screen the window now lives on. To avoid a feedback loop (each
`toggle_fullscreen` itself emits `window-resized`), guard the re-apply with a
per-window "already reconciling" flag and compare the window's current pixel
dimensions against the active screen's dimensions (`wezterm.gui.screens()`),
only re-fullscreening when they actually diverge.

The whole toggle dance only exists to work around wezterm's *non-native*
borderless fullscreen. **Disable it when `native_macos_fullscreen_mode` is
true**: native macOS fullscreen puts the window in its own Space and macOS
recomputes geometry across display changes on its own, so our re-fullscreen is
unneeded there (and toggling would fight the OS). The handler reads
`window:effective_config().native_macos_fullscreen_mode` and returns early when
it is set.

## Steps (exact `wezterm.lua` changes)

1. **Replace the TODO comment at `wezterm.lua:41`** with the handler described
   below (the comment currently reads
   `-- on screen resize event, for each window, if window is fullscreen, re-fullscreen`).

2. **Add a re-entrancy guard and helper**, placed after the `gui-startup`
   handler (~line 39). Sketch:

   ```lua
   -- Guard so our own toggle_fullscreen() calls (which re-emit
   -- window-resized) don't recurse.
   local reconciling = {}

   local function screen_pixel_size_for_window(window)
       -- wezterm.gui.screens() reports the active/attached screens with
       -- pixel geometry; pick the one the window is on (fall back to active).
       local ok, screens = pcall(function() return wezterm.gui.screens() end)
       if not ok or not screens then return nil end
       local s = screens.active or screens.main
       if not s then return nil end
       return s.width, s.height
   end

   wezterm.on("window-resized", function(window, pane)
       -- Native macOS fullscreen (Spaces) handles display changes itself, so
       -- our re-fullscreen dance is unneeded (and would fight the OS). Bail.
       if window:effective_config().native_macos_fullscreen_mode then
           return
       end
       local dims = window:get_dimensions()
       if not dims.is_full_screen then
           return
       end
       local win_id = window:window_id()
       if reconciling[win_id] then
           reconciling[win_id] = nil
           return
       end
       local sw, sh = screen_pixel_size_for_window(window)
       if not sw then return end
       -- Only act if the fullscreen window no longer matches the screen it
       -- is on (i.e. the display changed underneath it).
       if dims.pixel_width == sw and dims.pixel_height == sh then
           return
       end
       reconciling[win_id] = true
       -- Re-fullscreen: exit then re-enter so wezterm recomputes the
       -- borderless frame for the current screen.
       window:toggle_fullscreen()   -- -> windowed
       window:toggle_fullscreen()   -- -> fullscreen, refilled
   end)
   ```

   Notes on the sketch (finalize during implementation against the installed
   wezterm's actual API):
   - Confirm the exact shape of `wezterm.gui.screens()` return (fields
     `active`, `main`, `by_name`, and per-screen `width`/`height`) on the
     installed build; adjust `screen_pixel_size_for_window` accordingly. If the
     screen-size comparison proves unreliable, fall back to unconditionally
     re-fullscreening on every `window-resized` where `is_full_screen` is true,
     relying solely on the `reconciling` guard to stop recursion.
   - `window:window_id()` keys the guard per window so multiple windows are
     handled independently (the TODO says "for each window").
   - Two `toggle_fullscreen()` calls in one handler invocation is the
     "re-fullscreen". Each emits its own `window-resized`; the guard swallows
     the pair (set on entry to the reconcile, cleared on the next event).

3. **Leave `gui-startup` and the `Cmd+Enter` bind unchanged** — this only adds
   an event handler; startup fullscreen and manual toggle keep working.

4. Since this edits a file already symlinked under
   `~/.config/dotfiles/wezterm/` (per `AGENTS.md`, files under `config/files/`
   take effect immediately), no `config/config.sh` re-run is required — new
   wezterm windows / a config reload pick it up. Existing windows reload config
   automatically if `automatically_reload_config` is on (default), otherwise
   `ReloadConfiguration` (or restart) applies it.

## Verification

There is no automated test path (per `AGENTS.md`, verification = observe on a
real machine), and this specifically **cannot be tested headless** — it needs
an interactive GUI wezterm plus a real external display of a *different*
resolution. Manual procedure:

1. Launch our wezterm (`~/Applications/WezTerm.app`) fullscreen on the built-in
   display.
2. Connect an external display of a different resolution (or change the
   built-in scaled resolution in System Settings > Displays), moving the
   fullscreen window to it / making it the active screen.
3. Confirm the fullscreen window refills the new screen with no dead border and
   no clipping. Repeat on disconnect (window should refill the built-in
   display).
4. Sanity-check no visible flicker/loop: the exit+re-enter toggle should be a
   single quick reconcile, not a repeating flash (confirms the `reconciling`
   guard works).
5. Confirm `Cmd+Enter` toggle and startup fullscreen still behave normally.

## Risks / open questions

- **The event may not fire on a display change.** `window-resized` is
  documented to fire on resize and on fullscreen<->windowed transitions. If
  macOS keeps the borderless window at its *old* pixel size when the display
  changes (which is precisely the bug), then **no resize occurs and the handler
  never runs** — the core risk. Mitigations to evaluate during implementation:
  - Also hook `window-config-reloaded` (fires on config reload / overrides) as
    a secondary trigger — weak, since a display change alone won't reload
    config.
  - **Polling fallback**: a `wezterm.time.call_after` loop (e.g. every 1-2s)
    that walks `wezterm.mux.all_windows()`, and for each fullscreen window whose
    `get_dimensions()` disagrees with its screen size, re-fullscreens. Costlier
    and slightly hacky but robust if no event fires. Decide event-only vs.
    event+poll after step-2 testing.
- **No `set_fullscreen(bool)` API** — only `toggle_fullscreen()`, so re-apply is
  a two-toggle dance. If wezterm ever mis-tracks state, the double toggle could
  leave the window windowed; the `is_full_screen` check before acting limits
  exposure, but worth watching.
- **Recursion / flicker.** `toggle_fullscreen()` re-emits `window-resized`; the
  `reconciling` guard is essential. If the guard logic is wrong we get an
  infinite toggle loop — verify carefully (step 4).
- **`wezterm.gui.screens()` shape / multi-monitor ambiguity.** Mapping a window
  to "its" screen is imprecise via the current API; the active-screen fallback
  may pick the wrong monitor in a multi-display setup. The unconditional
  re-fullscreen fallback (guarded only against recursion) sidesteps this at the
  cost of an extra toggle on benign resizes.
- **Known upstream fullscreen bugs.** wezterm issues #6275 and #4665 describe
  fullscreen windows displacing/resizing on focus loss/regain; our handler
  could interact with those. Watch for it re-triggering on focus changes; if so,
  gate on an actual screen-size mismatch (as sketched) rather than firing on
  every resize.
- **Native vs. borderless fullscreen.** This targets the default borderless
  mode we use. The handler explicitly disables itself when
  `native_macos_fullscreen_mode` is enabled (macOS Spaces own the geometry and
  handle display changes), via the early
  `window:effective_config().native_macos_fullscreen_mode` check — so switching
  to native mode is safe and simply turns this workaround off. Confirm
  `effective_config()` exposes that field on the installed build during
  implementation.
