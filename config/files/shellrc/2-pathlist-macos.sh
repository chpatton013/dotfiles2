function find_gnu_packages() {
  # Performance optimization; instead of searching through the whole homebrew
  # opt dir, pre-calculate and track this list.
  #
  # find -L /opt/homebrew/opt/ -wholename '*/libexec/gnubin'
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

function find_homebrew_packages() {
  # Performance optimization; instead of searching through the whole homebrew
  # opt dir, pre-calculate and track this list.
  #
  # # Find all executables in /opt/homebrew/opt/*/bin/ directories and transform
  # # them to their realpaths.
  # executables=$(
  #   find -L /opt/homebrew/opt/ -name bin -type d |
  #   xargs -I{} find {} -type f -executable |
  #   xargs -I{} realpath {} |
  #   sort -u
  # )
  # # Filter to executables whose realpaths don't match the realpath of the file
  # # found in the pathlist (ie, `which $exec`).
  # # Further filter to executables who are in their package's top-level bin/
  # # directory (ie, /opt/homebrew/Cellar/$package/$version/bin/$exec).
  # # Get the dirnames of these remaining executables.
  # # Further filter out versioned packages (ie, containing `@` in their paths).
  # # Transform the path by replacing /Cellar/ with /opt/, and removing the
  # # versioned subdirectory.
  # while IFS= read -r exec; do
  #   if [ "$(realpath "$(which "$(basename "$exec")")")" != "$exec" ] &&
  #      [ "$(echo -n "$exec" | grep -Fo / | wc -l)" -eq 7 ]; then
  #     dirname "$exec"
  #   fi
  # done <<< "$executables" | grep -v @ | sort -u | sed -e 's|/Cellar/|/opt/|' | cut -d/ -f1-5,7
  cat <<EOF
/opt/homebrew/opt/berkeley-db/bin
/opt/homebrew/opt/binutils/bin
/opt/homebrew/opt/file-formula/bin
/opt/homebrew/opt/icu4c/bin
/opt/homebrew/opt/m4/bin
/opt/homebrew/opt/ncurses/bin
/opt/homebrew/opt/ruby/bin
/opt/homebrew/opt/sqlite/bin
/opt/homebrew/opt/unzip/bin
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
for dir in $(find_homebrew_packages); do
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
