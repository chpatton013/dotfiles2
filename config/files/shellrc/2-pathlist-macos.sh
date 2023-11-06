function find_gnu_packages() {
  local gnu_packages=(
    coreutils
    findutils
    gawk
    gnu-indent
    gnu-sed
    gnu-tar
    gnu-which
    grep
  )
  for dir in ${gnu_packages[@]}; do
    find "/opt/homebrew/Cellar/$dir" "$@"
  done
}

function prepend_pathlist() {
  local pathlist; pathlist="$1"
  local entry; entry="$2"
  if [ -z "$pathlist" ]; then
    echo "$entry"
  else
    echo "$entry:$pathlist"
  fi
}

function append_pathlist() {
  local pathlist; pathlist="$1"
  local entry; entry="$2"
  if [ -z "$pathlist" ]; then
    echo "$entry"
  else
    echo "$pathlist:$entry"
  fi
}

PATH="$(prepend_pathlist "$PATH" /opt/homebrew/sbin:/opt/homebrew/bin)"
# Prepend GNU bins so they take precedence over BSD bins
for dir in $(find_gnu_packages -name gnubin); do
  PATH="$(prepend_pathlist "$PATH" "$dir")"
done
export PATH

LD_LIBRARY_PATH="$(append_pathlist "$LD_LIBRARY_PATH" /opt/homebrew/lib)
export LD_LIBRARY_PATH

for dir in $(find_gnu_packages -name gnuman); do
  if [ -z "$MANPATH" ]; then
    MANPATH="$dir"
  else
    MANPATH="$dir:$MANPATH"
  fi
done
MANPATH="$(append_pathlist "$MANPATH" /opt/homebrew/share/man)
export MANPATH
