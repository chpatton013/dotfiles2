function find_gnu_packages() {
  # Performance optimization; instead of searching through the whole homebrew
  # opt dir, pre-calculate and track this list.
  local name; name="$1"
  cat <<EOF
/opt/homebrew/opt/coreutils/libexec/$name
/opt/homebrew/opt/findutils/libexec/$name
/opt/homebrew/opt/gawk/libexec/$name
/opt/homebrew/opt/gnu-indent/libexec/$name
/opt/homebrew/opt/gnu-sed/libexec/$name
/opt/homebrew/opt/gnu-tar/libexec/$name
/opt/homebrew/opt/gnu-which/libexec/$name
/opt/homebrew/opt/grep/libexec/$name
/opt/homebrew/opt/libtool/libexec/$name
EOF
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
for dir in $(find_gnu_packages gnubin); do
  PATH="$(prepend_pathlist "$PATH" "$dir")"
done
export PATH

# Prepend GNU mans so they take precedence over BSD bins
for dir in $(find_gnu_packages gnuman); do
  MANPATH="$(prepend_pathlist "$MANPATH" "$dir")"
done
MANPATH="$(append_pathlist "$MANPATH" /opt/homebrew/share/man)"
export MANPATH

LD_LIBRARY_PATH="$(append_pathlist "$LD_LIBRARY_PATH" /opt/homebrew/lib)"
export LD_LIBRARY_PATH
