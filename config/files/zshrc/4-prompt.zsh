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
  local rendered
  if rendered="$(command dotfiles-prompt zsh 2>/dev/null)"; then
    PS1="$rendered"
  else
    PS1='%n@%m %1~ %# '
  fi
}

precmd_functions+=(_prompt_precmd)
_prompt_precmd
