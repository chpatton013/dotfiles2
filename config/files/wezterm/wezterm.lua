local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.audible_bell = "Disabled"
config.hide_tab_bar_if_only_one_tab = true
config.macos_fullscreen_extend_behind_notch = false
config.font_size = 10
config.font = wezterm.font_with_fallback({
    {family = "Monaco"},
})
-- Whitespace, braces, quotes, and some punctuation.
config.selection_word_boundary = " \t\n{}[]()\"'`<>#=;:,|│┆"

local function get_appearance()
    -- wezterm.gui is not available to the mux server, so take care to
    -- do something reasonable when this config is evaluated by the mux
    if wezterm.gui then
        return wezterm.gui.get_appearance()
    end
    return "Dark"
end

local function scheme_for_appearance(appearance)
    if appearance:find("Dark") then
        return "Solarized Dark (Gogh)"
    else
        return "Solarized Light (Gogh)"
    end
end

-- Initial value only. This is resolved once at config-eval time, and the GUI's
-- get_appearance() can be stale/wrong at that moment (a new window would then
-- come up in the wrong scheme until an appearance toggle forced a reload). The
-- window-config-reloaded handler below re-resolves per window against that
-- window's own appearance, which is the authoritative fix.
config.color_scheme = scheme_for_appearance(get_appearance())

-- Resolve the scheme dynamically for each window, using the window's own
-- reported appearance rather than the value baked into config at eval time.
-- Fires on window creation and on every config reload (including the reload
-- macOS triggers when system appearance changes), so each window always picks
-- the correct light/dark scheme at creation instead of inheriting a stale one.
wezterm.on("window-config-reloaded", function(window, _pane)
    local overrides = window:get_config_overrides() or {}
    local scheme = scheme_for_appearance(window:get_appearance())
    if overrides.color_scheme ~= scheme then
        overrides.color_scheme = scheme
        window:set_config_overrides(overrides)
    end
end)

local mux = wezterm.mux

wezterm.on("gui-startup", function()
    -- Skip tab and pane return values
    local window = select(3, mux.spawn_window({}))
    window:gui_window():toggle_fullscreen()
end)

-- Note: keeping a non-native fullscreen window filling its screen across
-- display/resolution changes is handled in our wezterm fork (the csi-2031
-- branch built by config/roles/wezterm), not here. macOS surfaces no Lua event
-- for an in-place resolution change, so the fix lives in the app's
-- NSApplicationDidChangeScreenParameters handler.

config.keys = {
    -- Cmd+Enter to toggle fullscreen
    {key = "Enter", mods = "CMD", action = wezterm.action.ToggleFullScreen},
}
config.mouse_bindings = {
    -- Alt+Cmd+Left to block-select
    {
        event = {Down = {streak = 1, button = "Left"}},
        mods = "ALT|CMD",
        action = wezterm.action.SelectTextAtMouseCursor("Block"),
    },
    {
        event = {Drag = {streak = 1, button = "Left"}},
        mods = "ALT|CMD",
        action = wezterm.action.ExtendSelectionToMouseCursor("Block"),
    },
    {
        event = {Up = {streak = 1, button = "Left"}},
        mods = "ALT|CMD",
        action = wezterm.action.CompleteSelection("ClipboardAndPrimarySelection"),
    },
}

return config
