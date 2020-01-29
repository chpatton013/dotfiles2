if [ -f "$(dircolors_file)" ]; then
  eval $(dircolors --bourne-shell "$(dircolors_file)")
else
  echo dircolors Failed! \'$(dircolors_file)\' does not exist >&2
fi
