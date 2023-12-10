export BROWSER=w3m
export EDITOR=vim
export PAGER=less
export SHELL="$(which zsh)"
export TERMINAL=xterm
export VISUAL="$EDITOR"

LESS=
# Causes all forward searches to start just after the target line, and all
# backward searches to start just before the target line.
LESS+=" --SEARCH-SKIP-SCREEN"
# Searches ignore case unless the search pattern contains an uppercase letter.
LESS+=" --ignore-case"
# Display ANSI color escape sequences and OSC 8 hyperlink sequences in "raw"
# form, which enables embedded colors and hyperlinks in output.
LESS+=" --RAW-CONTROL-CHARS"
# Highlight the first new line after any forward movement larger than one line.
# Also highlights the target line after a g or p command. The highlight is
# removed at the next command which causes movement.
LESS+=" --HILITE-UNREAD"
# Set tab stops. With one argument, tab stops are set at multiples of `n`.
LESS+=" --tabs=4"
# NOTE: As appealing as it to include -J/--status-column or -N/--LINE-NUMBERS,
# these options break many applications that use tty width to determine when to
# line-break their output (like `man`) because they occupy a certain number of
# columns without altering the `$COLUMNS` variable. In addition, some
# applications use non-standard ways of determining the tty width (such as
# `ioctl()` of `TIOCGWINSZ`), which could not be overriden even if we were
# altering `$COLUMNS` dynamically.
export LESS

export JQ_COLORS="0;90:0;34:0;34:0;33:0;32:1;30:1;30:1;34"

export CLICOLOR=1
