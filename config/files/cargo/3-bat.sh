function man() {
  batman "$@"
}

function help() {
  "$@" --help 2>&1 | bat --plain --language=help
}

function follow() {
  tail -f "$@" | bat --paging=never -l log
}
