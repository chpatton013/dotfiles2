function build_ps1() {
  local fg_black=$'\[\e[0;30m\]'
  local fg_red=$'\[\e[0;31m\]'
  local fg_green=$'\[\e[0;32m\]'
  local fg_yellow=$'\[\e[0;33m\]'
  local fg_blue=$'\[\e[0;34m\]'
  local fg_magenta=$'\[\e[0;35m\]'
  local fg_cyan=$'\[\e[0;36m\]'
  local fg_white=$'\[\e[0;37m\]'
  local reset_color=$'\[\e[0m\]'

  local ps1_user=$'\u'
  local ps1_host=$'\H'
  local ps1_pwd=$'\w'
  local ps1_date=$'\D{%Y/%m/%d}'
  local ps1_time=$'\D{%H:%M:%S}'
  local ps1_priv=$'\$'

  echo -n "$fg_red$ps1_user"
  echo -n "$fg_black@"
  echo -n "$fg_blue$ps1_host"
  echo -n "$fg_black|"
  echo -n "$fg_magenta$ps1_date"
  echo -n "$fg_black@"
  echo -n "$fg_cyan$ps1_time"
  echo -n "$fg_black|"
  echo -n "$fg_green$ps1_pwd"
  echo
  echo -n "$fg_yellow$ps1_priv$reset_color "
}

export PS1="$(build_ps1)"
