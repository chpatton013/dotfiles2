export BROWSER=w3m
export EDITOR=nvim
export PAGER=less
export SHELL="$(which zsh)"
export TERMINAL=xterm
export VISUAL="$EDITOR"

LESS=
LESS+=" --SEARCH-SKIP-SCREEN"
LESS+=" --ignore-case"
LESS+=" --status-column"
LESS+=" --LINE-NUMBERS"
LESS+=" --RAW-CONTROL-CHARS"
LESS+=" --hilite-unread"
LESS+=" --tabs=2"
export LESS

export CLICOLOR=1
export TERM=xterm-256color
