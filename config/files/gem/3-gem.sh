export GEM_HOME="$(gem_data_dir)"
export PATH="$(prepend_pathlist "$PATH" "$GEM_HOME/bin")"
