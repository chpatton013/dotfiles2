PATH="/usr/local/bin:/usr/bin:/bin"
if [ "$(id -u)" = 0 ]; then
  PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
fi
PATH="$(xdg_bin_home):$PATH"
export PATH

export LD_LIBRARY_PATH="$(xdg_lib_home):/usr/local/lib:/usr/lib:/lib"
