# Try to complete from cursor.
setopt COMPLETE_IN_WORD

# Expand globs.
setopt GLOB_COMPLETE

# Moar globs!
setopt EXTENDED_GLOB

# Case insensitive globbing.
setopt NO_CASE_GLOB

# Glob sorting is primarily numeric.
setopt NUMERIC_GLOB_SORT

# Formatting output.
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*:corrections' format '%B%d (errors %e)%b'
zstyle ':completion:*' verbose yes

# Descriptions for options not described by completion functions.
zstyle ':completion:*' auto-description 'specify: %d'

# Menu instead of prompting for output. Auto-select first item.
zstyle ':completion:*:default' menu 'select=0'

# Use colors in completion menu.
zstyle ':completion:*:default' list-colors "=(#b) #([0-9]#)*=36=31"

# Display different types of matches separately.
zstyle ':completion:*' group-name ''

# Separate man page sections.
zstyle ':completion:*:manuals' separate-sections true

# Case insensitive completion.
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Don't complete directory we are already in (../here).
zstyle ':completion:*' ignore-parents parent pwd

# More errors allowed for large words and fewer for small words.
zstyle ':completion:*:approximate:*' max-errors 'reply=(  $((  ($#PREFIX+$#SUFFIX)/3  ))  )'

# Perform expansions, match all completions and corrections, and omit ignored.
zstyle ':completion:*' completer _expand _complete _approximate _ignored

# Faster completion.
zstyle ':completion::complete:*' use-cache 1
