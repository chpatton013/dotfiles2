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
config.selection_word_boundary = " \t\n{}[]()\"'`;:"

function get_appearance()
    -- wezterm.gui is not available to the mux server, so take care to
    -- do something reasonable when this config is evaluated by the mux
    if wezterm.gui then
        return wezterm.gui.get_appearance()
    end
    return "Light"
end

function scheme_for_appearance(appearance)
    if appearance:find("Dark") then
        return "Solarized Dark (Gogh)"
    else
        return "Solarized Light (Gogh)"
    end
end

config.color_scheme = scheme_for_appearance(get_appearance())

local mux = wezterm.mux

wezterm.on("gui-startup", function()
    local _tab, _pane, window = mux.spawn_window{}
    window:gui_window():toggle_fullscreen()
end)

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
