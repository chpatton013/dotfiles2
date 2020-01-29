function l() {
  ls --classify --escape --human-readable "$@"
}

function ll() {
  l -l "$@"
}

function la() {
  l --almost-all "$@"
}

function b() {
  bazel "$@"
}

function g() {
  git "$@"
}

function v() {
  "$EDITOR" "$@"
}

function vo() {
  "$EDITOR" -o "$@"
}

function vO() {
  "$EDITOR" -O "$@"
}

function vp() {
  "$EDITOR" -p "$@"
}

function tl() {
  tmux list-sessions
}

function tm() {
  local name
  name="$1"
  readonly name

  if [ -z "$name" ]; then
    tmux
  elif tmux has-session -t "$name" 2>/dev/null; then
    tmux attach -t "$name"
  else
    tmux new -s "$name"
  fi
}
