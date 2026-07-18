# Prompt drawn by the unified `dotfiles-prompt` script
# (config/files/prompt/dotfiles-prompt), which also renders the bash prompt and
# the tmux statusline so all three stay visually consistent. Re-rendered every
# command via a precmd hook so the prompt follows light/dark changes (the
# color-theme system is the source of truth). Named `dotfiles-prompt` rather
# than `prompt` to avoid colliding with zsh's promptinit `prompt` function.
# Falls back to a plain PS1 if the script isn't on PATH yet (e.g. before
# `config/config.sh --tags prompt` has linked it).
setopt PROMPT_SUBST

function _prompt_precmd() {
  # Re-read the cached appearance from the state file each command (cheap, no
  # terminal query) so a live light/dark switch published there -- e.g. by
  # tmux's mode-2031 client-*-theme hook running color-theme-set -- reaches the
  # prompt colors and delta within one prompt. COLOR_THEME_NAME is sticky once
  # exported (color-theme honors a pre-set value), so clear it to force the
  # state-file read; color-theme-detect (the tty OSC 11 query) is NOT run here.
  if command -v color-theme >/dev/null 2>&1; then
    eval "$(COLOR_THEME_NAME= command color-theme shell 2>/dev/null)" 2>/dev/null || true
    export DELTA_FEATURES="theme-${COLOR_THEME_NAME:-dark}"
  fi
  local rendered
  if rendered="$(command dotfiles-prompt zsh 2>/dev/null)"; then
    PS1="$rendered"
  else
    PS1='%n@%m %1~ %# '
  fi
}

precmd_functions+=(_prompt_precmd)
_prompt_precmd
