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

function tl() {
  tmux list-sessions
}

function tm() {
  local name
  name="$1"
  readonly name

  if [ -z "$name" ]; then
    tmux new
  elif tmux has-session -t "$name" 2>/dev/null; then
    tmux attach -t "$name"
  else
    tmux new -s "$name"
  fi
}

function catr() {
  find "$@" -type f | xargs --no-run-if-empty cat
}

function skyquery() {
  bazel query --universe_scope=//... --order_output=no "$@"
}

function wt() {
  worktree "$@"
}

function wt_create() {
  worktree_create "$@"
}

function wt_resume() {
  worktree_resume "$@"
}
