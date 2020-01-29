# Incremental search.
bindkey -M vicmd "/" history-incremental-search-backward
bindkey -M vicmd "?" history-incremental-search-forward
# Search on text already typed in.
bindkey -M vicmd "//" history-beginning-search-backward
bindkey -M vicmd "??" history-beginning-search-forward

# Rebind arrow keys.
bindkey '\e[A' up-line-or-history
bindkey '\eOA' up-line-or-history
bindkey '\e[B' down-line-or-history
bindkey '\eOB' down-line-or-history
bindkey '\e[C' forward-char
bindkey '\eOC' forward-char
bindkey '\e[D' backward-char
bindkey '\eOD' backward-char

# Rebind home and end.
bindkey '\e[1~' beginning-of-line
bindkey '\e[4~' end-of-line

# Rebind the insert and delete.
bindkey '\e[2~' overwrite-mode
bindkey '\e[3~' delete-char

# Vim smash escape.
bindkey -M viins 'kj' vi-cmd-mode

# Vim undo and redo.
bindkey -M vicmd 'u' undo
bindkey -M vicmd '^r' redo

# Vim clear text on line ("quit").
bindkey -M vicmd "q" push-line

# Space and completion in one.
bindkey -M viins ' ' magic-space
