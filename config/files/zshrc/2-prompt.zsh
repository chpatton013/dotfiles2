last_bg=NONE
() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  sep=
}

function prompt_segment() {
  local bg="%K{$1}"
  local fg="%F{$2}"
  if [[ "$last_bg" != 'NONE' && "$1" != "$last_bg" ]]; then
    echo -n " %{$bg%F{$last_bg}%}$sep%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  last_bg="$1"
  shift 2
  echo -n "$@"
}

# End the prompt, closing any open segments.
function prompt_end() {
  if [[ -n $last_bg ]]; then
    echo -n " %{%k%F{$last_bg}%}$sep"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  last_bg=
}

function build_prompt() {
  last_bg='NONE'
  prompt_segment "$COLOR_SELECTOR_FG" "$COLOR_SELECTOR_BG" "%?"
  prompt_segment "$COLOR_SELECTOR_BG" "$COLOR_SELECTOR_FG" "%n"
  prompt_segment "$COLOR_SELECTOR_FG" "$COLOR_SELECTOR_BG" "%M"
  prompt_segment "$COLOR_SELECTOR_BG" "$COLOR_SELECTOR_FG" "%D{%Y/%m/%d}"
  prompt_segment "$COLOR_SELECTOR_FG" "$COLOR_SELECTOR_BG" "%D{%H:%M:%S}"
  prompt_end
  echo

  last_bg='NONE'
  prompt_segment "$COLOR_SELECTOR_ACTIVE" "$COLOR_SELECTOR_BG" '%~'
  prompt_end
  echo

  last_bg='NONE'
  prompt_segment "$COLOR_SELECTOR_FG" "$COLOR_SELECTOR_BG" '%#'
  prompt_end
}

export PS1="%{%f%b%k%}$(build_prompt) "

unset last_bg
unset sep
unset prompt_segment
unset prompt_end
unset build_prompt
