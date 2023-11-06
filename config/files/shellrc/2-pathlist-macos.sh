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

for dir in $(find_gnu_packages -name gnubin); do
  if [ -z "$PATH" ]; then
    PATH="$dir"
  else
    PATH="$dir:$PATH"
  fi
done
export PATH

for dir in $(find_gnu_packages -name gnuman); do
  if [ -z "$MANPATH" ]; then
    MANPATH="$dir"
  else
    MANPATH="$dir:$MANPATH"
  fi
done
export MANPATH
