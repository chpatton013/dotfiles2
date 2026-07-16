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

# Keg-only formula bins are put on PATH by `brew link`-ing them into
# /opt/homebrew/bin at provision time (setup-macos/roles/dev-tools), not by
# enumerating opt/*/bin here. Note find_gnu_packages below stays: `brew link`
# can't replace it, since the GNU libexec/gnubin dirs provide *un-prefixed* GNU
# commands (grep, sed, ...) that linking the formula would not.

PATH="$(prepend_pathlist "$PATH" /opt/homebrew/bin)"
if [ "$(id -u)" -eq 0 ]; then
  PATH="$(prepend_pathlist "$PATH" /opt/homebrew/sbin)"
fi
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
