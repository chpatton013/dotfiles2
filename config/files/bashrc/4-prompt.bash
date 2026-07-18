# Prompt drawn by the unified `prompt` script (config/files/prompt/prompt),
# which also renders the zsh prompt and the tmux statusline so all three stay
# visually consistent. Rebuilt every command via PROMPT_COMMAND (which also
# captures the last exit status) so the prompt follows light/dark changes (the
# color-theme system is the source of truth). Colors and glyph-vs-ASCII
# selection are handled inside the script.
function __prompt_command() {
  local last_exit_status="$?"
  PS1="$(prompt bash "$last_exit_status")"
}

PROMPT_COMMAND=__prompt_command
