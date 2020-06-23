function l() {
  ls --classify --escape --human-readable "$@"
}

function ll() {
  l -l "$@"
}

function la() {
  l --almost-all "$@"
}

function v() {
  "$EDITOR" "$@"
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

function catr() {
  find "$@" -type f | xargs --no-run-if-empty cat
}
