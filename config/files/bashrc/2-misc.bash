# Update LINES and COLUMNS after each command.
shopt -s checkwinsize

# "**" recursively expands directories.
# Older versions of bash don't have this option, so we can ignore errors.
shopt -s globstar 2>/dev/null

# Allow <C-s> to pass through the terminal instead of stopping it.
stty stop undef
