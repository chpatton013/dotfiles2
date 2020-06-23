export NPM_PREFIX="$(npm_data_dir)"

if [ -z "$PATH" ]; then
  export PATH="$NPM_PREFIX/bin"
else
  export PATH="$NPM_PREFIX/bin:$PATH"
fi

if [ -z "$NODE_PATH" ]; then
  export NODE_PATH="$NPM_PREFIX/lib/node_modules"
else
  export NODE_PATH="$NPM_PREFIX/lib/node_modules:$NODE_PATH"
fi
