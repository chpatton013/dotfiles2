# Lone directory names become cd commands.
setopt AUTO_CD

# cd = pushd.
setopt AUTO_PUSHD

# Enable auto-correction for unrecognized commands.
setopt CORRECT

# NOTE: do NOT `setopt KSH_ARRAYS` here. It is globally incompatible with zsh's
# completion system: with KSH_ARRAYS a bare `$fpath` expands to only its first
# element, so the completer's internal `fpath=($fpath ...)` reassignments
# collapse fpath to a single entry and drop the (source-built) zsh's real
# function dir. The result is Tab producing
#   _main_complete: function definition file not found
# Keep arrays at zsh's native 1-based semantics so completion works.

# Allow piping to multiple outputs.
setopt MULTIOS

# No audio bells.
setopt NO_BEEP

# It is annoying when the terminal stops producing output for no good reason.
setopt NO_FLOW_CONTROL

# Do not hang up on me.
setopt NO_HUP

# Reverses 'cd +1' and 'cd -1'.
setopt PUSHD_MINUS

# Do not print directory name when running pushd.
setopt PUSHD_SILENT

# Blank pushd goes to home.
setopt PUSHD_TO_HOME

# foo${a b c}bar = fooabar foobbar foocbar instead of fooa b cbar.
setopt RC_EXPAND_PARAM

# Vim commands on the command line (instead of emacs).
setopt VI

# Report runtime of commands that take longer than 5 seconds of user time.
export REPORTTIME=5
