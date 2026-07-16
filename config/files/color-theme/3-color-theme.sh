# Refresh the cached theme by querying the terminal (interactive shells only),
# then export the theme environment for downstream consumers.
if [ -t 1 ]; then
  color-theme-detect >/dev/null 2>&1 || true
fi

eval "$(color-theme shell)"

# Drive git-delta from the same source of truth as the prompt and tmux. The
# matching `[delta "theme-light"]` / `[delta "theme-dark"]` features live in the
# git ui config fragment.
export DELTA_FEATURES="theme-${COLOR_THEME_NAME}"

# Re-query the terminal and re-export the theme in the current shell. Useful as
# a manual fallback until the mode-2031 push chain is fully trusted (and on
# terminals that cannot push at all).
function color-theme-refresh() {
  color-theme-detect >/dev/null 2>&1 || true
  eval "$(color-theme shell)"
  export DELTA_FEATURES="theme-${COLOR_THEME_NAME}"
}
