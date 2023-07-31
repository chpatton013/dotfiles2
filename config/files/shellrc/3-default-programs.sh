export BROWSER=w3m
export EDITOR=vim
export PAGER=less
export SHELL="$(which zsh)"
export TERMINAL=xterm
export VISUAL="$EDITOR"

LESS=
LESS+=" --SEARCH-SKIP-SCREEN"
LESS+=" --ignore-case"
LESS+=" --status-column"
LESS+=" --RAW-CONTROL-CHARS"
LESS+=" --hilite-unread"
LESS+=" --tabs=2"
export LESS

export CLICOLOR=1
