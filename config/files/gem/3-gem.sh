export GEM_HOME="$(gem_data_dir)"

if [ -z "$PATH" ]; then
  export PATH="$GEM_HOME/bin"
else
  export PATH="$GEM_HOME/bin:$PATH"
fi
