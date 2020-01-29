# Append to history file instead of overwriting.
shopt -s histappend

# Ignore immedately repeated commands and ignore commands prefixed with spaces.
export HISTCONTROL=ignoreboth

# Save history to a custom location.
export HISTFILE="$(bashrc_data_dir)/history"
