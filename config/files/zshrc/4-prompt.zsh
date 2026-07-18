# Prompt drawn by the unified `prompt` script (config/files/prompt/prompt),
# which also renders the bash prompt and the tmux statusline so all three stay
# visually consistent. Re-rendered every command via a precmd hook so the
# prompt follows light/dark changes (the color-theme system is the source of
# truth). Colors and glyph-vs-ASCII selection are handled inside the script.
setopt PROMPT_SUBST

function _prompt_precmd() {
  PS1="$(prompt zsh)"
}

precmd_functions+=(_prompt_precmd)
_prompt_precmd
