# Enable completion support. Stamp the compdump cache with $ZSH_VERSION so a zsh
# upgrade/rebuild (e.g. the source-built zsh landing a new version) starts from a
# fresh dump instead of reusing one whose cached function paths no longer exist.
autoload -U compinit complete complist computil
compinit -u -d "${ZDOTDIR:-$HOME}/.zcompdump-${ZSH_VERSION}" >/dev/null

# Prompt customization support.
autoload -U promptinit
promptinit

# Enable color support.
autoload -U colors
colors

# Enable regex support.
autoload -U regex
