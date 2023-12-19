function v() {
  vim "$@"
}

function vo() {
  v -o "$@"
}

function vO() {
  v -O "$@"
}

function vp() {
  v -p "$@"
}

function vprof() {
  local output_file="$(mktemp)"
  v "+profile start $output_file" "+profile func *" "+profile file *" "$@"
  echo reading profile from $output_file
  less "$output_file"
}
