# Prompt drawn by the unified `dotfiles-prompt` script
# (config/files/prompt/dotfiles-prompt), which also renders the zsh prompt and
# the tmux statusline so all three stay visually consistent. Rebuilt every
# command via PROMPT_COMMAND (which also captures the last exit status) so the
# prompt follows light/dark changes (the color-theme system is the source of
# truth). Named `dotfiles-prompt` (not `prompt`) for parity with the zsh side,
# where `prompt` collides with zsh's promptinit. Falls back to a plain PS1 if
# the script isn't on PATH yet (before `config/config.sh --tags prompt`).
function __prompt_command() {
  local last_exit_status="$?"
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
  if rendered="$(command dotfiles-prompt bash "$last_exit_status" 2>/dev/null)"; then
    PS1="$rendered"
  else
    PS1='\u@\h \w \$ '
  fi
}

PROMPT_COMMAND=__prompt_command
