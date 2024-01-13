function prompt_segment() {
  local bg="48;5;${1}"
  local fg="38;5;${2}"
  shift 2
  echo -n "\[\e[${fg};${bg}m\] $@ \[\e[0m"
}

function build_prompt() {
  local last_exit_status="$1"

  # Username
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "\u"
  # Hostname up to the first .
  prompt_segment "$COLOR_THEME_HIGHLIGHT_BG" "$COLOR_THEME_HIGHLIGHT_FG" "\h"
  # TTY without /dev/ prefix
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "\l"
  # Date yy/mm/dd
  prompt_segment "$COLOR_THEME_HIGHLIGHT_BG" "$COLOR_THEME_HIGHLIGHT_FG" "\D{%Y/%m/%d}"
  # Time hh:mm:ss
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "\D{%H:%M:%S}"

  echo

  # Return status of the last command
  prompt_segment "$COLOR_THEME_ACTIVE_BG" "$COLOR_THEME_ACTIVE_FG" "$last_exit_status"
  # Basename of $SHELL
  prompt_segment "$COLOR_THEME_HIGHLIGHT_BG" "$COLOR_THEME_HIGHLIGHT_FG" "\s"
  # cwd, with $HOME replaced by ~
  prompt_segment "$COLOR_THEME_ACTIVE_BG" "$COLOR_THEME_ACTIVE_FG" "\w"

  echo

  # Privileged (#) or unprivileged (%) user
  prompt_segment "$COLOR_THEME_INVERT_BG" "$COLOR_THEME_INVERT_FG" "\$"
}

function __prompt_command() {
  local last_exit_status="$?"
  PS1="$(build_prompt "$last_exit_status") "
}

PROMPT_COMMAND=__prompt_command
