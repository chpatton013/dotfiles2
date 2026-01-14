export PATH="$(prepend_pathlist "$PATH" "$(xdg_bin_home)")"
export LD_LIBRARY_PATH="$(prepend_pathlist "$LD_LIBRARY_PATH" "$(xdg_lib_home)")"
