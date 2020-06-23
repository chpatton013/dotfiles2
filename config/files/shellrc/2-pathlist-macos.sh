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
    find "/usr/local/Cellar/$dir" "$@"
  done
}

for dir in $(find_gnu_packages -name gnubin); do
  PATH="$dir:$PATH"
done
export PATH

for dir in $(find_gnu_packages -name gnuman); do
  MANPATH="$dir:$MANPATH"
done
export MANPATH
