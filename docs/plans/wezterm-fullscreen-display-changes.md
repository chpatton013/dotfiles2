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
(see `docs/plans/dynamic-color-theme-propagation.md` for the fork context); the
handler added here should work on either build.

## Approach

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
  mode we use. If `native_macos_fullscreen_mode` is ever enabled, macOS Spaces
  own the geometry and this handler's toggle approach would need reevaluation.
