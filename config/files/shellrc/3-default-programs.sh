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

export JQ_COLORS="0;90:0;34:0;34:0;33:0;32:1;30:1;30:1;34"

export CLICOLOR=1
