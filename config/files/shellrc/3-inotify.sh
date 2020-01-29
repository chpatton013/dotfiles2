function _inotifyrun_invoke() {
  echo CWD: $(pwd)
  echo CMD: $@
  "$@"
  echo RTN: $?
}

function inotifyrun() {
  _inotifyrun_invoke "$@"

  while inotifywait \
      --recursive \
      --exclude ".*/\.git/.*|.*/\.mypy_cache/.*|.*/bazel-.*/.*|(.*\.sw.?$)" \
      --event modify \
      --event move \
      --event create \
      --event delete \
      --event delete_self \
      --event unmount \
      --timefmt '%Y/%m/%d@%H:%M:%S' \
      --format '[%T | %e | %w %f]' \
      .; do
    _inotifyrun_invoke "$@"
  done
}
