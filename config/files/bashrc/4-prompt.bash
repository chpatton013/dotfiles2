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
  local rendered
  if rendered="$(command dotfiles-prompt bash "$last_exit_status" 2>/dev/null)"; then
    PS1="$rendered"
  else
    PS1='\u@\h \w \$ '
  fi
}

PROMPT_COMMAND=__prompt_command
