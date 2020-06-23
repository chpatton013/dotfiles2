# Lone directory names become cd commands.
setopt AUTO_CD

# cd = pushd.
setopt AUTO_PUSHD

# Enable auto-correction for unrecognized commands.
setopt CORRECT

# Use Bash- and Ksh-style array indices (0-based).
setopt KSH_ARRAYS

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
