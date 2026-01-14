export NPM_PREFIX="$(npm_data_dir)"
export PATH="$(prepend_pathlist "$PATH" "$NPM_PREFIX/bin")"
export NODE_PATH="$(prepend_pathlist "$NODE_PATH" "$NPM_PREFIX/lib/node_modules")"
