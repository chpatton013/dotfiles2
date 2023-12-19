function l() {
  ls --classify --color=always --escape --human-readable "$@"
}

function ll() {
  l -l "$@"
}

function la() {
  l --almost-all "$@"
}

function catr() {
  find "$@" -type f | xargs --no-run-if-empty cat
}

function ifind() {
  find . -iname "$@"
}

function wfind() {
  find . -wholename "*$@"
}

function gg() {
  rg --hidden --no-heading --smart-case "$@"
}

function uriencode() {
  jq --raw-input --raw-output --slurp '@uri'
}

function k() {
  kubectl "$@"
}

function e() {
  "$EDITOR" "$@"
}

function eo() {
  e -o "$@"
}

function eO() {
  e -O "$@"
}

function ep() {
  e -p "$@"
}
