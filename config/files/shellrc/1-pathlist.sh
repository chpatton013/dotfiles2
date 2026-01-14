function prepend_pathlist() {
  local pathlist
  local entry
  pathlist="$1"
  entry="$2"
  if [ -z "$pathlist" ]; then
    echo "$entry"
  elif [[ "$pathlist" != "$entry:"* ]]; then
    echo "$entry:$pathlist"
  else
    echo "$pathlist"
  fi
}

function append_pathlist() {
  local pathlist
  local entry
  pathlist="$1"
  entry="$2"
  if [ -z "$pathlist" ]; then
    echo "$entry"
  elif [[ ":$pathlist:" != *":$entry:"* ]]; then
    echo "$pathlist:$entry"
  else
    echo "$pathlist"
  fi
}

PATH="$(prepend_pathlist "$PATH" "$(xdg_bin_home)")"
if [ "$(id -u)" -eq 0 ]; then
  PATH="$(append_pathlist "$PATH" /usr/local/sbin)"
  PATH="$(append_pathlist "$PATH" /usr/sbin)"
  PATH="$(append_pathlist "$PATH" /sbin)"
fi
PATH="$(append_pathlist "$PATH" /usr/local/bin)"
PATH="$(append_pathlist "$PATH" /usr/bin)"
PATH="$(append_pathlist "$PATH" /bin)"
export PATH

LD_LIBRARY_PATH="$(prepend_pathlist "$PATH" "$(xdg_lib_home)")"
LD_LIBRARY_PATH="$(append_pathlist "$PATH" /usr/local/lib)"
LD_LIBRARY_PATH="$(append_pathlist "$PATH" /usr/lib)"
LD_LIBRARY_PATH="$(append_pathlist "$PATH" /lib)"
export LD_LIBRARY_PATH
