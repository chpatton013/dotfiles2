function tmux() {
  tmux -2 "$@"
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
