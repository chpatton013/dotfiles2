# Append to history file instead of overwriting.
setopt APPEND_HISTORY

# Save time and duration of execution.
setopt EXTENDED_HISTORY

# Ignore immediate duplicate commands.
setopt HIST_IGNORE_DUPS

# Do not save lines that start with a space.
setopt HIST_IGNORE_SPACE

# Resolve '!' to their effective commands.
setopt HIST_NO_STORE

# Auto-completion with '!' verifies on next line.
setopt HIST_VERIFY

# Share history between shells.
setopt SHARE_HISTORY

# Save history to a custom location.
export HISTFILE="$(zshrc_data_dir)/history"
