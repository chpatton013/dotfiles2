# Enable completion support.
autoload -U compinit complete complist computil

# Prompt customization support.
autoload -U promptinit

# Enable color support.
autoload -U colors

# Enable regex support.
autoload -U regex

colors && compinit -u && promptinit
