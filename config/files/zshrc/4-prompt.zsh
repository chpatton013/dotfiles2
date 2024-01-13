function prompt_segment() {
  local bg="%K{$1}"
  local fg="%F{$2}"
  shift 2
  echo -n "%{$bg%}%{$fg%} $@ %{%k%}%{%f%}"
}

function build_prompt() {
  # Username
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "%n"
  # Hostname up to the first .
  prompt_segment "$COLOR_THEME_HIGHLIGHT_BG" "$COLOR_THEME_HIGHLIGHT_FG" "%m"
  # TTY without /dev/ prefix
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "%y"
  # Date yy/mm/dd
  prompt_segment "$COLOR_THEME_HIGHLIGHT_BG" "$COLOR_THEME_HIGHLIGHT_FG" "%D{%Y/%m/%d}"
  # Time hh:mm:ss
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "%D{%H:%M:%S}"

  echo

  # Return status of the last command
  prompt_segment "$COLOR_THEME_ACTIVE_BG" "$COLOR_THEME_ACTIVE_FG" "%?"
  # Basename of $SHELL
  prompt_segment "$COLOR_THEME_HIGHLIGHT_BG" "$COLOR_THEME_HIGHLIGHT_FG" '$(basename $SHELL)'
  # cwd, with $HOME replaced by ~
  prompt_segment "$COLOR_THEME_ACTIVE_BG" "$COLOR_THEME_ACTIVE_FG" "%~"

  echo

  # Privileged (#) or unprivileged (%) user
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "%#"
}

setopt PROMPT_SUBST
export PS1="%{%f%b%k%}$(build_prompt) "
